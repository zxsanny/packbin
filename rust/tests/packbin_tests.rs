use packbin::{
    be, bits, bytes, dict, eq, f32, f64, flag_byte, flags, group, i16, i32, insert, list,
    mismatched_bytes, motion_field_count, pack, packet, repeat, sized, to_hex, u16, u2, u32, u8,
    unpack, utf8, when, PackError, ShortPacket, UnpackError, Value, Values,
};
use std::collections::BTreeMap;
use std::fs;
use std::time::Instant;

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

const GOLDEN_HEX: &str = "4001000065cd1d00a3e1110100";

fn parse_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

#[test]
fn ac1_position_pack() {
    let packed = pack(&position_packet(), &position_values()).expect("pack");
    let hex = to_hex(&packed);
    assert_eq!(hex, GOLDEN_HEX);
    assert_eq!(mismatched_bytes(&packed, &parse_hex(GOLDEN_HEX)), 0);
    assert_eq!(packed.len(), 13);
    let again = pack(&position_packet(), &position_values()).expect("pack again");
    assert_eq!(mismatched_bytes(&packed, &again), 0);
}

#[test]
fn ac2_position_unpack() {
    let got = unpack(&position_packet(), &parse_hex(GOLDEN_HEX)).expect("unpack");
    assert_eq!(got.get("type"), Some(&Some(Value::U8(64))));
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
    let packed = pack(&position_packet(), &position_values()).expect("pack");
    assert_eq!(to_hex(&packed), fixture);
    assert_eq!(mismatched_bytes(&packed, &parse_hex(&fixture)), 0);
}

#[test]
fn ac4_flags_and_stored_zero() {
    let pkt = packet(vec![
        u8("type"),
        flags(
            "opts",
            vec![
                u8("b0"),
                u8("b1"),
                u8("b2"),
                u8("b3"),
                u8("b4"),
                u16("b5"),
            ],
        ),
    ]);

    let mut clear = Values::new();
    insert(&mut clear, "type", Some(Value::U8(0x40)));
    let clear_bytes = pack(&pkt, &clear).expect("pack clear");
    assert_eq!(clear_bytes.len(), 2);
    assert_eq!(clear_bytes[1], 0x00);

    let mut set = Values::new();
    insert(&mut set, "type", Some(Value::U8(0x40)));
    insert(&mut set, "b5", Some(Value::U16(0x1234)));
    let set_bytes = pack(&pkt, &set).expect("pack set");
    assert_eq!(set_bytes.len(), 4);
    assert_eq!(set_bytes[1], 0x20);
    assert_eq!(set_bytes.len() - clear_bytes.len(), 2);

    let mut zero = Values::new();
    insert(&mut zero, "type", Some(Value::U8(0x40)));
    insert(&mut zero, "b5", Some(Value::U16(0)));
    let zero_bytes = pack(&pkt, &zero).expect("pack zero");
    assert_eq!(zero_bytes.len(), 4);
    assert_eq!(zero_bytes[1], 0x20);
    assert_eq!(&zero_bytes[2..], &[0x00, 0x00]);

    let mut absent = Values::new();
    insert(&mut absent, "type", Some(Value::U8(0x40)));
    insert(&mut absent, "b5", None);
    let absent_bytes = pack(&pkt, &absent).expect("pack absent");
    assert_eq!(absent_bytes.len(), 2);
    assert_eq!(absent_bytes[1], 0x00);
    assert_eq!(absent_bytes.len(), clear_bytes.len());
    assert_ne!(zero_bytes.len(), absent_bytes.len());
}

#[test]
fn ac5_short_buffer_then_position_pack() {
    let pkt = packet(vec![flags(
        "opts",
        vec![
            u8("b0"),
            u8("b1"),
            u8("b2"),
            u8("b3"),
            u8("b4"),
            u16("wide"),
        ],
    )]);
    let short = [0x20u8, 0x34];
    let err = unpack(&pkt, &short).expect_err("short");
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

    let packed = pack(&position_packet(), &position_values()).expect("pack after short");
    assert_eq!(to_hex(&packed), GOLDEN_HEX);
}

#[test]
fn nfr_round_trips_under_one_second() {
    let pkt = position_packet();
    let vals = position_values();
    let start = Instant::now();
    let mut last = Values::new();
    for _ in 0..100_000 {
        let packed = pack(&pkt, &vals).expect("pack");
        last = unpack(&pkt, &packed).expect("unpack");
    }
    let elapsed = start.elapsed();
    assert_eq!(last.get("type"), Some(&Some(Value::U8(64))));
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
    let pkt = packet(vec![
        u8("profile"),
        when(eq("profile", Value::U8(0)), vec![u8("shape")]),
    ]);
    let mut miss = Values::new();
    insert(&mut miss, "profile", Some(Value::U8(1)));
    insert(&mut miss, "shape", Some(Value::U8(9)));
    assert_eq!(pack(&pkt, &miss).unwrap().len(), 1);

    let mut hit = Values::new();
    insert(&mut hit, "profile", Some(Value::U8(0)));
    insert(&mut hit, "shape", Some(Value::U8(9)));
    assert_eq!(pack(&pkt, &hit).unwrap().len(), 2);
}

#[test]
fn repeat_groups_and_leftover() {
    let pkt = packet(vec![
        u8("type"),
        u16("sid"),
        repeat(vec![i32("lat"), i32("lon")]),
    ]);
    let mut vals = Values::new();
    insert(&mut vals, "type", Some(Value::U8(1)));
    insert(&mut vals, "sid", Some(Value::U16(2)));
    let mut g1 = Values::new();
    insert(&mut g1, "lat", Some(Value::I32(10)));
    insert(&mut g1, "lon", Some(Value::I32(20)));
    insert(&mut vals, "__repeat__", Some(Value::Groups(vec![g1])));
    let packed = pack(&pkt, &vals).unwrap();
    let got = unpack(&pkt, &packed).unwrap();
    match got.get("__repeat__") {
        Some(Some(Value::Groups(g))) => assert_eq!(g.len(), 1),
        other => panic!("expected one group, got {:?}", other),
    }

    let mut leftover = packed;
    leftover.push(0xff);
    let err = unpack(&pkt, &leftover).expect_err("leftover");
    match err {
        UnpackError::Short(ShortPacket { field, .. }) => {
            assert!(field == "lat" || field == "lon");
        }
        other => panic!("expected short on leftover, got {:?}", other),
    }
}

#[test]
fn trailing_bytes_error() {
    let pkt = packet(vec![u8("type"), u16("sid")]);
    let err = unpack(&pkt, &[1, 2, 3, 4]).expect_err("trailing");
    assert!(matches!(err, UnpackError::Trailing { left: 1 }));
}

#[test]
fn split_flag_byte_and_be() {
    let motion = flag_byte("motion");
    let pkt = packet(vec![
        u8("type"),
        motion.byte(),
        when(eq("type", Value::U8(0)), vec![u8("shape")]),
        motion.bit(u16("heading")),
        motion.bit(u8("speed")),
    ]);
    let mut vals = Values::new();
    insert(&mut vals, "type", Some(Value::U8(1)));
    insert(&mut vals, "heading", Some(Value::U16(90)));
    let packed = pack(&pkt, &vals).unwrap();
    assert_eq!(packed[1], 0x01);
    assert_eq!(packed.len(), 4);

    let be_pkt = packet(vec![packbin::be(u16("sid"))]);
    let mut be_vals = Values::new();
    insert(&mut be_vals, "sid", Some(Value::U16(0x0102)));
    assert_eq!(pack(&be_pkt, &be_vals).unwrap(), vec![0x01, 0x02]);

    let mut float_vals = Values::new();
    insert(&mut float_vals, "x", Some(Value::F32(1.0)));
    insert(&mut float_vals, "y", Some(Value::F64(2.0)));
    insert(&mut float_vals, "z", Some(Value::Bytes(vec![9, 8])));
    let float_pkt = packet(vec![f32("x"), f64("y"), bytes("z", 2)]);
    assert_eq!(pack(&float_pkt, &float_vals).unwrap().len(), 14);
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
    let pkt = packet(vec![flags("f", vec![group("mark", vec![])])]);
    let mut set = Values::new();
    insert(&mut set, "mark", Some(Value::U8(1)));
    assert_eq!(pack(&pkt, &set).unwrap(), vec![0x01]);
    let clear = Values::new();
    assert_eq!(pack(&pkt, &clear).unwrap(), vec![0x00]);
}

#[test]
fn flags_five_u8_then_u16() {
    let pkt = packet(vec![flags(
        "f",
        vec![
            u8("a"),
            u8("b"),
            u8("c"),
            u8("d"),
            u8("e"),
            u16("b5"),
        ],
    )]);
    let mut a = Values::new();
    insert(&mut a, "a", Some(Value::U8(1)));
    assert_eq!(pack(&pkt, &a).unwrap().len(), 2);

    let mut b5 = Values::new();
    insert(&mut b5, "b5", Some(Value::U16(1)));
    let wide = pack(&pkt, &b5).unwrap();
    assert_eq!(wide[0], 0x20);
    let clear = pack(&pkt, &Values::new()).unwrap();
    assert_eq!(wide.len() - clear.len(), 2);
}

#[test]
fn session_group_pack_unpack() {
    let pkt = packet(vec![flags(
        "f",
        vec![group("session", vec![u16("login"), u32("ts")])],
    )]);
    let mut vals = Values::new();
    insert(&mut vals, "login", Some(Value::U16(7)));
    insert(&mut vals, "ts", Some(Value::U32(1000)));
    let raw = pack(&pkt, &vals).unwrap();
    assert_eq!(to_hex(&raw[1..]), "0700e8030000");
    assert_eq!(raw.len() - 1, 6);

    let clear = pack(&pkt, &Values::new()).unwrap();
    assert_eq!(clear, vec![0x00]);
    let got = unpack(&pkt, &clear).unwrap();
    assert!(!got.contains_key("login"));
    assert!(!got.contains_key("ts"));
}

#[test]
fn group_one_u8_zero() {
    let pkt = packet(vec![flags("f", vec![group("g", vec![u8("b")])])]);
    let mut vals = Values::new();
    insert(&mut vals, "b", Some(Value::U8(0)));
    assert_eq!(pack(&pkt, &vals).unwrap(), vec![0x01, 0x00]);
}

#[test]
fn session_group_short_read() {
    let pkt = packet(vec![flags(
        "f",
        vec![group("session", vec![u16("login"), u32("ts")])],
    )]);
    let err = unpack(&pkt, &[0x01, 0x07]).expect_err("short");
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
fn sized_payload() {
    let pkt = packet(vec![u16("n"), sized("payload", "n")]);
    let mut vals = Values::new();
    insert(&mut vals, "n", Some(Value::U16(3)));
    insert(
        &mut vals,
        "payload",
        Some(Value::Bytes(vec![0x75, 0x61, 0x76])),
    );
    let raw = pack(&pkt, &vals).unwrap();
    assert_eq!(to_hex(&raw), "0300756176");

    let mut empty = Values::new();
    insert(&mut empty, "n", Some(Value::U16(0)));
    insert(&mut empty, "payload", Some(Value::Bytes(vec![])));
    let empty_raw = pack(&pkt, &empty).unwrap();
    assert_eq!(to_hex(&empty_raw), "0000");
    let empty_got = unpack(&pkt, &empty_raw).unwrap();
    match empty_got.get("payload") {
        Some(Some(Value::Bytes(b))) => assert_eq!(b.len(), 0),
        other => panic!("expected empty payload, got {:?}", other),
    }

    let err = unpack(&pkt, &parse_hex("030075")).expect_err("short");
    match err {
        UnpackError::Short(ShortPacket {
            field,
            needed,
            left,
        }) => {
            assert_eq!(field, "payload");
            assert_eq!(needed, 3);
            assert_eq!(left, 1);
        }
        other => panic!("expected ShortPacket, got {:?}", other),
    }
}

#[test]
fn u2_pack_unpack() {
    let pkt = packet(vec![u2(&["a", "b", "c", "d"])]);
    let mut vals = Values::new();
    insert(&mut vals, "a", Some(Value::U8(0)));
    insert(&mut vals, "b", Some(Value::U8(1)));
    insert(&mut vals, "c", Some(Value::U8(2)));
    insert(&mut vals, "d", Some(Value::U8(3)));
    let raw = pack(&pkt, &vals).unwrap();
    assert_eq!(to_hex(&raw), "e4");
    let got = unpack(&pkt, &raw).unwrap();
    assert_eq!(got.get("a"), Some(&Some(Value::U8(0))));
    assert_eq!(got.get("b"), Some(&Some(Value::U8(1))));
    assert_eq!(got.get("c"), Some(&Some(Value::U8(2))));
    assert_eq!(got.get("d"), Some(&Some(Value::U8(3))));

    let one = packet(vec![u2(&["a"])]);
    let mut one_vals = Values::new();
    insert(&mut one_vals, "a", Some(Value::U8(1)));
    assert_eq!(to_hex(&pack(&one, &one_vals).unwrap()), "01");
}

#[test]
fn bits_pack_unpack() {
    let pkt = packet(vec![u8("n"), bits("segs", "n")]);
    let mut eight = Values::new();
    insert(&mut eight, "n", Some(Value::U8(8)));
    insert(
        &mut eight,
        "segs",
        Some(Value::List(vec![Value::U8(1); 8])),
    );
    let eight_raw = pack(&pkt, &eight).unwrap();
    assert_eq!(to_hex(&eight_raw[1..]), "ff");
    assert_eq!(eight_raw.len() - 1, 1);

    let mut nine = Values::new();
    insert(&mut nine, "n", Some(Value::U8(9)));
    insert(
        &mut nine,
        "segs",
        Some(Value::List(vec![Value::U8(1); 9])),
    );
    let nine_raw = pack(&pkt, &nine).unwrap();
    assert_eq!(nine_raw.len() - 1, 2);
    assert_eq!(nine_raw[1], 0xff);
    assert_eq!(nine_raw[2] & 0xfe, 0);

    let err = unpack(&pkt, &[9, 0x01]).expect_err("short");
    match err {
        UnpackError::Short(ShortPacket {
            field,
            needed,
            left,
        }) => {
            assert_eq!(field, "segs");
            assert_eq!(needed, 2);
            assert_eq!(left, 1);
        }
        other => panic!("expected ShortPacket, got {:?}", other),
    }
}

#[test]
fn utf8_string() {
    let pkt = packet(vec![utf8("name")]);
    let mut vals = Values::new();
    insert(&mut vals, "name", Some(Value::Str("zxsanny".into())));
    let raw = pack(&pkt, &vals).unwrap();
    assert_eq!(to_hex(&raw), "07007a7873616e6e79");
    assert_eq!(raw.len(), 9);
    let got = unpack(&pkt, &raw).unwrap();
    assert_eq!(got["name"], Some(Value::Str("zxsanny".into())));

    let mut empty_vals = Values::new();
    insert(&mut empty_vals, "name", Some(Value::Str(String::new())));
    let empty = pack(&pkt, &empty_vals).unwrap();
    assert_eq!(to_hex(&empty), "0000");
    let empty_got = unpack(&pkt, &empty).unwrap();
    assert_eq!(empty_got["name"], Some(Value::Str(String::new())));

    let mut long_vals = Values::new();
    insert(
        &mut long_vals,
        "name",
        Some(Value::Str("a".repeat(65536))),
    );
    assert!(pack(&pkt, &long_vals).is_err());

    let err = unpack(&pkt, &[0x07, 0x00, 0x7a, 0x78]).expect_err("short");
    match err {
        UnpackError::Short(ShortPacket {
            field,
            needed,
            left,
        }) => {
            assert_eq!(field, "name");
            assert_eq!(needed, 7);
            assert_eq!(left, 2);
        }
        other => panic!("expected ShortPacket, got {:?}", other),
    }
}

#[test]
fn counted_list() {
    let two = packet(vec![list("xs", u16("n"))]);
    let mut vals = Values::new();
    insert(
        &mut vals,
        "xs",
        Some(Value::List(vec![Value::U16(1), Value::U16(2)])),
    );
    let raw = pack(&two, &vals).unwrap();
    assert_eq!(to_hex(&raw), "020001000200");
    let got = unpack(&two, &raw).unwrap();
    assert_eq!(
        got["xs"],
        Some(Value::List(vec![Value::U16(1), Value::U16(2)]))
    );

    let be_one = packet(vec![list("xs", be(u16("n")))]);
    let mut be_vals = Values::new();
    insert(&mut be_vals, "xs", Some(Value::List(vec![Value::U16(1)])));
    assert_eq!(to_hex(&pack(&be_one, &be_vals).unwrap()), "01000001");

    let followed = packet(vec![list("xs", u8("n")), u8("y")]);
    let mut both_vals = Values::new();
    insert(&mut both_vals, "xs", Some(Value::List(vec![Value::U8(1)])));
    insert(&mut both_vals, "y", Some(Value::U8(2)));
    let both = pack(&followed, &both_vals).unwrap();
    assert_eq!(to_hex(&both), "01000102");
    let back = unpack(&followed, &both).unwrap();
    assert_eq!(back["xs"], Some(Value::List(vec![Value::U8(1)])));
    assert_eq!(back["y"], Some(Value::U8(2)));

    let mut empty_vals = Values::new();
    insert(&mut empty_vals, "xs", Some(Value::List(vec![])));
    assert_eq!(to_hex(&pack(&two, &empty_vals).unwrap()), "0000");

    let mut long_vals = Values::new();
    insert(
        &mut long_vals,
        "xs",
        Some(Value::List(vec![Value::U16(1); 65536])),
    );
    assert!(pack(&two, &long_vals).is_err());
}

#[test]
fn dictionary_field() {
    const USER_HEX: &str = concat!(
        "07007a7873616e6e7902000400757365720a0064697370617463686572",
        "030007006368616e6e656c010004007265616403006d61700400040072656164",
        "07006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465"
    );

    let pkt = packet(vec![
        utf8("username"),
        list("roles", utf8("role")),
        dict("access", list("actions", utf8("action"))),
    ]);

    let mut access = BTreeMap::new();
    access.insert(
        "channel".into(),
        Value::List(vec![Value::Str("read".into())]),
    );
    access.insert(
        "map".into(),
        Value::List(vec![
            Value::Str("read".into()),
            Value::Str("gps_fix".into()),
            Value::Str("set".into()),
            Value::Str("edit".into()),
        ]),
    );
    access.insert(
        "store".into(),
        Value::List(vec![Value::Str("read".into()), Value::Str("write".into())]),
    );

    let mut vals = Values::new();
    insert(&mut vals, "username", Some(Value::Str("zxsanny".into())));
    insert(
        &mut vals,
        "roles",
        Some(Value::List(vec![
            Value::Str("user".into()),
            Value::Str("dispatcher".into()),
        ])),
    );
    insert(&mut vals, "access", Some(Value::Map(access.clone())));

    let raw = pack(&pkt, &vals).unwrap();
    assert_eq!(to_hex(&raw), USER_HEX);

    let got = unpack(&pkt, &raw).unwrap();
    assert_eq!(got["username"], Some(Value::Str("zxsanny".into())));
    assert_eq!(
        got["roles"],
        Some(Value::List(vec![
            Value::Str("user".into()),
            Value::Str("dispatcher".into()),
        ]))
    );
    match &got["access"] {
        Some(Value::Map(m)) => {
            assert_eq!(m.len(), 3);
            assert_eq!(
                m.get("channel"),
                Some(&Value::List(vec![Value::Str("read".into())]))
            );
            assert_eq!(
                m.get("map"),
                Some(&Value::List(vec![
                    Value::Str("read".into()),
                    Value::Str("gps_fix".into()),
                    Value::Str("set".into()),
                    Value::Str("edit".into()),
                ]))
            );
            assert_eq!(
                m.get("store"),
                Some(&Value::List(vec![
                    Value::Str("read".into()),
                    Value::Str("write".into()),
                ]))
            );
        }
        other => panic!("expected access map, got {:?}", other),
    }

    let mut shuffled = BTreeMap::new();
    shuffled.insert(
        "store".into(),
        Value::List(vec![Value::Str("read".into()), Value::Str("write".into())]),
    );
    shuffled.insert(
        "channel".into(),
        Value::List(vec![Value::Str("read".into())]),
    );
    shuffled.insert(
        "map".into(),
        Value::List(vec![
            Value::Str("read".into()),
            Value::Str("gps_fix".into()),
            Value::Str("set".into()),
            Value::Str("edit".into()),
        ]),
    );
    let mut shuffled_vals = Values::new();
    insert(
        &mut shuffled_vals,
        "username",
        Some(Value::Str("zxsanny".into())),
    );
    insert(
        &mut shuffled_vals,
        "roles",
        Some(Value::List(vec![
            Value::Str("user".into()),
            Value::Str("dispatcher".into()),
        ])),
    );
    insert(&mut shuffled_vals, "access", Some(Value::Map(shuffled)));
    assert_eq!(to_hex(&pack(&pkt, &shuffled_vals).unwrap()), USER_HEX);

    let empty_pkt = packet(vec![
        utf8("username"),
        list("roles", utf8("role")),
        dict("access", list("actions", utf8("action"))),
    ]);
    let mut empty_vals = Values::new();
    insert(&mut empty_vals, "username", Some(Value::Str(String::new())));
    insert(&mut empty_vals, "roles", Some(Value::List(vec![])));
    insert(&mut empty_vals, "access", Some(Value::Map(BTreeMap::new())));
    assert_eq!(to_hex(&pack(&empty_pkt, &empty_vals).unwrap()), "000000000000");

    let dup_pkt = packet(vec![dict("access", utf8("v"))]);
    let dup_err = unpack(&dup_pkt, &parse_hex("0200010061010078010061010079")).unwrap_err();
    match dup_err {
        UnpackError::Short(ShortPacket {
            field,
            needed,
            left,
        }) => {
            assert_eq!(field, "access");
            assert_eq!(needed, 0);
            assert_eq!(left, 0);
        }
        other => panic!("expected ShortPacket, got {:?}", other),
    }

    let again = pack(&pkt, &vals).unwrap();
    assert_eq!(raw, again);

    let t1 = std::thread::spawn(|| {
        let pkt = packet(vec![
            utf8("username"),
            list("roles", utf8("role")),
            dict("access", list("actions", utf8("action"))),
        ]);
        let mut access = BTreeMap::new();
        access.insert(
            "channel".into(),
            Value::List(vec![Value::Str("read".into())]),
        );
        access.insert(
            "map".into(),
            Value::List(vec![
                Value::Str("read".into()),
                Value::Str("gps_fix".into()),
                Value::Str("set".into()),
                Value::Str("edit".into()),
            ]),
        );
        access.insert(
            "store".into(),
            Value::List(vec![Value::Str("read".into()), Value::Str("write".into())]),
        );
        let mut vals = Values::new();
        insert(&mut vals, "username", Some(Value::Str("zxsanny".into())));
        insert(
            &mut vals,
            "roles",
            Some(Value::List(vec![
                Value::Str("user".into()),
                Value::Str("dispatcher".into()),
            ])),
        );
        insert(&mut vals, "access", Some(Value::Map(access)));
        pack(&pkt, &vals).unwrap()
    });
    let t2 = std::thread::spawn(|| {
        let pkt = packet(vec![
            utf8("username"),
            list("roles", utf8("role")),
            dict("access", list("actions", utf8("action"))),
        ]);
        let mut access = BTreeMap::new();
        access.insert(
            "channel".into(),
            Value::List(vec![Value::Str("read".into())]),
        );
        access.insert(
            "map".into(),
            Value::List(vec![
                Value::Str("read".into()),
                Value::Str("gps_fix".into()),
                Value::Str("set".into()),
                Value::Str("edit".into()),
            ]),
        );
        access.insert(
            "store".into(),
            Value::List(vec![Value::Str("read".into()), Value::Str("write".into())]),
        );
        let mut vals = Values::new();
        insert(&mut vals, "username", Some(Value::Str("zxsanny".into())));
        insert(
            &mut vals,
            "roles",
            Some(Value::List(vec![
                Value::Str("user".into()),
                Value::Str("dispatcher".into()),
            ])),
        );
        insert(&mut vals, "access", Some(Value::Map(access)));
        pack(&pkt, &vals).unwrap()
    });
    assert_eq!(t1.join().unwrap(), t2.join().unwrap());

    let mut long_map = BTreeMap::new();
    for i in 0..65536u32 {
        long_map.insert(format!("{:05}", i), Value::Str("x".into()));
    }
    let long_pkt = packet(vec![dict("access", utf8("v"))]);
    let mut long_vals = Values::new();
    insert(&mut long_vals, "access", Some(Value::Map(long_map)));
    match pack(&long_pkt, &long_vals) {
        Err(PackError::Type(_)) => {}
        Ok(_) => panic!("expected PackError for 65536 pairs"),
        Err(other) => panic!("expected PackError::Type, got {:?}", other),
    }
}
