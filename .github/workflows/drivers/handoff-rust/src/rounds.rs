use crate::from_hex;
use packbin::{
    eq, flags, group, insert, pack, repeat, to_hex, u8, unpack, when, MapScheme, Value, Values,
};

type Want = Vec<Vec<(&'static str, Option<Value>)>>;

/// `repeat(flags(bool on, u8 n))`: a bool is an empty group, on for the value 1.
fn roundflags_scheme() -> MapScheme {
    MapScheme::new(
        1,
        vec![repeat(
            0,
            vec![flags(0, "f", vec![group(0, "on", vec![]), u8("n")])],
        )],
    )
}

/// `repeat(u8 k, when(k == 1, u8 v))`.
fn roundwhen_scheme() -> MapScheme {
    MapScheme::new(
        1,
        vec![repeat(
            0,
            vec![u8("k"), when(1, eq("k", Value::U8(1)), vec![u8("v")])],
        )],
    )
}

fn rounds_values(rounds: Vec<Vec<(&str, Value)>>) -> Values {
    let groups = rounds
        .into_iter()
        .map(|round| {
            let mut values = Values::new();
            for (name, value) in round {
                insert(&mut values, name, Some(value));
            }
            values
        })
        .collect();
    let mut values = Values::new();
    insert(&mut values, "__repeat__", Some(Value::Groups(groups)));
    values
}

fn pack_rows(cmd: &str, scheme: &MapScheme, values: &Values) -> u8 {
    match pack(scheme, values) {
        Ok(bytes) => {
            println!("{}", to_hex(&bytes));
            0
        }
        Err(err) => {
            eprintln!("{cmd}: {err:?}");
            1
        }
    }
}

/// Exit 0 when `hex` unpacks to the rounds in `want` (`None` is an absent value) and packing
/// the unpacked row gives the same bytes.
fn unpack_rows(cmd: &str, hex: Option<&String>, scheme: &MapScheme, want: &Want) -> u8 {
    let Some(hex) = hex else {
        eprintln!("{cmd}: missing hex argument");
        return 1;
    };
    let Some(raw) = from_hex(hex) else {
        eprintln!("{cmd}: {hex:?} is not hex");
        return 1;
    };
    let values = match unpack(scheme, &raw) {
        Ok(values) => values,
        Err(err) => {
            eprintln!("{cmd}: {err:?}");
            return 1;
        }
    };
    let Some(Some(Value::Groups(rounds))) = values.get("__repeat__") else {
        eprintln!("{cmd}: no rounds read");
        return 1;
    };
    let got: Want = rounds
        .iter()
        .map(|round| {
            want[0]
                .iter()
                .map(|(name, _)| (*name, round.get(*name).cloned().flatten()))
                .collect()
        })
        .collect();
    if &got != want {
        eprintln!("{cmd}: read {got:?}, expected {want:?}");
        return 1;
    }
    match pack(scheme, &values) {
        Ok(bytes) if bytes == raw => 0,
        Ok(bytes) => {
            eprintln!(
                "{cmd}: repacked {}, expected {}",
                to_hex(&bytes),
                to_hex(&raw)
            );
            1
        }
        Err(err) => {
            eprintln!("{cmd}: repack {err:?}");
            1
        }
    }
}

pub fn pack_roundflags() -> u8 {
    let on = [true, false, true];
    let n = [1u8, 2, 3];
    let rounds = on
        .iter()
        .zip(n)
        .map(|(on, n)| vec![("on", Value::U8(u8::from(*on))), ("n", Value::U8(n))])
        .collect();
    pack_rows(
        "pack-roundflags",
        &roundflags_scheme(),
        &rounds_values(rounds),
    )
}

pub fn unpack_roundflags(hex: Option<&String>) -> u8 {
    let want = vec![
        vec![("on", Some(Value::U8(1))), ("n", Some(Value::U8(1)))],
        vec![("on", None), ("n", Some(Value::U8(2)))],
        vec![("on", Some(Value::U8(1))), ("n", Some(Value::U8(3)))],
    ];
    unpack_rows("unpack-roundflags", hex, &roundflags_scheme(), &want)
}

pub fn pack_roundwhen() -> u8 {
    let rounds = vec![
        vec![("k", Value::U8(1)), ("v", Value::U8(9))],
        vec![("k", Value::U8(2))],
    ];
    pack_rows(
        "pack-roundwhen",
        &roundwhen_scheme(),
        &rounds_values(rounds),
    )
}

pub fn unpack_roundwhen(hex: Option<&String>) -> u8 {
    let want = vec![
        vec![("k", Some(Value::U8(1))), ("v", Some(Value::U8(9)))],
        vec![("k", Some(Value::U8(2))), ("v", None)],
    ];
    unpack_rows("unpack-roundwhen", hex, &roundwhen_scheme(), &want)
}
