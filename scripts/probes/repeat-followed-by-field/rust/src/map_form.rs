//! The map form: `MapScheme` with `packbin::pack` and `packbin::unpack`, values keyed by field name.
//!
//! - A field is named, not numbered (`u8("x")`); only the anchors of `repeat`, `when`, `flags` and
//!   `group` carry the next order id.
//! - The rounds of a `repeat` are `Value::Groups` under `__repeat__`, one `Values` a round (round 0
//!   holds `v = 5`, round 1 holds `v = 6`). A scheme has one `__repeat__` key however many repeats
//!   it holds (shape `f`).
//! - `group(anchor, name, fields)` is the only group: its members are keys of the row around it, as
//!   in TypeScript, so shape `d` gives `v` (inside the rounds) and `x` flat.
//! - `flags` takes a name; unpack returns its byte under it.
//! - `MapScheme::new` (and `list` / `dict` themselves) refuse a scheme with a panic.
use crate::{caught, compared, hex, line, one_line};
use packbin::{
    dict, eq, flags, group, insert, list, pack, repeat, u8, unpack, when, MapScheme, Value, Values,
};

fn row(pairs: Vec<(&str, Value)>) -> Values {
    let mut values = Values::new();
    for (name, value) in pairs {
        insert(&mut values, name, Some(value));
    }
    values
}

/// One round per item, each holding `v`.
fn rounds(items: &[u8]) -> Value {
    Value::Groups(
        items
            .iter()
            .map(|item| row(vec![("v", Value::U8(*item))]))
            .collect(),
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
                .map_or("null".to_string(), shown_value);
            format!("{:?}:{value}", name.as_ref())
        })
        .collect();
    format!("{{{}}}", members.join(","))
}

fn shown_value(value: &Value) -> String {
    fn listed(items: impl Iterator<Item = String>) -> String {
        format!("[{}]", items.collect::<Vec<_>>().join(","))
    }
    match value {
        Value::U8(n) => n.to_string(),
        Value::U16(n) => n.to_string(),
        Value::U32(n) => n.to_string(),
        Value::U64(n) => n.to_string(),
        Value::I8(n) => n.to_string(),
        Value::I16(n) => n.to_string(),
        Value::I32(n) => n.to_string(),
        Value::I64(n) => n.to_string(),
        Value::F32(n) => n.to_string(),
        Value::F64(n) => n.to_string(),
        Value::Bytes(bytes) => listed(bytes.iter().map(|b| b.to_string())),
        Value::Str(text) => format!("{text:?}"),
        Value::List(items) => listed(items.iter().map(shown_value)),
        Value::Map(entries) => format!(
            "{{{}}}",
            entries
                .iter()
                .map(|(key, item)| format!("{key:?}:{}", shown_value(item)))
                .collect::<Vec<_>>()
                .join(",")
        ),
        Value::Groups(groups) => listed(groups.iter().map(shown)),
    }
}

/// `values` is `None` for a shape whose values the map API cannot hold: if its scheme builds,
/// nothing is packed and stderr says why.
fn probe(shape: &str, build: impl FnOnce() -> MapScheme, values: Option<Values>) {
    let scheme = match caught(build) {
        Ok(scheme) => scheme,
        Err(message) => return line(shape, &format!("refused: panic: {message}"), "-", "-"),
    };
    let Some(values) = values else {
        eprintln!(
            "rust {shape}: the scheme built, and nothing is packed: a Value cannot hold a row as a \
             list or dict item"
        );
        return line(shape, "built", "-", "-");
    };
    let packed = match caught(|| pack(&scheme, &values)) {
        Ok(Ok(bytes)) => bytes,
        Ok(Err(error)) => {
            return line(
                shape,
                "built",
                &format!("refused: {}", one_line(&format!("{error:?}"))),
                "-",
            )
        }
        Err(message) => return line(shape, "built", &format!("refused: panic: {message}"), "-"),
    };
    let unpacked = match caught(|| unpack(&scheme, &packed)) {
        Ok(Ok(got)) => compared(shape, || {
            if got == values {
                "same".to_string()
            } else {
                format!("differs: {}", shown(&got))
            }
        }),
        Ok(Err(error)) => format!("refused: {}", one_line(&format!("{error:?}"))),
        Err(message) => format!("threw: {message}"),
    };
    line(shape, "built", &hex(&packed), &unpacked);
}

pub fn run() {
    // control: the repeat is the last thing read.
    probe(
        "control",
        || MapScheme::new(1, vec![u8("x"), repeat(1, vec![u8("v")])]),
        Some(row(vec![
            ("x", Value::U8(9)),
            ("__repeat__", rounds(&[5, 6])),
        ])),
    );

    // a: a field after a repeat, top level.
    probe(
        "a",
        || MapScheme::new(1, vec![repeat(0, vec![u8("v")]), u8("x")]),
        Some(row(vec![
            ("__repeat__", rounds(&[5, 6])),
            ("x", Value::U8(9)),
        ])),
    );

    // b: a repeat inside a list element row. The map form has no row element (an element is one
    // value), so the nearest scheme is a group as the element; a `Value` cannot hold its items.
    probe(
        "b",
        || {
            let element = group(0, "item", vec![u8("mode"), repeat(1, vec![u8("v")])]);
            MapScheme::new(1, vec![list("items", element)])
        },
        None,
    );

    // c: a repeat inside a dict element row, as for b.
    probe(
        "c",
        || {
            let element = group(0, "item", vec![u8("mode"), repeat(1, vec![u8("v")])]);
            MapScheme::new(1, vec![dict("d", element)])
        },
        None,
    );

    // d: a repeat inside a group, then a field. The group is flat: its members are keys of the row.
    probe(
        "d",
        || {
            MapScheme::new(
                1,
                vec![group(0, "m", vec![repeat(0, vec![u8("v")])]), u8("x")],
            )
        },
        Some(row(vec![
            ("__repeat__", rounds(&[5, 6])),
            ("x", Value::U8(9)),
        ])),
    );

    // e-when: a repeat under a when that is taken, then a field.
    probe(
        "e-when",
        || {
            let taken = when(1, eq("k", Value::U8(1)), vec![repeat(1, vec![u8("v")])]);
            MapScheme::new(1, vec![u8("k"), taken, u8("x")])
        },
        Some(row(vec![
            ("k", Value::U8(1)),
            ("__repeat__", rounds(&[5, 6])),
            ("x", Value::U8(9)),
        ])),
    );

    // e-flags: a repeat under flags, then a field. Unpack returns the flags byte under its name, so
    // the row given holds the byte a read-back returns (bit 0 set, `f = 1`) and compares equal to
    // it; pack does not read a value kept under the name of a flags byte.
    probe(
        "e-flags",
        || {
            MapScheme::new(
                1,
                vec![flags(0, "f", vec![repeat(0, vec![u8("v")])]), u8("x")],
            )
        },
        Some(row(vec![
            ("f", Value::U8(1)),
            ("__repeat__", rounds(&[5, 6])),
            ("x", Value::U8(9)),
        ])),
    );

    // f: a repeat after a repeat. Both read their rounds from the one `__repeat__` key, so round 0
    // of each is the same `Values`: it holds `v` for the first repeat and `w` for the second.
    let two_repeats =
        || MapScheme::new(1, vec![repeat(0, vec![u8("v")]), repeat(1, vec![u8("w")])]);
    let both_names = row(vec![("v", Value::U8(5)), ("w", Value::U8(6))]);
    probe(
        "f",
        two_repeats,
        Some(row(vec![("__repeat__", Value::Groups(vec![both_names]))])),
    );

    // f-two-groups: the same scheme with the rounds given one after the other, a group for the
    // round of the first repeat and a group for the round of the second.
    let first = row(vec![("v", Value::U8(5))]);
    let second = row(vec![("w", Value::U8(6))]);
    probe(
        "f-two-groups",
        two_repeats,
        Some(row(vec![(
            "__repeat__",
            Value::Groups(vec![first, second]),
        )])),
    );
}
