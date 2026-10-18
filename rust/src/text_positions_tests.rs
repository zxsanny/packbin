use crate::walk::{decode_text, encode_text, pack, unpack};
use crate::{
    dict, flags, insert, list, repeat, times, to_hex, u32, u8, utf8, MapScheme, PackError,
    UnpackError, Value, Values,
};
use std::collections::BTreeMap;
use std::time::Instant;

// AZ-2652: the codec in every string position, its limits and header sizes, dictionary key order,
// round trips of random texts, damaged random payloads and the speed bound.

const HELLO: &str = "05a37aa424e0";
const HELLO_CAPS: &str = "0c83e6f54849fd8f96849cffe0";

fn hello() -> Value {
    Value::Str("привіт".to_string())
}

fn row(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

fn hex_of(scheme: &MapScheme, vals: &Values) -> String {
    to_hex(&pack(scheme, vals).expect("pack"))
}

fn from_hex(hex: &str) -> Vec<u8> {
    let hex = hex.replace(' ', "");
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).expect("hex"))
        .collect()
}

fn short_naming(result: Result<Values, UnpackError>, field: &str) {
    match result {
        Err(UnpackError::Short(short)) => assert_eq!(short.field, field),
        other => panic!("expected a refusal naming {field}, got {other:?}"),
    }
}

#[test]
fn ac3_a_list_element_a_dict_key_and_a_dict_value_list_use_the_codec() {
    // Arrange
    let as_list = MapScheme::new(1, vec![list("l", utf8("e"))]);
    let as_dict = MapScheme::new(1, vec![dict("d", u8("v"))]);
    let value_list = MapScheme::new(1, vec![dict("d", list("l", utf8("e")))]);
    let map = |v: Value| Value::Map(BTreeMap::from([("привіт".to_string(), v)]));

    // Act and Assert
    let list_vals = row(&[("l", Value::List(vec![hello(), Value::Str(String::new())]))]);
    assert_eq!(hex_of(&as_list, &list_vals), format!("010200{HELLO}00"));
    let dict_vals = row(&[("d", map(Value::U8(7)))]);
    assert_eq!(hex_of(&as_dict, &dict_vals), format!("010100{HELLO}07"));
    let nested_vals = row(&[("d", map(Value::List(vec![hello()])))]);
    assert_eq!(
        hex_of(&value_list, &nested_vals),
        format!("010100{HELLO}0100{HELLO}")
    );
    for (scheme, vals) in [
        (&as_list, list_vals),
        (&as_dict, dict_vals),
        (&value_list, nested_vals),
    ] {
        let bytes = pack(scheme, &vals).expect("pack");
        assert_eq!(unpack(scheme, &bytes).expect("unpack"), vals);
    }
}

#[test]
fn ac3_a_repeat_a_times_and_a_flags_string_use_the_codec() {
    // Arrange
    let rounds = |texts: &[&str]| {
        Value::Groups(
            texts
                .iter()
                .map(|t| row(&[("s", Value::Str(t.to_string()))]))
                .collect(),
        )
    };
    let repeated = MapScheme::new(1, vec![repeat(0, vec![utf8("s")])]);
    let counted = MapScheme::new(1, vec![u32("n"), times(1, "n", vec![utf8("s")])]);
    let optional = MapScheme::new(1, vec![flags(0, "f", vec![utf8("note")])]);

    // Act and Assert: repeat
    let vals = row(&[("__repeat__", rounds(&["привіт", "Привіт, Світе!"]))]);
    assert_eq!(hex_of(&repeated, &vals), format!("01{HELLO}{HELLO_CAPS}"));
    assert_eq!(
        unpack(&repeated, &pack(&repeated, &vals).expect("pack")).expect("unpack"),
        vals
    );

    // times, with rounds and with one lone string for every round
    let by_rounds = row(&[
        ("n", Value::U32(2)),
        ("__times_1", rounds(&["привіт", "привіт"])),
    ]);
    let lone = row(&[("n", Value::U32(2)), ("s", hello())]);
    let want = format!("01020000 00{HELLO}{HELLO}").replace(' ', "");
    assert_eq!(hex_of(&counted, &by_rounds), want);
    assert_eq!(hex_of(&counted, &lone), want);
    let back = unpack(&counted, &from_hex(&want)).expect("unpack");
    assert_eq!(back["s"], Some(Value::List(vec![hello(), hello()])));

    // flags: absent adds 0 bytes, empty adds 1, a text adds its field
    let absent = Values::new();
    let empty = row(&[("note", Value::Str(String::new()))]);
    let present = row(&[("note", hello())]);
    assert_eq!(hex_of(&optional, &absent), "0100");
    assert_eq!(hex_of(&optional, &empty), "010100");
    assert_eq!(hex_of(&optional, &present), format!("0101{HELLO}"));
    assert_eq!(
        unpack(&optional, &from_hex("0100"))
            .expect("unpack")
            .get("note"),
        None
    );
    assert_eq!(
        unpack(&optional, &from_hex("010100")).expect("unpack")["note"],
        Some(Value::Str(String::new()))
    );
}

#[test]
fn ac5_a_text_of_65535_bytes_packs_and_one_of_65536_is_refused_naming_the_field() {
    // Arrange
    let scheme = MapScheme::new(1, vec![utf8("s")]);
    let unpackable = [
        "a".repeat(65535),
        "\t".repeat(65535),
        "я".repeat(32767) + "a",
    ];

    for text in unpackable {
        // Act
        let vals = row(&[("s", Value::Str(text.clone()))]);
        let bytes = pack(&scheme, &vals).expect("65,535 bytes pack");

        // Assert
        assert_eq!(
            unpack(&scheme, &bytes).expect("unpack")["s"],
            Some(Value::Str(text))
        );
    }
    let too_long = row(&[("s", Value::Str("a".repeat(65536)))]);
    assert_eq!(
        pack(&scheme, &too_long),
        Err(PackError::Type("s".to_string()))
    );
    let dict_scheme = MapScheme::new(1, vec![dict("d", u8("v"))]);
    let long_key = row(&[(
        "d",
        Value::Map(BTreeMap::from([("a".repeat(65536), Value::U8(1))])),
    )]);
    assert_eq!(
        pack(&dict_scheme, &long_key),
        Err(PackError::Type("d".to_string()))
    );
}

#[test]
fn ac5_the_count_is_one_byte_up_to_127_and_two_bytes_from_128() {
    // Arrange: a tab is in no alphabet, so the raw fallback makes the payload 1 + the text
    let scheme = MapScheme::new(1, vec![utf8("s")]);
    let tabs = |n: usize| row(&[("s", Value::Str("\t".repeat(n)))]);

    // Act
    let payload_127 = hex_of(&scheme, &tabs(126));
    let payload_128 = hex_of(&scheme, &tabs(127));

    // Assert
    assert_eq!(&payload_127[..6], "017f10");
    assert_eq!(payload_127.len(), 2 * (1 + 1 + 127));
    assert_eq!(&payload_128[..8], "01800110");
    assert_eq!(payload_128.len(), 2 * (1 + 2 + 128));
}

#[test]
fn ac5_max_bytes_bounds_the_packet_with_the_codec_field() {
    // Arrange
    let scheme = MapScheme::new(1, vec![utf8("s")]).with_max_bytes(1 + 6);

    // Act and Assert: "привіт" is 1 + 5 bytes, and one more character does not fit
    assert_eq!(
        pack(&scheme, &row(&[("s", hello())])).map(|b| b.len()),
        Ok(7)
    );
    let over = pack(&scheme, &row(&[("s", Value::Str("привіт, ".to_string()))]));
    assert!(matches!(over, Err(PackError::Type(m)) if m.starts_with("s: the packet would be ")));
}

#[test]
fn ac7_dictionary_keys_are_sorted_by_their_utf8_bytes_whatever_the_insert_order() {
    // Arrange
    let scheme = MapScheme::new(1, vec![dict("d", u8("v"))]);
    let keys = ["я", "а", "Б", "b"];
    let build = |order: &[&str]| {
        let mut map = BTreeMap::new();
        for key in order {
            map.insert(key.to_string(), Value::U8(1));
        }
        row(&[("d", Value::Map(map))])
    };

    // Act
    let forward = hex_of(&scheme, &build(&keys));
    let backward = hex_of(&scheme, &build(&[keys[3], keys[2], keys[1], keys[0]]));

    // Assert: b (62), Б (d0 91), а (d0 b0), я (d1 8f)
    let want = "010400 021062 01 0310d091 01 02c080 01 02a300 01".replace(' ', "");
    assert_eq!(forward, want);
    assert_eq!(backward, want);
    assert_eq!(
        unpack(&scheme, &from_hex(&want)).expect("unpack"),
        build(&keys)
    );
}

#[test]
fn ac7_a_repeated_decoded_key_is_refused_even_when_the_bytes_differ() {
    // Arrange
    let scheme = MapScheme::new(1, vec![dict("d", u8("v"))]);
    let same_bytes = from_hex("010200 02a300 01 02a300 02");
    // The second key is the escape form of я (vectors row alt.escape_for_letter).
    let other_bytes = from_hex("010200 02a300 01 05c3ff3463c0 02");

    // Act and Assert
    short_naming(unpack(&scheme, &same_bytes), "d");
    short_naming(unpack(&scheme, &other_bytes), "d");
}

#[test]
fn ac6_escape_bytes_that_are_not_utf8_and_a_raw_payload_that_is_not_utf8_are_refused() {
    // Arrange
    let scheme = MapScheme::new(1, vec![utf8("s")]);
    let bad_fields = [
        "05c3ff302000",   // an overlong escape
        "06c3ff3b682000", // a surrogate
        "04c3ff3fc0",     // a lead byte that cannot start a character
        "0310c328",       // raw payload with a bad continuation
        "0210ff",         // raw payload with a bad lead byte
    ];

    for field in bad_fields {
        // Act
        let result = unpack(&scheme, &from_hex(&format!("01{field}")));

        // Assert
        short_naming(result, "s");
        assert_eq!(decode_text(&from_hex(field)).expect_err(field).kind, "utf8");
    }
}

/// A small deterministic generator, so a failure reproduces.
struct Lcg(u64);

impl Lcg {
    fn next(&mut self) -> u64 {
        self.0 = self
            .0
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        self.0 >> 33
    }

    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
}

#[test]
fn random_texts_of_every_script_round_trip() {
    // Arrange
    let pool: Vec<char> = "абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'ёъыэАБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ \
        abcxyzABCXYZ0123456789.,-:;!?()\"%/@+=*#&_$\n\t\u{0}😀🎉中文日本語한국어ß€é\u{301}\u{200d}\u{feff}\u{10ffff}"
        .chars()
        .collect();
    let mut rng = Lcg(7);

    for round in 0..3000 {
        let len = rng.below(60);
        let text: String = (0..len).map(|_| pool[rng.below(pool.len())]).collect();

        // Act
        let field = encode_text(&text).expect("encodes");
        let back = decode_text(&field);

        // Assert
        assert_eq!(
            back,
            Ok((text.clone(), field.len())),
            "round {round}: {text:?}"
        );
        assert!(
            field.len() <= 3 + 1 + text.len() || text.is_empty(),
            "round {round}"
        );
    }
}

#[test]
fn random_payloads_never_panic_and_decode_to_at_most_six_bytes_per_byte_plus_eight() {
    // Arrange
    let mut rng = Lcg(11);

    for round in 0..30_000 {
        let n = 1 + rng.below(80);
        let mut payload: Vec<u8> = (0..n).map(|_| rng.next() as u8).collect();
        payload[0] = (payload[0] & 0x03) | (((round % 4) as u8) << 2);
        let mut field = vec![n as u8];
        field.extend_from_slice(&payload);

        // Act
        let result = decode_text(&field);

        // Assert
        if let Ok((text, used)) = result {
            assert_eq!(used, field.len());
            assert!(
                text.len() <= 6 * n + 8,
                "round {round}: {} bytes from {n}",
                text.len()
            );
        }
    }
}

#[test]
fn the_longest_runs_decode_within_the_bound_and_the_limit() {
    // Arrange: 64 KiB payloads of zeros and of ones, in every start mode
    for mode in 0..4u8 {
        for fill in [0x00u8, 0xff] {
            let mut payload = vec![fill; 40_000];
            payload[0] = mode << 2;
            payload[1] = fill;
            let mut field = vec![
                0x80 | (payload.len() & 0x7f) as u8,
                0x80 | ((payload.len() >> 7) & 0x7f) as u8,
            ];
            field.push((payload.len() >> 14) as u8);
            field.extend_from_slice(&payload);

            // Act
            let result = decode_text(&field);

            // Assert
            if let Ok((text, _)) = result {
                assert!(text.len() <= 65535);
            }
        }
    }
}

fn ukrainian_texts() -> Vec<String> {
    let sentence = "Швидка бура лисиця стрибає через ледачого собаку, а мудра сова \
        спостерігає за ними з високої гілки старого дуба біля річки Дніпро";
    let chars: Vec<char> = sentence.chars().collect();
    (0..chars.len() - 20)
        .map(|at| chars[at..at + 20].iter().collect())
        .collect()
}

#[test]
fn ac8_one_hundred_thousand_round_trips_of_a_20_character_ukrainian_string() {
    // Arrange: 100,000 round trips over different 20-character windows of one sentence
    let scheme = MapScheme::new(1, vec![utf8("s")]);
    let texts = ukrainian_texts();
    let vals: Vec<Values> = texts
        .iter()
        .map(|t| row(&[("s", Value::Str(t.clone()))]))
        .collect();
    // The 1 s bound is for the optimized build; `cargo test` runs unoptimized code, about 6 times slower.
    let bound = if cfg!(debug_assertions) { 6.0 } else { 1.0 };
    let started = Instant::now();

    // Act
    for i in 0..100_000 {
        let which = i % texts.len();
        let bytes = pack(&scheme, &vals[which]).expect("pack");
        let back = unpack(&scheme, &bytes).expect("unpack");
        assert_eq!(back["s"], Some(Value::Str(texts[which].clone())));
    }
    let elapsed = started.elapsed().as_secs_f64();

    // Assert
    eprintln!("text speed: 100000 round trips in {elapsed:.3} s (bound {bound} s)");
    assert!(elapsed <= bound, "{elapsed:.3} s > {bound} s");
}
