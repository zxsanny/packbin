use crate::walk::{decode_text, encode_text, pack, unpack};
use crate::{
    insert, to_hex, u8, utf8, BinaryPacker, BoundField, MapScheme, Scheme, UnpackError, Value,
    Values,
};
use std::collections::BTreeMap;
use std::process::{Command, Stdio};

// AZ-2652: every row of fixtures/text/vectors.txt (enc, alt, bad, flip, ref) against the codec,
// packed and unpacked as a string field, plus the drift check of the emitted tables.

const VECTORS: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../fixtures/text/vectors.txt");
const EMITTER: &str = concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../scripts/text/emit_tables.py"
);
const TABLES_FILE: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/src/walk/text_tables.rs");

fn from_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).expect("hex"))
        .collect()
}

/// The rows of one kind: the fields after the kind, split on spaces (an empty buffer is "").
fn rows(kind: &str) -> Vec<Vec<String>> {
    let text = std::fs::read_to_string(VECTORS).expect("vectors file");
    let found: Vec<Vec<String>> = text
        .lines()
        .filter(|line| line.split(' ').next() == Some(kind))
        .map(|line| line.split(' ').skip(1).map(str::to_string).collect())
        .collect();
    assert!(!found.is_empty(), "no {kind} rows");
    found
}

fn text_of(hex: &str) -> String {
    if hex == "-" {
        return String::new();
    }
    String::from_utf8(from_hex(hex)).expect("row text is UTF-8")
}

fn string_scheme() -> MapScheme {
    MapScheme::new(1, vec![utf8("s")])
}

/// The packet `01` + `field` and one `u8` after it, to prove where the string stops.
fn string_then_byte_scheme() -> MapScheme {
    MapScheme::new(1, vec![utf8("s"), u8("t")])
}

fn pack_string(text: &str) -> Result<String, crate::PackError> {
    let mut vals = Values::new();
    insert(&mut vals, "s", Some(Value::Str(text.to_string())));
    pack(&string_scheme(), &vals).map(|bytes| to_hex(&bytes))
}

fn unpack_string(field: &[u8]) -> Result<String, UnpackError> {
    let mut packet = vec![1u8];
    packet.extend_from_slice(field);
    match unpack(&string_scheme(), &packet)?.remove("s") {
        Some(Some(Value::Str(text))) => Ok(text),
        other => panic!("expected a string, got {other:?}"),
    }
}

fn refused_naming_s(result: Result<String, UnpackError>, id: &str) {
    match result {
        Err(UnpackError::Short(short)) => assert_eq!(short.field, "s", "{id}"),
        other => panic!("{id}: expected a refusal naming the field, got {other:?}"),
    }
}

#[test]
fn ac1_every_enc_row_packs_to_its_bytes() {
    // Arrange
    let rows = rows("enc");

    for row in &rows {
        // Act
        let packed = pack_string(&text_of(&row[1]));
        let direct = encode_text(&text_of(&row[1])).map(|b| to_hex(&b));

        // Assert
        assert_eq!(packed, Ok(format!("01{}", row[2])), "{}", row[0]);
        assert_eq!(direct, Some(row[2].clone()), "{}", row[0]);
    }
    assert!(rows.len() >= 290, "{} enc rows", rows.len());
}

#[test]
fn ac2_every_enc_and_alt_row_unpacks_to_its_text_using_every_byte() {
    // Arrange
    let mut rows = rows("enc");
    rows.extend(self::rows("alt"));

    for row in &rows {
        let field = from_hex(&row[2]);

        // Act
        let text = unpack_string(&field);
        let direct = decode_text(&field);

        // Assert: unpack refuses trailing bytes, so a pass means the field used them all
        assert_eq!(text, Ok(text_of(&row[1])), "{}", row[0]);
        assert_eq!(direct, Ok((text_of(&row[1]), field.len())), "{}", row[0]);
    }
}

#[test]
fn ac4_ac6_every_bad_row_is_refused_naming_the_field_with_its_kind() {
    // Arrange
    let rows = rows("bad");
    let mut kinds = std::collections::BTreeSet::new();

    for row in &rows {
        let buffer = from_hex(&row[2]);

        // Act
        let result = unpack_string(&buffer);
        let direct = decode_text(&buffer);

        // Assert
        refused_naming_s(result, &row[0]);
        let kind = direct.expect_err(&row[0]).kind;
        assert_eq!(kind, row[1], "{}", row[0]);
        kinds.insert(kind);
    }
    for kind in [
        "short", "varint", "mode", "pad", "code", "cap", "esc", "utf8", "raw", "length",
    ] {
        assert!(kinds.contains(kind), "no bad row of kind {kind}");
    }
}

#[test]
fn ac4_a_flipped_payload_bit_is_a_string_or_an_error_and_the_next_byte_survives() {
    // Arrange
    let encs: BTreeMap<String, String> = rows("enc")
        .into_iter()
        .map(|row| (row[0].clone(), row[2].clone()))
        .collect();
    let flips = rows("flip");
    let mut flipped = 0;

    for row in &flips {
        let field = from_hex(&encs[&row[1]]);
        let payload_at = if field[0] < 0x80 {
            1
        } else {
            2 + usize::from(field[1] >= 0x80)
        };

        for bit in 0..8 * (field.len() - payload_at) {
            let mut damaged = field.clone();
            damaged[payload_at + bit / 8] ^= 0x80 >> (bit % 8);
            damaged.push(0x5a);

            // Act
            let mut packet = vec![1u8];
            packet.extend_from_slice(&damaged);
            let result = unpack(&string_then_byte_scheme(), &packet);
            let direct = decode_text(&damaged);

            // Assert
            match result {
                Ok(values) => {
                    assert_eq!(values["t"], Some(Value::U8(0x5a)), "{} bit {bit}", row[0]);
                    let (text, used) = direct.expect("decode agrees with unpack");
                    assert_eq!(damaged[used], 0x5a, "{} bit {bit}", row[0]);
                    assert!(
                        text.len() <= 6 * (used - payload_at) + 8,
                        "{} bit {bit}",
                        row[0]
                    );
                }
                Err(UnpackError::Short(short)) => {
                    assert_eq!(short.field, "s", "{} bit {bit}", row[0]);
                    assert!(direct.is_err(), "{} bit {bit}", row[0]);
                }
                Err(other) => panic!("{} bit {bit}: {other:?}", row[0]),
            }
            flipped += 1;
        }
    }
    assert!(
        flips.len() >= 20 && flipped > 1000,
        "{} rows, {flipped} flips",
        flips.len()
    );
}

#[derive(Default, Debug, PartialEq)]
struct User {
    username: String,
    roles: Vec<String>,
    access: BTreeMap<String, Vec<String>>,
}

#[derive(Default, Debug, PartialEq)]
struct Nested {
    access: BTreeMap<String, Vec<BTreeMap<String, String>>>,
}

fn user_scheme() -> Scheme<User> {
    Scheme::new(
        1,
        [
            BoundField::utf8(0, |r: &User| r.username.clone(), |r, v| r.username = v).into(),
            BoundField::list_utf8(|r: &User| r.roles.clone(), |r, v| r.roles = v).into(),
            BoundField::dict_list_utf8(|r: &User| r.access.clone(), |r, v| r.access = v).into(),
        ],
    )
}

fn nested_scheme() -> Scheme<Nested> {
    Scheme::new(
        1,
        [
            BoundField::dict_list_dict_utf8(|r: &Nested| r.access.clone(), |r, v| r.access = v)
                .into(),
        ],
    )
}

fn strings(items: &[&str]) -> Vec<String> {
    items.iter().map(|s| s.to_string()).collect()
}

fn user(name: &str, roles: &[&str], access: &[(&str, &[&str])]) -> User {
    User {
        username: name.to_string(),
        roles: strings(roles),
        access: access
            .iter()
            .map(|(k, v)| (k.to_string(), strings(v)))
            .collect(),
    }
}

fn nested(access: &[(&str, &[&[(&str, &str)]])]) -> Nested {
    let rows = |rows: &[&[(&str, &str)]]| {
        rows.iter()
            .map(|r| {
                r.iter()
                    .map(|(k, v)| (k.to_string(), v.to_string()))
                    .collect()
            })
            .collect()
    };
    Nested {
        access: access
            .iter()
            .map(|(k, v)| (k.to_string(), rows(v)))
            .collect(),
    }
}

fn ring_hex(id: &str) -> String {
    let rows = rows("ref");
    rows.iter()
        .find(|row| row[0] == id)
        .unwrap_or_else(|| panic!("no ref row {id}"))[1]
        .clone()
}

#[test]
fn ac3_the_ref_packets_match_the_ring_bytes_and_round_trip() {
    // Arrange
    let users = [
        (
            "ref.user",
            user(
                "zxsanny",
                &["user", "dispatcher"],
                &[
                    ("channel", &["read"]),
                    ("map", &["read", "gps_fix", "set", "edit"]),
                    ("store", &["read", "write"]),
                ],
            ),
        ),
        (
            "ref.user_ua",
            user(
                "Олександр",
                &["диспетчер", "Оператор"],
                &[("карта", &["читати", "правити"]), ("канал", &["читати"])],
            ),
        ),
    ];
    let nesteds = [
        (
            "ref.nested",
            nested(&[
                ("map", &[&[("op", "gps_fix")]]),
                ("store", &[&[("op", "read")], &[("op", "write")]]),
            ]),
        ),
        (
            "ref.nested_mixed",
            nested(&[
                (
                    "Карта",
                    &[&[("op", "gps_fix"), ("note", "увага 48.46, 35.04")]],
                ),
                ("store", &[&[("op", "ЧИТАТИ")]]),
            ]),
        ),
    ];

    for (id, row) in users {
        // Act
        let bytes = BinaryPacker::pack(&user_scheme(), &row).expect("pack");
        let mut got = User::default();
        let scheme = user_scheme();
        BinaryPacker::unpack_with(&bytes, &mut [&mut scheme.on(|r| got = r)]).expect("unpack");

        // Assert
        assert_eq!(to_hex(&bytes), ring_hex(id), "{id}");
        assert_eq!(got, row, "{id}");
    }
    for (id, row) in nesteds {
        let bytes = BinaryPacker::pack(&nested_scheme(), &row).expect("pack");
        let mut got = Nested::default();
        let scheme = nested_scheme();
        BinaryPacker::unpack_with(&bytes, &mut [&mut scheme.on(|r| got = r)]).expect("unpack");

        assert_eq!(to_hex(&bytes), ring_hex(id), "{id}");
        assert_eq!(got, row, "{id}");
    }
}

#[test]
fn the_emitted_tables_file_is_what_the_emitter_writes_today() {
    // Arrange and Act
    let status = Command::new("python3")
        .args([EMITTER, "rust", "--check", TABLES_FILE])
        .stdin(Stdio::null())
        .status()
        .expect("python3 runs the table emitter");

    // Assert
    assert!(
        status.success(),
        "{TABLES_FILE} differs from emit_tables.py rust"
    );
}
