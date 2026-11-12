//! The map form: `MapScheme` with `packbin::pack` and `packbin::unpack`, values keyed by field name.
//! The plain shape names of the README are this form.
//!
//! - A field is named; only the anchors of `when`, `times`, `flags` and `group` carry an order id.
//! - The element row is a `group` (the only row there is) as the element of the `list` or `dict`.
//! - A `Value` has no row variant for a list item; the nearest is `Value::Map` (name to value), which
//!   the probe gives when a scheme builds. A `Value::List` cannot hold a null item.
//! - `MapScheme::new` refuses a scheme with a panic (documented on `MapScheme::new`).
use crate::{caught, compared, hex, line, na, one_line};
use packbin::{
    dict, eq, group, insert, list, pack, times, u32, u8, unpack, utf8, when, MapScheme, Value,
    Values,
};
use std::collections::BTreeMap;

fn record(pairs: Vec<(&str, Value)>) -> Value {
    Value::Map(
        pairs
            .into_iter()
            .map(|(name, value)| (name.to_string(), value))
            .collect(),
    )
}

fn text(s: &str) -> Value {
    Value::Str(s.to_string())
}

fn comment(id: &str, body: Option<&str>, author_id: u32, author: &str) -> Value {
    let mut pairs = vec![("id", text(id))];
    if let Some(body) = body {
        pairs.push(("text", text(body)));
    }
    pairs.push(("authorId", Value::U32(author_id)));
    pairs.push(("author", text(author)));
    record(pairs)
}

fn c1() -> Value {
    comment("c1", Some("hi"), 7, "ann")
}
fn c2() -> Value {
    comment("c2", Some("ok"), 258, "bo")
}
fn c3() -> Value {
    comment("c3", Some("yes"), 1, "cy")
}

fn one(name: &str, value: Value) -> Values {
    let mut values = Values::new();
    insert(&mut values, name, Some(value));
    values
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
            "rust {shape}: the scheme built, and nothing is packed: a Value::List cannot hold a \
             null item"
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
        Err(message) => return line(shape, "built", &format!("threw: panic: {message}"), "-"),
    };
    let unpacked = match caught(|| unpack(&scheme, &packed)) {
        Ok(Ok(got)) => compared(shape, || {
            if got == values {
                "same".to_string()
            } else {
                let mut shown: Vec<String> =
                    got.iter().map(|(k, v)| format!("{k:?}: {v:?}")).collect();
                shown.sort();
                format!("differs: {{{}}}", one_line(&shown.join(", ")))
            }
        }),
        Ok(Err(error)) => format!("refused: {}", one_line(&format!("{error:?}"))),
        Err(message) => format!("threw: panic: {message}"),
    };
    line(shape, "built", &hex(&packed), &unpacked);
}

/// The element row of AZ-4199: `Comment = (utf8 id, utf8 text, u32 authorId, utf8 author)`.
fn comment_row() -> packbin::Field {
    group(
        0,
        "comment",
        vec![utf8("id"), utf8("text"), u32("authorId"), utf8("author")],
    )
}

fn listed() -> MapScheme {
    MapScheme::new(1, vec![list("items", comment_row())])
}

fn keyed() -> MapScheme {
    MapScheme::new(1, vec![dict("map", comment_row())])
}

pub fn run() {
    probe("list-0", listed, Some(one("items", Value::List(vec![]))));
    probe(
        "list-1",
        listed,
        Some(one("items", Value::List(vec![c1()]))),
    );
    probe(
        "list-3",
        listed,
        Some(one("items", Value::List(vec![c1(), c2(), c3()]))),
    );
    let map: BTreeMap<String, Value> = [("b".to_string(), c2()), ("a".to_string(), c1())]
        .into_iter()
        .collect();
    probe("dict-2", keyed, Some(one("map", Value::Map(map))));

    // pack reads a list only from Value::List and a dict only from Value::Map (any other Value,
    // Value::Groups too, is PackError::Type): there is no other collection type to name.
    na(
        "coll",
        "a list field takes Value::List and a dict field Value::Map; no other collection type",
    );

    // when inside an element row: speed is written only for mode 1.
    probe(
        "when",
        || {
            let element = group(
                0,
                "item",
                vec![
                    u8("mode"),
                    when(1, eq("mode", Value::U8(1)), vec![u8("speed")]),
                ],
            );
            MapScheme::new(1, vec![list("items", element)])
        },
        Some(one(
            "items",
            Value::List(vec![
                record(vec![("mode", Value::U8(1)), ("speed", Value::U8(7))]),
                record(vec![("mode", Value::U8(0))]),
            ]),
        )),
    );

    // times inside an element row: c rounds of v.
    probe(
        "times",
        || {
            let element = group(0, "item", vec![u8("c"), times(1, "c", vec![u8("v")])]);
            MapScheme::new(1, vec![list("items", element)])
        },
        Some(one(
            "items",
            Value::List(vec![
                record(vec![
                    ("c", Value::U8(2)),
                    ("v", Value::List(vec![Value::U8(5), Value::U8(6)])),
                ]),
                record(vec![("c", Value::U8(0)), ("v", Value::List(vec![]))]),
            ]),
        )),
    );

    na(
        "other-row",
        "no row types: a member reads a Values map by name (the typed Scheme<T> has no list or dict of rows)",
    );
    na(
        "nested-other-row",
        "no row types: a group's members are names in the row around it",
    );

    // A required member left out of an element.
    probe(
        "null-member",
        listed,
        Some(one(
            "items",
            Value::List(vec![comment("c1", None, 7, "ann")]),
        )),
    );

    // A list that holds a null element: a Value::List cannot hold one.
    probe("null-item", listed, None);
}
