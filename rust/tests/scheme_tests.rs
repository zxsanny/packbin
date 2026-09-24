use packbin::{
    flags, i16, i32, insert, mismatched_bytes, pack, packet, to_hex, type_num, u16, u8,
    BinaryPacker, BoundField, Scheme, UnpackError, Value, Values,
};
use std::fs;
use std::process::Command;

#[derive(Default)]
struct MarkerRow {
    sid: u8,
}

fn marker_row_scheme() -> Scheme<MarkerRow> {
    Scheme::of([
        type_num(32).into(),
        BoundField::u8(
            "sid",
            |r: &MarkerRow| r.sid,
            |r: &mut MarkerRow, v| r.sid = v,
        )
        .into(),
    ])
}

fn position_packet() -> packbin::Packet {
    packet(vec![
        u8("type"),
        u16("sid"),
        i32("lat"),
        i32("lon"),
        u8("profile"),
        flags(
            "motion",
            vec![u16("heading"), u8("speed"), i16("altitude")],
        ),
    ])
}

fn position_values() -> Values {
    let mut v = Values::new();
    insert(&mut v, "type", Some(Value::U8(64)));
    insert(&mut v, "sid", Some(Value::U16(1)));
    insert(&mut v, "lat", Some(Value::I32(500_000_000)));
    insert(&mut v, "lon", Some(Value::I32(300_000_000)));
    insert(&mut v, "profile", Some(Value::U8(1)));
    v
}

fn parse_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

#[test]
fn ac1_pack_takes_the_scheme() {
    let row = MarkerRow { sid: 23 };
    let bytes = BinaryPacker::pack(&marker_row_scheme(), &row).expect("pack");
    assert_eq!(to_hex(&bytes), "2017");
    assert_eq!(bytes, vec![0x20, 0x17]);
}

#[test]
fn ac2_unpack_takes_the_same_scheme() {
    let back = BinaryPacker::unpack(&marker_row_scheme(), &parse_hex("2017")).expect("unpack");
    assert_eq!(back.sid, 23);
    let source = include_str!("scheme_tests.rs");
    let start = source
        .find("struct MarkerRow")
        .expect("MarkerRow");
    let brace = source[start..].find('{').expect("{") + start;
    let mut depth = 0;
    let mut end = brace;
    for (i, ch) in source[brace..].char_indices() {
        match ch {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if depth == 0 {
                    end = brace + i;
                    break;
                }
            }
            _ => {}
        }
    }
    let body = &source[start..=end];
    assert!(body.contains("sid"));
    assert!(!body.contains("type"));
}

#[test]
fn ac3_scheme_argument_is_required() {
    let manifest = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/tests/compile-fail/pack_without_scheme/Cargo.toml"
    );
    assert!(
        fs::metadata(manifest).is_ok(),
        "missing compile-fail fixture {manifest}"
    );
    let target_dir = concat!(env!("CARGO_MANIFEST_DIR"), "/target/compile-fail-pack");
    let output = Command::new("cargo")
        .args([
            "check",
            "--manifest-path",
            manifest,
            "--target-dir",
            target_dir,
        ])
        .output()
        .expect("cargo check");
    assert!(
        !output.status.success(),
        "expected compile failure, exit={:?}\n{}\n{}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr),
    );
}

#[test]
fn ac4_wrong_type_byte() {
    match BinaryPacker::unpack(&marker_row_scheme(), &parse_hex("2117")) {
        Err(UnpackError::Type { expected, actual }) => {
            assert_eq!(expected, 32);
            assert_eq!(actual, 33);
        }
        Ok(_) => panic!("expected UnpackError::Type, got row"),
        Err(other) => panic!("expected UnpackError::Type, got {:?}", other),
    }
}

#[test]
fn ac5_untyped_path() {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/../fixtures/golden.hex");
    let fixture = fs::read_to_string(path).expect("golden.hex").trim().to_string();
    let packed = pack(&position_packet(), &position_values()).expect("pack");
    assert_eq!(to_hex(&packed), fixture);
    assert_eq!(mismatched_bytes(&packed, &parse_hex(&fixture)), 0);
}

#[test]
fn ac6_row_stays_data() {
    let source = include_str!("scheme_tests.rs");
    let start = source
        .find("struct MarkerRow")
        .expect("MarkerRow");
    let brace = source[start..].find('{').expect("{") + start;
    let mut depth = 0;
    let mut end = brace;
    for (i, ch) in source[brace..].char_indices() {
        match ch {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if depth == 0 {
                    end = brace + i;
                    break;
                }
            }
            _ => {}
        }
    }
    let body = &source[start..=end];
    assert!(body.contains("sid"));
    assert!(!body.contains("Scheme"));
    assert!(!body.contains("Pack"));
    assert!(!body.contains("BinaryPacker"));
    assert!(!body.contains("fn "));
}
