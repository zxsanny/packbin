//! The map form: `MapScheme` with `packbin::pack` and `packbin::unpack`, values keyed by field name.
//!
//! - A field is named, not numbered (`u8("x")`); the anchors of `flags` and `group` carry the next
//!   order id: both `flags` take 0 (x is order 0), the bool takes 1.
//! - A bool is an empty `group` (README §Bool, Rust): set by `Value::U8(1)`, unpacked as `1`.
//! - A `flags` takes a name (`f` outside, `g` inside); unpack returns each flag byte it read under
//!   that name. Pack does not read those names, so they are left out of the comparison and printed
//!   after `differs:`.
use crate::{caught, compared, hex, one_line, stopped, values_of, Cells};
use packbin::{flags, group, insert, pack, u8, unpack, MapScheme, Value, Values};

/// The names of the two flag bytes.
const FLAG_BYTES: [&str; 2] = ["f", "g"];

fn build() -> MapScheme {
    MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![flags(0, "g", vec![u8("x")]), group(1, "b", vec![])],
        )],
    )
}

/// Keys in sorted order, so two rows that hold the same values print the same text.
fn shown(values: &Values) -> String {
    let mut names: Vec<_> = values.keys().collect();
    names.sort();
    let members: Vec<String> = names
        .into_iter()
        .map(|name| {
            let value = values[name]
                .as_ref()
                .map_or("null".to_string(), |v| format!("{v:?}"));
            format!("{:?}:{value}", name.as_ref())
        })
        .collect();
    format!("{{{}}}", members.join(","))
}

/// The values two rows are compared by: no value, a flag byte, and `b = 0` (a clear bit, as an
/// absent `b`) are left out.
fn present(values: &Values) -> String {
    let mut kept = Values::new();
    for (name, value) in values {
        let key: &str = name.as_ref();
        let clear_bool = key == "b" && *value == Some(Value::U8(0));
        if value.is_some() && !FLAG_BYTES.contains(&key) && !clear_bool {
            kept.insert(name.clone(), value.clone());
        }
    }
    shown(&kept)
}

pub fn probe(shape: &str) -> Cells {
    let scheme = match caught(build) {
        Ok(scheme) => scheme,
        Err(message) => return stopped(&[format!("refused: panic: {message}")]),
    };
    let (x, b) = values_of(shape);
    let mut values = Values::new();
    if let Some(x) = x {
        insert(&mut values, "x", Some(Value::U8(x)));
    }
    if let Some(b) = b {
        insert(&mut values, "b", Some(Value::U8(u8::from(b))));
    }
    let packed = match caught(|| pack(&scheme, &values)) {
        Ok(Ok(bytes)) => bytes,
        Ok(Err(error)) => {
            return stopped(&[
                "built".into(),
                format!("refused: {}", one_line(&format!("{error:?}"))),
            ])
        }
        Err(message) => return stopped(&["built".into(), format!("refused: panic: {message}")]),
    };
    let unpacked = match caught(|| unpack(&scheme, &packed)) {
        Ok(Ok(got)) => compared(shape, || {
            if present(&got) == present(&values) {
                "same".to_string()
            } else {
                format!("differs: {}", shown(&got))
            }
        }),
        Ok(Err(error)) => format!("refused: {}", one_line(&format!("{error:?}"))),
        Err(message) => format!("threw: {message}"),
    };
    ["built".into(), hex(&packed), unpacked]
}
