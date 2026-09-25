use crate::walk::{pack, unpack};
use crate::{
    be, bits, dict, insert, list, sized, to_hex, u16, u2, u8, utf8, MapScheme, PackError,
    ShortPacket, UnpackError, Value, Values,
};
use std::collections::BTreeMap;

fn parse_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

#[test]
fn sized_payload() {
    let scheme = MapScheme::new(1, vec![u16("n"), sized("payload", "n")]);
    let mut vals = Values::new();
    insert(&mut vals, "n", Some(Value::U16(3)));
    insert(
        &mut vals,
        "payload",
        Some(Value::Bytes(vec![0x75, 0x61, 0x76])),
    );
    let raw = pack(&scheme, &vals).unwrap();
    assert_eq!(to_hex(&raw), "010300756176");

    let mut empty = Values::new();
    insert(&mut empty, "n", Some(Value::U16(0)));
    insert(&mut empty, "payload", Some(Value::Bytes(vec![])));
    let empty_raw = pack(&scheme, &empty).unwrap();
    assert_eq!(to_hex(&empty_raw), "010000");
    let empty_got = unpack(&scheme, &empty_raw).unwrap();
    match empty_got.get("payload") {
        Some(Some(Value::Bytes(b))) => assert_eq!(b.len(), 0),
        other => panic!("expected empty payload, got {:?}", other),
    }

    let err = unpack(&scheme, &parse_hex("01030075")).expect_err("short");
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
    let scheme = MapScheme::new(1, vec![u2(&["a", "b", "c", "d"])]);
    let mut vals = Values::new();
    insert(&mut vals, "a", Some(Value::U8(0)));
    insert(&mut vals, "b", Some(Value::U8(1)));
    insert(&mut vals, "c", Some(Value::U8(2)));
    insert(&mut vals, "d", Some(Value::U8(3)));
    let raw = pack(&scheme, &vals).unwrap();
    assert_eq!(to_hex(&raw), "01e4");
    let got = unpack(&scheme, &raw).unwrap();
    assert_eq!(got.get("a"), Some(&Some(Value::U8(0))));
    assert_eq!(got.get("b"), Some(&Some(Value::U8(1))));
    assert_eq!(got.get("c"), Some(&Some(Value::U8(2))));
    assert_eq!(got.get("d"), Some(&Some(Value::U8(3))));

    let one = MapScheme::new(1, vec![u2(&["a"])]);
    let mut one_vals = Values::new();
    insert(&mut one_vals, "a", Some(Value::U8(1)));
    assert_eq!(to_hex(&pack(&one, &one_vals).unwrap()), "0101");
}

#[test]
fn bits_pack_unpack() {
    let scheme = MapScheme::new(1, vec![u8("n"), bits("segs", "n")]);
    let mut eight = Values::new();
    insert(&mut eight, "n", Some(Value::U8(8)));
    insert(&mut eight, "segs", Some(Value::List(vec![Value::U8(1); 8])));
    let eight_raw = pack(&scheme, &eight).unwrap();
    assert_eq!(to_hex(&eight_raw[2..]), "ff");
    assert_eq!(eight_raw.len() - 2, 1);

    let mut nine = Values::new();
    insert(&mut nine, "n", Some(Value::U8(9)));
    insert(&mut nine, "segs", Some(Value::List(vec![Value::U8(1); 9])));
    let nine_raw = pack(&scheme, &nine).unwrap();
    assert_eq!(nine_raw.len() - 2, 2);
    assert_eq!(nine_raw[2], 0xff);
    assert_eq!(nine_raw[3] & 0xfe, 0);

    let err = unpack(&scheme, &[1, 9, 0x01]).expect_err("short");
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
    let scheme = MapScheme::new(1, vec![utf8("name")]);
    let mut vals = Values::new();
    insert(&mut vals, "name", Some(Value::Str("zxsanny".into())));
    let raw = pack(&scheme, &vals).unwrap();
    assert_eq!(to_hex(&raw), "0107007a7873616e6e79");
    assert_eq!(raw.len(), 10);
    let got = unpack(&scheme, &raw).unwrap();
    assert_eq!(got["name"], Some(Value::Str("zxsanny".into())));

    let mut empty_vals = Values::new();
    insert(&mut empty_vals, "name", Some(Value::Str(String::new())));
    let empty = pack(&scheme, &empty_vals).unwrap();
    assert_eq!(to_hex(&empty), "010000");
    let empty_got = unpack(&scheme, &empty).unwrap();
    assert_eq!(empty_got["name"], Some(Value::Str(String::new())));

    let mut long_vals = Values::new();
    insert(&mut long_vals, "name", Some(Value::Str("a".repeat(65536))));
    assert!(pack(&scheme, &long_vals).is_err());

    let err = unpack(&scheme, &[0x01, 0x07, 0x00, 0x7a, 0x78]).expect_err("short");
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
    let two = MapScheme::new(1, vec![list("xs", u16("n"))]);
    let mut vals = Values::new();
    insert(
        &mut vals,
        "xs",
        Some(Value::List(vec![Value::U16(1), Value::U16(2)])),
    );
    let raw = pack(&two, &vals).unwrap();
    assert_eq!(to_hex(&raw), "01020001000200");
    let got = unpack(&two, &raw).unwrap();
    assert_eq!(
        got["xs"],
        Some(Value::List(vec![Value::U16(1), Value::U16(2)]))
    );

    let be_one = MapScheme::new(1, vec![list("xs", be(u16("n")))]);
    let mut be_vals = Values::new();
    insert(&mut be_vals, "xs", Some(Value::List(vec![Value::U16(1)])));
    assert_eq!(to_hex(&pack(&be_one, &be_vals).unwrap()), "0101000001");

    let followed = MapScheme::new(1, vec![list("xs", u8("n")), u8("y")]);
    let mut both_vals = Values::new();
    insert(&mut both_vals, "xs", Some(Value::List(vec![Value::U8(1)])));
    insert(&mut both_vals, "y", Some(Value::U8(2)));
    let both = pack(&followed, &both_vals).unwrap();
    assert_eq!(to_hex(&both), "0101000102");
    let back = unpack(&followed, &both).unwrap();
    assert_eq!(back["xs"], Some(Value::List(vec![Value::U8(1)])));
    assert_eq!(back["y"], Some(Value::U8(2)));

    let mut empty_vals = Values::new();
    insert(&mut empty_vals, "xs", Some(Value::List(vec![])));
    assert_eq!(to_hex(&pack(&two, &empty_vals).unwrap()), "010000");

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
        "01",
        "07007a7873616e6e7902000400757365720a0064697370617463686572",
        "030007006368616e6e656c010004007265616403006d61700400040072656164",
        "07006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465"
    );

    let scheme = MapScheme::new(
        1,
        vec![
            utf8("username"),
            list("roles", utf8("role")),
            dict("access", list("actions", utf8("action"))),
        ],
    );

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

    let raw = pack(&scheme, &vals).unwrap();
    assert_eq!(to_hex(&raw), USER_HEX);

    let got = unpack(&scheme, &raw).unwrap();
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
    assert_eq!(to_hex(&pack(&scheme, &shuffled_vals).unwrap()), USER_HEX);

    let empty_scheme = MapScheme::new(
        1,
        vec![
            utf8("username"),
            list("roles", utf8("role")),
            dict("access", list("actions", utf8("action"))),
        ],
    );
    let mut empty_vals = Values::new();
    insert(&mut empty_vals, "username", Some(Value::Str(String::new())));
    insert(&mut empty_vals, "roles", Some(Value::List(vec![])));
    insert(&mut empty_vals, "access", Some(Value::Map(BTreeMap::new())));
    assert_eq!(
        to_hex(&pack(&empty_scheme, &empty_vals).unwrap()),
        "01000000000000"
    );

    let dup_scheme = MapScheme::new(1, vec![dict("access", utf8("v"))]);
    let dup_err = unpack(&dup_scheme, &parse_hex("010200010061010078010061010079")).unwrap_err();
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

    let again = pack(&scheme, &vals).unwrap();
    assert_eq!(raw, again);

    let t1 = std::thread::spawn(|| {
        let scheme = MapScheme::new(
            1,
            vec![
                utf8("username"),
                list("roles", utf8("role")),
                dict("access", list("actions", utf8("action"))),
            ],
        );
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
        pack(&scheme, &vals).unwrap()
    });
    let t2 = std::thread::spawn(|| {
        let scheme = MapScheme::new(
            1,
            vec![
                utf8("username"),
                list("roles", utf8("role")),
                dict("access", list("actions", utf8("action"))),
            ],
        );
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
        pack(&scheme, &vals).unwrap()
    });
    assert_eq!(t1.join().unwrap(), t2.join().unwrap());

    let mut long_map = BTreeMap::new();
    for i in 0..65536u32 {
        long_map.insert(format!("{:05}", i), Value::Str("x".into()));
    }
    let long_scheme = MapScheme::new(1, vec![dict("access", utf8("v"))]);
    let mut long_vals = Values::new();
    insert(&mut long_vals, "access", Some(Value::Map(long_map)));
    match pack(&long_scheme, &long_vals) {
        Err(PackError::Type(_)) => {}
        Ok(_) => panic!("expected PackError for 65536 pairs"),
        Err(other) => panic!("expected PackError::Type, got {:?}", other),
    }
}
