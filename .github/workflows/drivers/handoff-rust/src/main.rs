use packbin::{
    eq, flag_byte, flags, i16, insert, pack, to_hex, u16, u8, unpack, when, BinaryPacker,
    BoundField, MapScheme, PackSession, Scheme, SchemeItem, Value, Values,
};
use std::collections::BTreeMap;
use std::process::ExitCode;

mod rounds;

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

#[derive(Default, Debug, PartialEq)]
struct BoolFlag {
    on: Option<bool>,
}

fn boolflag_scheme() -> Scheme<BoolFlag> {
    Scheme::new(
        1,
        [SchemeItem::flags(
            0,
            [
                BoundField::bool_flag(0, |row: &BoolFlag| row.on, |row, value| row.on = value)
                    .into(),
            ],
        )],
    )
}

/// Unpacks `hex` with the boolflag scheme. Exit 0 when it reads and `on` is what `want_on`
/// asks for: `Some(true)` for a set bit, absent or `false` for a clear one.
fn unpack_boolflag(cmd: &str, hex: Option<&String>, want_on: bool) -> u8 {
    let Some(hex) = hex else {
        eprintln!("{cmd}: missing hex argument");
        return 1;
    };
    let Some(raw) = from_hex(hex) else {
        eprintln!("{cmd}: {hex:?} is not hex");
        return 1;
    };
    let scheme = boolflag_scheme();
    let mut got = BoolFlag::default();
    match BinaryPacker::unpack_with(&raw, &mut [&mut scheme.on(|row| got = row)]) {
        Ok(()) if (got.on == Some(true)) == want_on => 0,
        Ok(()) => {
            let want = if want_on {
                "Some(true)"
            } else {
                "absent or false"
            };
            eprintln!("{cmd}: on = {:?}, expected {want}", got.on);
            1
        }
        Err(err) => {
            eprintln!("{cmd}: {err:?}");
            1
        }
    }
}

fn pack_boolflag(on: bool) -> u8 {
    let row = BoolFlag { on: Some(on) };
    let bytes = BinaryPacker::pack(&boolflag_scheme(), &row).expect("pack");
    println!("{}", to_hex(&bytes));
    0
}

/// `u8 k`, split flag byte `m`, `when(k == 1)` holding `m.bit(u8 v)`: the bit of `v` is set
/// from the row even when the `when` is not taken.
fn bitwhen_scheme() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            u8("k"),
            m.byte(),
            when(2, eq("k", Value::U8(1)), vec![m.bit(u8("v"))]),
        ],
    )
}

fn pack_bitwhen() -> u8 {
    let mut values = Values::new();
    insert(&mut values, "k", Some(Value::U8(0)));
    insert(&mut values, "v", Some(Value::U8(5)));
    match pack(&bitwhen_scheme(), &values) {
        Ok(bytes) => {
            println!("{}", to_hex(&bytes));
            0
        }
        Err(err) => {
            eprintln!("pack-bitwhen: {err:?}");
            1
        }
    }
}

/// Exit 0 when `hex` unpacks with `k == 0` and no `v`.
fn unpack_bitwhen(hex: Option<&String>) -> u8 {
    let Some(hex) = hex else {
        eprintln!("unpack-bitwhen: missing hex argument");
        return 1;
    };
    let Some(raw) = from_hex(hex) else {
        eprintln!("unpack-bitwhen: {hex:?} is not hex");
        return 1;
    };
    match unpack(&bitwhen_scheme(), &raw) {
        Ok(values) => {
            let k = values.get("k").cloned().flatten();
            let v = values.get("v").cloned().flatten();
            if k == Some(Value::U8(0)) && v.is_none() {
                0
            } else {
                eprintln!("unpack-bitwhen: k = {k:?}, v = {v:?}, expected k = 0 and no v");
                1
            }
        }
        Err(err) => {
            eprintln!("unpack-bitwhen: {err:?}");
            1
        }
    }
}

#[derive(Default, Debug, PartialEq)]
struct Position {
    sid: u16,
    lat: i32,
    lon: i32,
    profile: u8,
    heading: Option<u16>,
    speed: Option<u8>,
    altitude: Option<i16>,
}

fn position_scheme() -> Scheme<Position> {
    Scheme::new(
        0x40,
        [
            BoundField::u16(
                0,
                |row: &Position| row.sid,
                |row, value| row.sid = value,
            )
            .into(),
            BoundField::i32(
                1,
                |row: &Position| row.lat,
                |row, value| row.lat = value,
            )
            .into(),
            BoundField::i32(
                2,
                |row: &Position| row.lon,
                |row, value| row.lon = value,
            )
            .into(),
            BoundField::u8(
                3,
                |row: &Position| row.profile,
                |row, value| row.profile = value,
            )
            .into(),
            flags(4, "motion", vec![u16("heading"), u8("speed"), i16("altitude")]).into(),
        ],
    )
}

fn position_row() -> Position {
    Position {
        sid: 1,
        lat: 500_000_000,
        lon: 300_000_000,
        profile: 1,
        heading: None,
        speed: None,
        altitude: None,
    }
}

fn session_seed() -> [u8; 32] {
    let mut seed = [0u8; 32];
    for (i, b) in seed.iter_mut().enumerate() {
        *b = (i + 1) as u8;
    }
    seed
}

fn session_nonce() -> [u8; 16] {
    let mut nonce = [0u8; 16];
    nonce[0] = 0x01;
    nonce
}

fn session_fields_ok(row: &Position) -> bool {
    row.sid == 1
        && row.lat == 500_000_000
        && row.lon == 300_000_000
        && row.profile == 1
        && row.heading.is_none()
        && row.speed.is_none()
        && row.altitude.is_none()
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
        "pack-boolflag" => pack_boolflag(false),
        "unpack-boolflag" => unpack_boolflag(cmd, args.get(1), false),
        "pack-booltrue" => pack_boolflag(true),
        "pack-bitwhen" => pack_bitwhen(),
        "unpack-bitwhen" => unpack_bitwhen(args.get(1)),
        "unpack-booltrue" => unpack_boolflag(cmd, args.get(1), true),
        "pack-roundflags" => rounds::pack_roundflags(),
        "unpack-roundflags" => rounds::unpack_roundflags(args.get(1)),
        "pack-roundwhen" => rounds::pack_roundwhen(),
        "unpack-roundwhen" => rounds::unpack_roundwhen(args.get(1)),
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
        "pack-session" => {
            let Some(mut opener) = PackSession::load(&session_seed()) else {
                return 1;
            };
            if opener.start_with(&session_nonce()).is_none() {
                return 1;
            }
            let Ok(payload) = opener.pack(&position_scheme(), &position_row()) else {
                return 1;
            };
            println!("{}", to_hex(&payload));
            0
        }
        "unpack-session" => {
            let Some(hex) = args.get(1) else {
                return 1;
            };
            let Some(raw) = from_hex(hex) else {
                return 1;
            };
            let Some(mut waiter) = PackSession::load(&session_seed()) else {
                return 1;
            };
            if !waiter.join(&session_nonce()) {
                return 1;
            }
            let scheme = position_scheme();
            let mut got = Position::default();
            match waiter.unpack(&raw, &mut [&mut scheme.on(|row| got = row)]) {
                Ok(()) if session_fields_ok(&got) => 0,
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
