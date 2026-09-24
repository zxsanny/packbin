use packbin::{
    be, bytes, eq, f32, f64, flag_byte, flags, group, i16, i32, insert, mismatched_bytes,
    motion_field_count, pack_map, repeat, to_hex, u16, u8, unpack_map, when, MapScheme, ShortPacket,
    UnpackError, Value, Values,
};
use std::fs;
use std::time::Instant;

fn position_scheme() -> MapScheme {
    MapScheme::new(
        0x40,
        vec![
            u16("sid"),
            i32("lat"),
            i32("lon"),
            u8("profile"),
            flags(
                "motion",
                vec![u16("heading"), u8("speed"), i16("altitude")],
            ),
        ],
    )
}

fn position_values() -> Values {
    let mut v = Values::new();
    insert(&mut v, "sid", Some(Value::U16(1)));
    insert(&mut v, "lat", Some(Value::I32(500_000_000)));
    insert(&mut v, "lon", Some(Value::I32(300_000_000)));
    insert(&mut v, "profile", Some(Value::U8(1)));
    v
}

const GOLDEN_HEX: &str = "4001000065cd1d00a3e1110100";

fn parse_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

#[test]
fn ac1_position_pack() {
    let packed = pack_map(&position_scheme(), &position_values()).expect("pack");
    let hex = to_hex(&packed);
    assert_eq!(hex, GOLDEN_HEX);
    assert_eq!(mismatched_bytes(&packed, &parse_hex(GOLDEN_HEX)), 0);
    assert_eq!(packed.len(), 13);
    let again = pack_map(&position_scheme(), &position_values()).expect("pack again");
    assert_eq!(mismatched_bytes(&packed, &again), 0);
}

#[test]
fn ac2_position_unpack() {
    let got = unpack_map(&position_scheme(), &parse_hex(GOLDEN_HEX)).expect("unpack");
    assert!(!got.contains_key("type"));
    assert_eq!(got.get("sid"), Some(&Some(Value::U16(1))));
    assert_eq!(got.get("lat"), Some(&Some(Value::I32(500_000_000))));
    assert_eq!(got.get("lon"), Some(&Some(Value::I32(300_000_000))));
    assert_eq!(got.get("profile"), Some(&Some(Value::U8(1))));
    assert_eq!(motion_field_count(&got), 0);
    assert!(!got.contains_key("heading"));
    assert!(!got.contains_key("speed"));
    assert!(!got.contains_key("altitude"));
}

#[test]
fn ac3_bytes_match_fixture() {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/../fixtures/golden.hex");
    let fixture = fs::read_to_string(path).expect("golden.hex").trim().to_string();
    let packed = pack_map(&position_scheme(), &position_values()).expect("pack");
    assert_eq!(to_hex(&packed), fixture);
    assert_eq!(mismatched_bytes(&packed, &parse_hex(&fixture)), 0);
}

#[test]
fn ac4_flags_and_stored_zero() {
    let scheme = MapScheme::new(
        0x40,
        vec![flags(
            "opts",
            vec![
                u8("b0"),
                u8("b1"),
                u8("b2"),
                u8("b3"),
                u8("b4"),
                u16("b5"),
            ],
        )],
    );

    let clear = Values::new();
    let clear_bytes = pack_map(&scheme, &clear).expect("pack clear");
    assert_eq!(clear_bytes.len(), 2);
    assert_eq!(clear_bytes[0], 0x40);
    assert_eq!(clear_bytes[1], 0x00);

    let mut set = Values::new();
    insert(&mut set, "b5", Some(Value::U16(0x1234)));
    let set_bytes = pack_map(&scheme, &set).expect("pack set");
    assert_eq!(set_bytes.len(), 4);
    assert_eq!(set_bytes[1], 0x20);
    assert_eq!(set_bytes.len() - clear_bytes.len(), 2);

    let mut zero = Values::new();
    insert(&mut zero, "b5", Some(Value::U16(0)));
    let zero_bytes = pack_map(&scheme, &zero).expect("pack zero");
    assert_eq!(zero_bytes.len(), 4);
    assert_eq!(zero_bytes[1], 0x20);
    assert_eq!(&zero_bytes[2..], &[0x00, 0x00]);

    let mut absent = Values::new();
    insert(&mut absent, "b5", None);
    let absent_bytes = pack_map(&scheme, &absent).expect("pack absent");
    assert_eq!(absent_bytes.len(), 2);
    assert_eq!(absent_bytes[1], 0x00);
    assert_eq!(absent_bytes.len(), clear_bytes.len());
    assert_ne!(zero_bytes.len(), absent_bytes.len());
}

#[test]
fn ac5_short_buffer_then_position_pack() {
    let scheme = MapScheme::new(
        1,
        vec![flags(
            "opts",
            vec![
                u8("b0"),
                u8("b1"),
                u8("b2"),
                u8("b3"),
                u8("b4"),
                u16("wide"),
            ],
        )],
    );
    let short = [0x01u8, 0x20, 0x34];
    let err = unpack_map(&scheme, &short).expect_err("short");
    match err {
        UnpackError::Short(ShortPacket {
            field,
            needed,
            left,
        }) => {
            assert_eq!(field, "wide");
            assert_eq!(needed, 2);
            assert_eq!(left, 1);
        }
        other => panic!("expected ShortPacket, got {:?}", other),
    }

    let packed = pack_map(&position_scheme(), &position_values()).expect("pack after short");
    assert_eq!(to_hex(&packed), GOLDEN_HEX);
}

#[test]
fn nfr_round_trips_under_one_second() {
    let scheme = position_scheme();
    let vals = position_values();
    let start = Instant::now();
    let mut last = Values::new();
    for _ in 0..100_000 {
        let packed = pack_map(&scheme, &vals).expect("pack");
        last = unpack_map(&scheme, &packed).expect("unpack");
    }
    let elapsed = start.elapsed();
    assert!(!last.contains_key("type"));
    assert_eq!(last.get("lat"), Some(&Some(Value::I32(500_000_000))));
    assert_no_gpu();
    assert!(
        elapsed.as_secs_f64() <= 1.0,
        "elapsed {:?} > 1s",
        elapsed
    );
    eprintln!("nfr elapsed_ms {:.1}", elapsed.as_secs_f64() * 1000.0);
}

#[test]
fn when_group_width() {
    let scheme = MapScheme::new(
        1,
        vec![
            u8("profile"),
            when(eq("profile", Value::U8(0)), vec![u8("shape")]),
        ],
    );
    let mut miss = Values::new();
    insert(&mut miss, "profile", Some(Value::U8(1)));
    insert(&mut miss, "shape", Some(Value::U8(9)));
    assert_eq!(pack_map(&scheme, &miss).unwrap().len(), 2);

    let mut hit = Values::new();
    insert(&mut hit, "profile", Some(Value::U8(0)));
    insert(&mut hit, "shape", Some(Value::U8(9)));
    assert_eq!(pack_map(&scheme, &hit).unwrap().len(), 3);
}

#[test]
fn repeat_groups_and_leftover() {
    let scheme = MapScheme::new(1, vec![u16("sid"), repeat(vec![i32("lat"), i32("lon")])]);
    let mut vals = Values::new();
    insert(&mut vals, "sid", Some(Value::U16(2)));
    let mut g1 = Values::new();
    insert(&mut g1, "lat", Some(Value::I32(10)));
    insert(&mut g1, "lon", Some(Value::I32(20)));
    insert(&mut vals, "__repeat__", Some(Value::Groups(vec![g1])));
    let packed = pack_map(&scheme, &vals).unwrap();
    let got = unpack_map(&scheme, &packed).unwrap();
    match got.get("__repeat__") {
        Some(Some(Value::Groups(g))) => assert_eq!(g.len(), 1),
        other => panic!("expected one group, got {:?}", other),
    }

    let mut leftover = packed;
    leftover.push(0xff);
    let err = unpack_map(&scheme, &leftover).expect_err("leftover");
    match err {
        UnpackError::Short(ShortPacket { field, .. }) => {
            assert!(field == "lat" || field == "lon");
        }
        other => panic!("expected short on leftover, got {:?}", other),
    }
}

#[test]
fn trailing_bytes_error() {
    let scheme = MapScheme::new(1, vec![u16("sid")]);
    let err = unpack_map(&scheme, &[1, 2, 3, 4]).expect_err("trailing");
    assert!(matches!(err, UnpackError::Trailing { left: 1 }));
}

#[test]
fn split_flag_byte_and_be() {
    let motion = flag_byte("motion");
    let scheme = MapScheme::new(
        1,
        vec![
            motion.byte(),
            when(eq("type", Value::U8(0)), vec![u8("shape")]),
            motion.bit(u16("heading")),
            motion.bit(u8("speed")),
        ],
    );
    let mut vals = Values::new();
    insert(&mut vals, "heading", Some(Value::U16(90)));
    let packed = pack_map(&scheme, &vals).unwrap();
    assert_eq!(packed[0], 0x01);
    assert_eq!(packed[1], 0x01);
    assert_eq!(packed.len(), 4);

    let be_scheme = MapScheme::new(1, vec![be(u16("sid"))]);
    let mut be_vals = Values::new();
    insert(&mut be_vals, "sid", Some(Value::U16(0x0102)));
    assert_eq!(pack_map(&be_scheme, &be_vals).unwrap(), vec![0x01, 0x01, 0x02]);

    let mut float_vals = Values::new();
    insert(&mut float_vals, "x", Some(Value::F32(1.0)));
    insert(&mut float_vals, "y", Some(Value::F64(2.0)));
    insert(&mut float_vals, "z", Some(Value::Bytes(vec![9, 8])));
    let float_scheme = MapScheme::new(1, vec![f32("x"), f64("y"), bytes("z", 2)]);
    assert_eq!(pack_map(&float_scheme, &float_vals).unwrap().len(), 15);
}

fn assert_no_gpu() {
    let Ok(text) = std::fs::read_to_string("/proc/self/maps") else {
        return;
    };
    let blob = text.to_ascii_lowercase();
    for bad in [
        "libcuda",
        "libnvidia",
        "libvulkan",
        "libopencl",
        "metal.framework",
    ] {
        assert!(!blob.contains(bad), "{bad}");
    }
}

#[test]
fn empty_group_flag() {
    let scheme = MapScheme::new(1, vec![flags("f", vec![group("mark", vec![])])]);
    let mut set = Values::new();
    insert(&mut set, "mark", Some(Value::U8(1)));
    assert_eq!(pack_map(&scheme, &set).unwrap(), vec![0x01, 0x01]);
    let clear = Values::new();
    assert_eq!(pack_map(&scheme, &clear).unwrap(), vec![0x01, 0x00]);
}

#[test]
fn flags_five_u8_then_u16() {
    let scheme = MapScheme::new(
        1,
        vec![flags(
            "f",
            vec![
                u8("a"),
                u8("b"),
                u8("c"),
                u8("d"),
                u8("e"),
                u16("b5"),
            ],
        )],
    );
    let mut a = Values::new();
    insert(&mut a, "a", Some(Value::U8(1)));
    assert_eq!(pack_map(&scheme, &a).unwrap().len(), 3);

    let mut b5 = Values::new();
    insert(&mut b5, "b5", Some(Value::U16(1)));
    let wide = pack_map(&scheme, &b5).unwrap();
    assert_eq!(wide[1], 0x20);
    let clear = pack_map(&scheme, &Values::new()).unwrap();
    assert_eq!(wide.len() - clear.len(), 2);
}

#[test]
fn session_group_pack_unpack() {
    let scheme = MapScheme::new(
        1,
        vec![flags(
            "f",
            vec![group("session", vec![u16("login"), packbin::u32("ts")])],
        )],
    );
    let mut vals = Values::new();
    insert(&mut vals, "login", Some(Value::U16(7)));
    insert(&mut vals, "ts", Some(Value::U32(1000)));
    let raw = pack_map(&scheme, &vals).unwrap();
    assert_eq!(to_hex(&raw[2..]), "0700e8030000");
    assert_eq!(raw.len() - 2, 6);

    let clear = pack_map(&scheme, &Values::new()).unwrap();
    assert_eq!(clear, vec![0x01, 0x00]);
    let got = unpack_map(&scheme, &clear).unwrap();
    assert!(!got.contains_key("login"));
    assert!(!got.contains_key("ts"));
}

#[test]
fn group_one_u8_zero() {
    let scheme = MapScheme::new(1, vec![flags("f", vec![group("g", vec![u8("b")])])]);
    let mut vals = Values::new();
    insert(&mut vals, "b", Some(Value::U8(0)));
    assert_eq!(pack_map(&scheme, &vals).unwrap(), vec![0x01, 0x01, 0x00]);
}

#[test]
fn session_group_short_read() {
    let scheme = MapScheme::new(
        1,
        vec![flags(
            "f",
            vec![group("session", vec![u16("login"), packbin::u32("ts")])],
        )],
    );
    let err = unpack_map(&scheme, &[0x01, 0x01, 0x07]).expect_err("short");
    match err {
        UnpackError::Short(ShortPacket {
            field,
            needed,
            left,
        }) => {
            assert_eq!(field, "login");
            assert_eq!(needed, 2);
            assert_eq!(left, 1);
        }
        other => panic!("expected ShortPacket, got {:?}", other),
    }
}

#[test]
fn map_scheme_type_number_range() {
    assert!(std::panic::catch_unwind(|| {
        let _ = MapScheme::new(256, vec![]);
    })
    .is_err());
}
