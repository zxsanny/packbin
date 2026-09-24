use packbin::{dict, insert, list, pack_map, to_hex, unpack_map, utf8, MapScheme, Value, Values};
use std::collections::BTreeMap;
use std::process::ExitCode;

fn user_scheme() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            utf8("username"),
            list("roles", utf8("role")),
            dict("access", list("actions", utf8("action"))),
        ],
    )
}

fn user_values() -> Values {
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
    vals
}

fn nested_scheme() -> MapScheme {
    MapScheme::new(
        1,
        vec![dict(
            "access",
            list("rows", dict("fields", utf8("value"))),
        )],
    )
}

fn nested_values() -> Values {
    let mut map_row = BTreeMap::new();
    map_row.insert("op".into(), Value::Str("gps_fix".into()));
    let mut read_row = BTreeMap::new();
    read_row.insert("op".into(), Value::Str("read".into()));
    let mut write_row = BTreeMap::new();
    write_row.insert("op".into(), Value::Str("write".into()));

    let mut access = BTreeMap::new();
    access.insert("map".into(), Value::List(vec![Value::Map(map_row)]));
    access.insert(
        "store".into(),
        Value::List(vec![Value::Map(read_row), Value::Map(write_row)]),
    );

    let mut vals = Values::new();
    insert(&mut vals, "access", Some(Value::Map(access)));
    vals
}

fn fields_match(got: &Values, expected: &Values) -> bool {
    if got.len() != expected.len() {
        return false;
    }
    expected.iter().all(|(k, ev)| got.get(k) == Some(ev))
}

fn from_hex(s: &str) -> Option<Vec<u8>> {
    if s.len() % 2 != 0 {
        return None;
    }
    let mut out = Vec::with_capacity(s.len() / 2);
    let bytes = s.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        let hi = hex_nibble(bytes[i])?;
        let lo = hex_nibble(bytes[i + 1])?;
        out.push((hi << 4) | lo);
        i += 2;
    }
    Some(out)
}

fn hex_nibble(b: u8) -> Option<u8> {
    match b {
        b'0'..=b'9' => Some(b - b'0'),
        b'a'..=b'f' => Some(b - b'a' + 10),
        b'A'..=b'F' => Some(b - b'A' + 10),
        _ => None,
    }
}

fn run(args: &[String]) -> u8 {
    let Some(cmd) = args.first().map(String::as_str) else {
        return 2;
    };
    match cmd {
        "pack-user" => {
            let bytes = pack_map(&user_scheme(), &user_values()).expect("pack");
            println!("{}", to_hex(&bytes));
            0
        }
        "pack-nested" => {
            let bytes = pack_map(&nested_scheme(), &nested_values()).expect("pack");
            println!("{}", to_hex(&bytes));
            0
        }
        "unpack-user" => {
            let Some(hex) = args.get(1) else {
                return 1;
            };
            let Some(raw) = from_hex(hex) else {
                return 1;
            };
            match unpack_map(&user_scheme(), &raw) {
                Ok(got) if fields_match(&got, &user_values()) => 0,
                _ => 1,
            }
        }
        "unpack-nested" => {
            let Some(hex) = args.get(1) else {
                return 1;
            };
            let Some(raw) = from_hex(hex) else {
                return 1;
            };
            match unpack_map(&nested_scheme(), &raw) {
                Ok(got) if fields_match(&got, &nested_values()) => 0,
                _ => 1,
            }
        }
        _ => 2,
    }
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    ExitCode::from(run(&args))
}
