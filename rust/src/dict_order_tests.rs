use crate::hostile_tests::within_one_second;
use crate::walk::{decode_text, encode_text, pack, unpack};
use crate::{dict, insert, u8, MapScheme, UnpackError, Value, Values};
use std::collections::BTreeMap;
use std::time::Instant;

// AZ-2713: a decoded dict key must be greater than the one before it, compared as UTF-8 bytes; a key
// given twice or out of order is refused with the dict-key error. AZ-2722 F60: a decoded string keeps
// no spare capacity.

fn dict_scheme() -> MapScheme {
    MapScheme::new(1, vec![dict("m", u8("v"))])
}

/// A type 1 packet of a dict of u8 with the keys in the order given, each in the raw text form
/// (0x10, then the UTF-8 bytes) and holding the value 0.
fn dict_packet(keys: &[&str]) -> Vec<u8> {
    let mut raw = vec![1, keys.len() as u8, (keys.len() >> 8) as u8];
    for key in keys {
        if key.is_empty() {
            raw.push(0);
        } else {
            raw.push(key.len() as u8 + 1);
            raw.push(0x10);
            raw.extend_from_slice(key.as_bytes());
        }
        raw.push(0);
    }
    raw
}

fn refused() -> Result<(), UnpackError> {
    Err(UnpackError::Short(crate::ShortPacket {
        field: "m".to_string(),
        needed: 0,
        left: 0,
    }))
}

#[test]
fn dict_keys_ascending_utf8_bytes_are_accepted() {
    let scheme = dict_scheme();
    let accepted: [&[&str]; 6] = [
        &["a", "b", "c"],
        &["", "a"],
        &["a", "ab"],
        &["\u{ff5e}", "\u{10000}"],
        &["z"],
        &[],
    ];
    for keys in accepted {
        let got = unpack(&scheme, &dict_packet(keys)).map_err(|e| format!("{keys:?}: {e:?}"));
        match got.expect("accepted").get("m") {
            Some(Some(Value::Map(map))) => assert_eq!(map.len(), keys.len(), "{keys:?}"),
            other => panic!("{keys:?}: {other:?}"),
        }
    }
}

#[test]
fn dict_keys_repeated_or_out_of_order_are_refused() {
    let scheme = dict_scheme();
    let refusals: [&[&str]; 9] = [
        &["b", "a"],
        &["a", "a"],
        &["", ""],
        &["a", ""],
        &["ab", "a"],
        &["\u{10000}", "\u{ff5e}"],
        &["a", "b", "a"],
        &["a", "b", "b"],
        &["a", "c", "b"],
    ];
    for keys in refusals {
        let result = unpack(&scheme, &dict_packet(keys)).map(|_| ());
        assert_eq!(result, refused(), "{keys:?}");
    }
}

// AZ-2713 AC-3: 65,535 distinct ascending keys packed by the package and unpacked. A release build
// takes at most 1 s (the fastest of up to three passes counts: one stall on a loaded machine does not
// fail it, a real slowdown makes every pass slow). A debug build is 13 times slower (about 0.7 s here),
// too close to 1 s under load, so it asserts linear cost against a load-aware reference instead: the
// unpack takes at most 5 times the pack of the same dict (both linear; a quadratic key check is over
// 100 times) and at most 10 s.
#[test]
fn dict_keys_65535_ascending_keys_pack_and_unpack_within_one_second() {
    let scheme = dict_scheme();
    let map: BTreeMap<String, Value> = (0..65535)
        .map(|i| (format!("key{i:05}"), Value::U8(i as u8)))
        .collect();
    let mut vals = Values::new();
    insert(&mut vals, "m", Some(Value::Map(map)));
    let mut whole = f64::MAX;
    let mut ratio = f64::MAX;
    for _ in 0..3 {
        let start = Instant::now();
        let raw = pack(&scheme, &vals).expect("pack");
        let packed = start.elapsed().as_secs_f64();
        let back = unpack(&scheme, &raw).expect("unpack");
        let total = start.elapsed().as_secs_f64();
        assert_eq!(back, vals);
        whole = whole.min(total);
        ratio = ratio.min((total - packed) / packed);
        if whole <= 1.0 && (!cfg!(debug_assertions) || ratio <= 5.0) {
            break;
        }
    }
    eprintln!("dict 65535 keys: fastest {:.1} ms, unpack/pack {:.2}", whole * 1000.0, ratio);
    if cfg!(debug_assertions) {
        assert!(ratio <= 5.0, "unpack takes {ratio} times the pack");
        assert!(whole <= 10.0, "fastest pass {whole} s > 10 s");
    } else {
        assert!(whole <= 1.0, "fastest pass {whole} s > 1 s");
    }
}

#[test]
fn dict_keys_65535_descending_keys_are_refused_within_one_second() {
    let result = within_one_second("65535 descending keys", || {
        let keys: Vec<String> = (0..65535).rev().map(|i| format!("k{i:05}")).collect();
        let refs: Vec<&str> = keys.iter().map(String::as_str).collect();
        unpack(&dict_scheme(), &dict_packet(&refs)).map(|_| ())
    });
    assert_eq!(result, refused());
}

// F60: capacity == len for the compact and the raw form, short and at the 65,535 byte limit.
#[test]
fn decoded_string_keeps_no_spare_capacity() {
    let texts = [
        "a".to_string(),
        "привіт, друже".to_string(),
        "a".repeat(1000),
        "a".repeat(65535),
        "ж".repeat(32767),
        "Доброго ранку, друже. ".repeat(100),
        "\u{10000}".repeat(16383),
        "~".repeat(65535),
    ];
    for text in texts {
        let field = encode_text(&text).expect("encodes");
        let (back, used) = decode_text(&field).expect("decodes");
        assert_eq!(back, text);
        assert_eq!(used, field.len());
        assert_eq!(back.capacity(), back.len(), "{} bytes", text.len());
    }
}
