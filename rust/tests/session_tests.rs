use packbin::{
    flags, i16, mismatched_bytes, to_hex, u16, u8, BinaryPacker, BoundField, PackError,
    PackSession, Scheme, SessionPackError, NONCE_SIZE, SEED_SIZE,
};

#[derive(Default, Clone, Debug, PartialEq, Eq)]
struct PositionRow {
    sid: u16,
    lat: i32,
    lon: i32,
    profile: u8,
    heading: Option<u16>,
    speed: Option<u8>,
    altitude: Option<i16>,
}

fn position_scheme() -> Scheme<PositionRow> {
    Scheme::new(
        0x40,
        [
            BoundField::u16(
                0,
                |r: &PositionRow| r.sid,
                |r: &mut PositionRow, v| r.sid = v,
            )
            .into(),
            BoundField::i32(
                1,
                |r: &PositionRow| r.lat,
                |r: &mut PositionRow, v| r.lat = v,
            )
            .into(),
            BoundField::i32(
                2,
                |r: &PositionRow| r.lon,
                |r: &mut PositionRow, v| r.lon = v,
            )
            .into(),
            BoundField::u8(
                3,
                |r: &PositionRow| r.profile,
                |r: &mut PositionRow, v| r.profile = v,
            )
            .into(),
            flags(4, "motion", vec![u16("heading"), u8("speed"), i16("altitude")]).into(),
        ],
    )
}

fn position_row() -> PositionRow {
    PositionRow {
        sid: 1,
        lat: 500_000_000,
        lon: 300_000_000,
        profile: 1,
        heading: None,
        speed: None,
        altitude: None,
    }
}

fn seed() -> [u8; SEED_SIZE] {
    let mut s = [0u8; SEED_SIZE];
    for (i, b) in s.iter_mut().enumerate() {
        *b = (i + 1) as u8;
    }
    s
}

fn fixture_nonce() -> [u8; NONCE_SIZE] {
    let mut n = [0u8; NONCE_SIZE];
    n[0] = 0x01;
    n
}

fn parse_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

fn field_mismatches(row: &PositionRow) -> usize {
    let mut n = 0;
    if row.sid != 1 {
        n += 1;
    }
    if row.lat != 500_000_000 {
        n += 1;
    }
    if row.lon != 300_000_000 {
        n += 1;
    }
    if row.profile != 1 {
        n += 1;
    }
    if row.heading.is_some() {
        n += 1;
    }
    if row.speed.is_some() {
        n += 1;
    }
    if row.altitude.is_some() {
        n += 1;
    }
    n
}

const GOLDEN_HEX: &str = "4001000065cd1d00a3e1110100";
const CIPHER_HEX: &str = "b55d0a29c56c203712b241232e";

#[test]
fn ac1_opener_ciphertext_matches() {
    let mut opener = PackSession::load(&seed()).expect("load");
    assert!(opener.start_with(&fixture_nonce()).is_some());
    let payload = opener.pack(&position_scheme(), &position_row()).expect("pack");
    assert_eq!(payload.len(), 13);
    assert_eq!(to_hex(&payload), CIPHER_HEX);
    assert_eq!(mismatched_bytes(&payload, &parse_hex(CIPHER_HEX)), 0);
}

#[test]
fn ac2_waiter_recovers_row() {
    let mut opener = PackSession::load(&seed()).expect("load");
    let mut waiter = PackSession::load(&seed()).expect("load");
    let nonce = opener.start_with(&fixture_nonce()).expect("start");
    assert!(waiter.join(&nonce));
    let payload = opener.pack(&position_scheme(), &position_row()).expect("pack");

    let mut got = None;
    let scheme = position_scheme();
    let mut on_row = scheme.on(|row| got = Some(row));
    waiter
        .unpack(&payload, &mut [&mut on_row])
        .expect("unpack");
    let row = got.expect("row");
    assert_eq!(field_mismatches(&row), 0);
}

#[test]
fn ac3_clear_pack_unchanged() {
    let bytes = BinaryPacker::pack(&position_scheme(), &position_row()).expect("pack");
    assert_eq!(to_hex(&bytes), GOLDEN_HEX);
    assert_eq!(mismatched_bytes(&bytes, &parse_hex(GOLDEN_HEX)), 0);
}

#[test]
fn ac4_bad_lengths_create_nothing() {
    let mut created = 0;
    if PackSession::load(&[0u8; 31]).is_some() {
        created += 1;
    }
    if PackSession::load(&[0u8; 33]).is_some() {
        created += 1;
    }
    let mut loaded = PackSession::load(&seed()).expect("load");
    if loaded.join(&[0u8; 15]) {
        created += 1;
    }
    if loaded.join(&[0u8; 17]) {
        created += 1;
    }
    if loaded.start_with(&[0u8; 15]).is_some() {
        created += 1;
    }
    assert_eq!(created, 0);
    assert_eq!(
        loaded.pack(&position_scheme(), &position_row()),
        Err(SessionPackError::NotOpen)
    );
}

#[derive(Default)]
struct TextRow {
    text: String,
}

fn text_scheme() -> Scheme<TextRow> {
    Scheme::new(
        0x41,
        [BoundField::utf8(
            0,
            |r: &TextRow| r.text.clone(),
            |r: &mut TextRow, v| r.text = v,
        )
        .into()],
    )
}

fn open_pair() -> (PackSession, PackSession) {
    let mut opener = PackSession::load(&[7; SEED_SIZE]).expect("load");
    let mut waiter = PackSession::load(&[7; SEED_SIZE]).expect("load");
    let nonce = opener.start_with(&[1; NONCE_SIZE]).expect("start");
    assert!(waiter.join(&nonce));
    (opener, waiter)
}

#[test]
fn ac1_pack_before_open_is_not_open_and_the_counter_stays_zero() {
    let mut session = PackSession::load(&seed()).expect("load");

    let before = session.pack(&position_scheme(), &position_row());

    assert_eq!(before, Err(SessionPackError::NotOpen));
    assert!(session.start_with(&fixture_nonce()).is_some());
    let first = session
        .pack(&position_scheme(), &position_row())
        .expect("pack");
    assert_eq!(to_hex(&first), CIPHER_HEX);
}

#[test]
fn ac2_oversize_string_returns_the_pack_error_of_clear_pack() {
    let (mut opener, _waiter) = open_pair();
    let row = TextRow {
        text: "a".repeat(70_000),
    };
    let clear = BinaryPacker::pack(&text_scheme(), &row);
    assert_eq!(clear, Err(PackError::Type("0".to_string())));

    let sent = opener.pack(&text_scheme(), &row);

    assert_eq!(
        sent,
        Err(SessionPackError::Pack(PackError::Type("0".to_string())))
    );
}

#[test]
fn ac3_a_failed_pack_consumes_no_pad_position() {
    let (mut opener, mut waiter) = open_pair();
    let bad = TextRow {
        text: "a".repeat(70_000),
    };
    assert!(opener.pack(&text_scheme(), &bad).is_err());

    let payload = opener
        .pack(&position_scheme(), &position_row())
        .expect("pack");

    let mut got = None;
    let scheme = position_scheme();
    let mut on_row = scheme.on(|row| got = Some(row));
    waiter.unpack(&payload, &mut [&mut on_row]).expect("unpack");
    assert_eq!(field_mismatches(&got.expect("row")), 0);
}
