use packbin::{
    flags, i16, pack, to_hex, u16, u8, unpack, unpack_with, BoundField, Scheme, ShortPacket,
    UnpackError,
};

fn parse_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

#[derive(Default, Debug)]
struct SidRow {
    sid: u8,
}

fn sid_scheme() -> Scheme<SidRow> {
    Scheme::new(
        32,
        [BoundField::u8(0, |r: &SidRow| r.sid, |r: &mut SidRow, v| r.sid = v).into()],
    )
}

#[derive(Default)]
struct UserModifiedEvent {
    user_id: i32,
    user_name_change: String,
    user_email_change: String,
    user_status_change: u8,
}

#[derive(Default, Debug, PartialEq)]
struct UserPositionEvent {
    user_id: i32,
    latitude: i32,
    longitude: i32,
}

fn modified_scheme() -> Scheme<UserModifiedEvent> {
    Scheme::new(
        1,
        [
            BoundField::i32(
                0,
                |r: &UserModifiedEvent| r.user_id,
                |r: &mut UserModifiedEvent, v| r.user_id = v,
            )
            .into(),
            BoundField::utf8(
                1,
                |r: &UserModifiedEvent| r.user_name_change.clone(),
                |r: &mut UserModifiedEvent, v| r.user_name_change = v,
            )
            .into(),
            BoundField::utf8(
                2,
                |r: &UserModifiedEvent| r.user_email_change.clone(),
                |r: &mut UserModifiedEvent, v| r.user_email_change = v,
            )
            .into(),
            BoundField::u8(
                3,
                |r: &UserModifiedEvent| r.user_status_change,
                |r: &mut UserModifiedEvent, v| r.user_status_change = v,
            )
            .into(),
        ],
    )
}

fn position_event_scheme() -> Scheme<UserPositionEvent> {
    Scheme::new(
        2,
        [
            BoundField::i32(
                0,
                |r: &UserPositionEvent| r.user_id,
                |r: &mut UserPositionEvent, v| r.user_id = v,
            )
            .into(),
            BoundField::i32(
                1,
                |r: &UserPositionEvent| r.latitude,
                |r: &mut UserPositionEvent, v| r.latitude = v,
            )
            .into(),
            BoundField::i32(
                2,
                |r: &UserPositionEvent| r.longitude,
                |r: &mut UserPositionEvent, v| r.longitude = v,
            )
            .into(),
        ],
    )
}

#[derive(Default)]
struct PositionRow {
    sid: u16,
    lat: i32,
    lon: i32,
    profile: u8,
}

fn position_row_scheme() -> Scheme<PositionRow> {
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
            flags(
                "motion",
                vec![u16("heading"), u8("speed"), i16("altitude")],
            )
            .into(),
        ],
    )
}

#[test]
fn ac1_scheme_replaces_packet() {
    let source = include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/src/lib.rs"));
    assert!(!source.contains("BinaryPacker"));
    assert!(!source.contains("type_num"));
    assert!(!source.contains(" packet,"));
    assert!(!source.contains(" Packet"));
    let row = SidRow { sid: 23 };
    let bytes = pack(&sid_scheme(), &row).expect("pack");
    assert_eq!(to_hex(&bytes), "2017");
}

#[test]
fn ac2_position_row_no_type_member() {
    let row = PositionRow {
        sid: 1,
        lat: 500_000_000,
        lon: 300_000_000,
        profile: 1,
    };
    let bytes = pack(&position_row_scheme(), &row).expect("pack");
    assert_eq!(to_hex(&bytes), "4001000065cd1d00a3e1110100");
    let source = include_str!("scheme_tests.rs");
    let start = source.find("struct PositionRow").expect("PositionRow");
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
fn ac3_known_scheme_checks_leading_byte() {
    match unpack(&sid_scheme(), &parse_hex("2117")) {
        Err(UnpackError::Type { expected, actual }) => {
            assert_eq!(expected, 32);
            assert_eq!(actual, 33);
        }
        Ok(_) => panic!("expected UnpackError::Type, got row"),
        Err(other) => panic!("expected UnpackError::Type, got {:?}", other),
    }
}

#[test]
fn ac3_empty_buffer_short_packet() {
    match unpack::<SidRow>(&sid_scheme(), &[]) {
        Err(UnpackError::Short(ShortPacket {
            field,
            needed,
            left,
        })) => {
            assert_eq!(field, "");
            assert_eq!(needed, 1);
            assert_eq!(left, 0);
        }
        other => panic!("expected ShortPacket, got {:?}", other),
    }
}

#[test]
fn ac4_unknown_buffer_calls_matching_handler() {
    let bytes = parse_hex("02070000000800000009000000");
    let mut modified_called = false;
    let mut position_got = None;
    let modified = modified_scheme();
    let position = position_event_scheme();
    let mut on_modified = modified.on(|_ev| {
        modified_called = true;
    });
    let mut on_position = position.on(|ev| {
        position_got = Some(ev);
    });
    unpack_with(&bytes, &mut [&mut on_modified, &mut on_position]).expect("dispatch");
    assert!(!modified_called);
    assert_eq!(
        position_got,
        Some(UserPositionEvent {
            user_id: 7,
            latitude: 8,
            longitude: 9,
        })
    );
    let source = include_str!("scheme_tests.rs");
    let start = source
        .find("struct UserPositionEvent")
        .expect("UserPositionEvent");
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
    assert!(!body.contains("type"));
}

#[test]
fn ac5_unknown_type_number() {
    let bytes = parse_hex("09070000000800000009000000");
    let mut modified_called = false;
    let mut position_called = false;
    let modified = modified_scheme();
    let position = position_event_scheme();
    let mut on_modified = modified.on(|_ev| {
        modified_called = true;
    });
    let mut on_position = position.on(|_ev| {
        position_called = true;
    });
    match unpack_with(&bytes, &mut [&mut on_modified, &mut on_position]) {
        Err(UnpackError::Type { actual, .. }) => assert_eq!(actual, 9),
        other => panic!("expected Type error, got {:?}", other),
    }
    assert!(!modified_called);
    assert!(!position_called);
}

#[test]
fn ac6_type_numbers_unique() {
    let modified = modified_scheme();
    let other = Scheme::new(
        1,
        [BoundField::i32(
            0,
            |r: &UserPositionEvent| r.user_id,
            |r: &mut UserPositionEvent, v| r.user_id = v,
        )
        .into()],
    );
    let mut on_a = modified.on(|_ev| {});
    let mut on_b = other.on(|_ev| {});
    match unpack_with(&[1], &mut [&mut on_a, &mut on_b]) {
        Err(UnpackError::DuplicateType { type_number }) => assert_eq!(type_number, 1),
        other => panic!("expected DuplicateType, got {:?}", other),
    }
}

#[test]
fn type_number_range() {
    assert!(std::panic::catch_unwind(|| {
        let _ = Scheme::<SidRow>::new(256, []);
    })
    .is_err());
    assert!(std::panic::catch_unwind(|| {
        let _ = Scheme::<SidRow>::new(-1, []);
    })
    .is_err());
}

#[test]
fn scheme_argument_is_required() {
    use std::fs;
    use std::process::Command;
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
