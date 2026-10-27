#![cfg(feature = "std")]
use packbin::{
    bits, eq, flag_byte, flags, group, insert, pack, packed, repeat, sized, times, to_hex, u8,
    when, Field, MapScheme, PackError, Value, Values,
};

// AZ-2436 (assessment22 gap G3): the U11 refusal of AZ-2410 (`reference_loop22.md` row 56: a
// `bits`, `packed` or `sized` count above 0 behind a clear `when`, no value, member behind a clear
// bit) pinned in nested positions. The row 56 shape is `u8 mode; when mode == 1 { u8 c }`, then
// the counted member `v` behind a split flag bit or in a combined `flags`. Six positions, each in
// both forms and for the three kinds: the shape inside a group, a bit holding a group around the
// member, the shape inside an outer `when` that holds, a bit holding a holding `when` around the
// member, and the shape as the body of a `times` round and of a `repeat` round (the second round
// is the refused one). Count 0, a count left out and a holding `when` with a value pack as at
// HEAD (b8b2809). The member inside a clear `when` is the existing silent skip, not U11.

const KINDS: [&str; 3] = ["bits", "packed", "sized"];
const FORMS: [&str; 2] = ["split", "flags"];

fn n(x: u8) -> Value {
    Value::U8(x)
}

fn v(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

fn hex_of(scheme: &MapScheme, vals: &Values) -> Result<String, PackError> {
    pack(scheme, vals).map(|raw| to_hex(&raw))
}

fn member(kind: &str) -> Field {
    match kind {
        "bits" => bits("v", "c"),
        "packed" => packed(1, "v", "c", 0),
        _ => sized("v", "c"),
    }
}

/// A value for `v` with count 3.
fn three(kind: &str) -> Value {
    match kind {
        "sized" => Value::Bytes(vec![1, 2, 3]),
        _ => Value::List(vec![n(1), n(0), n(1)]),
    }
}

/// A value for `v` with count 1.
fn one(kind: &str) -> Value {
    match kind {
        "sized" => Value::Bytes(vec![9]),
        _ => Value::List(vec![n(1)]),
    }
}

/// `u8 mode; when mode == 1 { u8 c }`, its `when` at id `base + 1`.
fn head(base: u32) -> Vec<Field> {
    vec![u8("mode"), when(base + 1, eq("mode", n(1)), vec![u8("c")])]
}

/// `inner` (built at its id) behind a split flag bit or in a combined `flags`, starting at `next`.
fn placed(form: &str, next: u32, inner: &dyn Fn(u32) -> Field) -> Vec<Field> {
    if form == "split" {
        let fb = flag_byte("fb");
        vec![fb.byte(), fb.bit(inner(next + 1))]
    } else {
        vec![flags(next, "f", vec![inner(next)])]
    }
}

/// The row 56 shape whose `when` sits at `base + 1`.
fn shape(kind: &str, form: &str, base: u32) -> Vec<Field> {
    let mut fields = head(base);
    fields.extend(placed(form, base + 2, &|_| member(kind)));
    fields
}

const POSITIONS: [&str; 6] = [
    "group",
    "bit holding a group",
    "outer holding when",
    "bit holding a holding when",
    "times round",
    "repeat round",
];

fn scheme(position: &str, kind: &str, form: &str) -> MapScheme {
    let fields = match position {
        "group" => vec![group(0, "g", shape(kind, form, 0))],
        "bit holding a group" => {
            let mut fields = head(0);
            fields.extend(placed(form, 2, &|id| group(id, "g", vec![member(kind)])));
            fields
        }
        "outer holding when" => vec![u8("k"), when(1, eq("k", n(1)), shape(kind, form, 1))],
        "bit holding a holding when" => {
            let mut fields = vec![u8("k")];
            fields.extend(head(1));
            fields.extend(placed(form, 3, &|id| {
                when(id, eq("k", n(1)), vec![member(kind)])
            }));
            fields
        }
        "times round" => vec![u8("r"), times(1, "r", shape(kind, form, 1))],
        _ => vec![repeat(0, shape(kind, form, 0))],
    };
    MapScheme::new(1, fields)
}

/// The row for `position`: `pairs` at the top, after `k: 1` for the `when` positions, or as the
/// second round after a first round that holds the `when` and gives `v` with count 1.
fn row(position: &str, kind: &str, pairs: &[(&str, Value)]) -> Values {
    let first = || v(&[("mode", n(1)), ("c", n(1)), ("v", one(kind))]);
    match position {
        "outer holding when" | "bit holding a holding when" => {
            let mut vals = v(pairs);
            insert(&mut vals, "k", Some(n(1)));
            vals
        }
        "times round" => v(&[
            ("r", n(2)),
            ("__times_1", Value::Groups(vec![first(), v(pairs)])),
        ]),
        "repeat round" => v(&[("__repeat__", Value::Groups(vec![first(), v(pairs)]))]),
        _ => v(pairs),
    }
}

fn no_value() -> String {
    "v: the count c is 3 in the row, but no field wrote it (the when that holds it is clear), so \
     the member reads nothing; give the count 0, leave it out, or make the when hold"
        .to_string()
}

#[test]
fn ac1_to_ac3_count_3_and_no_value_is_refused_in_every_nested_position() {
    for position in POSITIONS {
        for kind in KINDS {
            for form in FORMS {
                // Arrange
                let scheme = scheme(position, kind, form);
                let vals = row(position, kind, &[("mode", n(0)), ("c", n(3))]);

                // Act
                let result = hex_of(&scheme, &vals);

                // Assert
                assert_eq!(
                    result,
                    Err(PackError::Type(no_value())),
                    "{position} {kind} {form}"
                );
            }
        }
    }
}

/// The bytes at HEAD of count 0 (and of the count left out, the same bytes) and of a holding
/// `when` with a value, for `bits` and `packed` (equal for these rows) and for `sized`.
fn at_head(position: &str) -> [(&'static str, &'static str); 2] {
    match position {
        "group" | "bit holding a group" => [("010000", "0101030105"), ("010000", "01010301010203")],
        "outer holding when" | "bit holding a holding when" => [
            ("01010000", "010101030105"),
            ("01010000", "0101010301010203"),
        ],
        "times round" => [
            ("0102010101010000", "01020101010101030105"),
            ("0102010101090000", "010201010109010301010203"),
        ],
        _ => [
            ("01010101010000", "010101010101030105"),
            ("01010101090000", "0101010109010301010203"),
        ],
    }
}

#[test]
fn ac4_count_zero_count_left_out_and_a_holding_when_pack_as_at_head() {
    for position in POSITIONS {
        for kind in KINDS {
            for form in FORMS {
                // Arrange
                let scheme = scheme(position, kind, form);
                let zero = row(position, kind, &[("mode", n(0)), ("c", n(0))]);
                let left_out = row(position, kind, &[("mode", n(0))]);
                let holding = row(
                    position,
                    kind,
                    &[("mode", n(1)), ("c", n(3)), ("v", three(kind))],
                );
                let (clear, held) = at_head(position)[usize::from(kind == "sized")];

                // Act
                let bytes = [
                    hex_of(&scheme, &zero),
                    hex_of(&scheme, &left_out),
                    hex_of(&scheme, &holding),
                ];

                // Assert
                let ok = |hex: &str| Ok(hex.to_string());
                assert_eq!(
                    bytes,
                    [ok(clear), ok(clear), ok(held)],
                    "{position} {kind} {form}"
                );
            }
        }
    }
}

#[test]
fn observed_a_member_inside_a_clear_when_is_skipped_without_a_word() {
    for kind in KINDS {
        for form in FORMS {
            // Arrange: the bit holds `when k == 1 { when j == 1 { v } }`; `j` is 0, so the member
            // is never reached and its count (behind the clear `when mode == 1`) is not U11's
            let mut fields = vec![u8("k"), u8("j")];
            fields.extend(head(2));
            fields.extend(placed(form, 4, &|id| {
                when(
                    id,
                    eq("k", n(1)),
                    vec![when(id, eq("j", n(1)), vec![member(kind)])],
                )
            }));
            let scheme = MapScheme::new(1, fields);
            let vals = v(&[("k", n(1)), ("j", n(0)), ("mode", n(0)), ("c", n(3))]);

            // Act
            let result = hex_of(&scheme, &vals);

            // Assert: a clear bit, as at HEAD
            assert_eq!(result, Ok("0101000000".to_string()), "{kind} {form}");
        }
    }
}
