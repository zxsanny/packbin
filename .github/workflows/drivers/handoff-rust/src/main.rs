use packbin::{to_hex, BinaryPacker, BoundField, Scheme};
use std::collections::BTreeMap;
use std::process::ExitCode;

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
            BoundField::utf8(
                0,
                |row: &User| row.username.clone(),
                |row, value| row.username = value,
            )
            .into(),
            BoundField::list_utf8(
                |row: &User| row.roles.clone(),
                |row, value| row.roles = value,
            )
            .into(),
            BoundField::dict_list_utf8(
                |row: &User| row.access.clone(),
                |row, value| row.access = value,
            )
            .into(),
        ],
    )
}

fn user_row() -> User {
    let mut access = BTreeMap::new();
    access.insert("channel".into(), vec!["read".into()]);
    access.insert(
        "map".into(),
        vec!["read".into(), "gps_fix".into(), "set".into(), "edit".into()],
    );
    access.insert("store".into(), vec!["read".into(), "write".into()]);
    User {
        username: "zxsanny".into(),
        roles: vec!["user".into(), "dispatcher".into()],
        access,
    }
}

fn nested_scheme() -> Scheme<Nested> {
    Scheme::new(
        1,
        [BoundField::dict_list_dict_utf8(
            |row: &Nested| row.access.clone(),
            |row, value| row.access = value,
        )
        .into()],
    )
}

fn nested_row() -> Nested {
    let mut map_row = BTreeMap::new();
    map_row.insert("op".into(), "gps_fix".into());
    let mut read_row = BTreeMap::new();
    read_row.insert("op".into(), "read".into());
    let mut write_row = BTreeMap::new();
    write_row.insert("op".into(), "write".into());
    let mut access = BTreeMap::new();
    access.insert("map".into(), vec![map_row]);
    access.insert("store".into(), vec![read_row, write_row]);
    Nested { access }
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
            let bytes = BinaryPacker::pack(&user_scheme(), &user_row()).expect("pack");
            println!("{}", to_hex(&bytes));
            0
        }
        "pack-nested" => {
            let bytes = BinaryPacker::pack(&nested_scheme(), &nested_row()).expect("pack");
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
            let scheme = user_scheme();
            let mut got = User::default();
            match BinaryPacker::unpack_with(&raw, &mut [&mut scheme.on(|row| got = row)]) {
                Ok(()) if got == user_row() => 0,
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
            let scheme = nested_scheme();
            let mut got = Nested::default();
            match BinaryPacker::unpack_with(&raw, &mut [&mut scheme.on(|row| got = row)]) {
                Ok(()) if got == nested_row() => 0,
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
