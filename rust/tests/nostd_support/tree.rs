//! One scheme written once and built twice: as a `nostd` table and as a `std` `MapScheme`, so a
//! test packs and unpacks the same row with both walkers. A `std` name is `f<id>` for the field
//! of `nostd` order id `id`; a flag byte number `n` is the `std` flag byte `b<n>`.
#![allow(dead_code)]

use packbin::nostd::{self, Kind, Num, Row, DICT_KEY};
use packbin::{insert, MapScheme, Value, Values};

#[derive(Clone, Debug)]
pub enum Node {
    Num(Kind),
    Be(Kind),
    Bytes(u16),
    Bool,
    Flags(Vec<Node>),
    FlagByte(u16),
    FlagBit(u16, Box<Node>),
    /// Source id, value, body.
    When(u16, i64, Vec<Node>),
    Sized(u16),
    Bits(u16),
    /// Width, count id, bias.
    Packed(u8, u16, i8),
    U2(u16),
    Group(Vec<Node>),
    Repeat(Vec<Node>),
    /// Count id, body.
    Times(u16, Vec<Node>),
    List(Box<Node>),
    /// A decoded string (needs `text`).
    Utf8,
    /// A string kept as on the wire.
    Wire,
    /// A dictionary of this element (needs `text`).
    Dict(Box<Node>),
}

/// What a row holds for one `nostd` id.
#[derive(Clone, Debug, PartialEq)]
pub enum Leaf {
    Num(Kind),
    Bytes(u16),
    Bool,
    Sized(u16),
    Bits(u16),
    Packed(u8, u16, i8),
    U2,
    /// The members of one round.
    Repeat(Vec<(u16, Leaf)>),
    /// The `std` key of the rounds, the count id, the members of one round.
    Times(String, u16, Vec<(u16, Leaf)>),
    /// The element (id 0 of each item).
    List(Box<Leaf>),
    Utf8,
    Wire,
    /// The element (id 0 of each item; the key sits under `DICT_KEY`).
    Dict(Box<Leaf>),
}

pub struct Built {
    pub fields: Vec<nostd::Field>,
    pub reference: MapScheme,
    pub leaves: Vec<(u16, Leaf)>,
}

pub fn build(type_number: u8, nodes: &[Node]) -> Built {
    let mut fields = Vec::new();
    let mut leaves = Vec::new();
    let mut next = 0u16;
    let mut anchor = 0u32;
    for node in nodes {
        to_nostd(node, &mut next, &mut anchor, &mut fields, &mut leaves);
    }
    let reference = MapScheme::new(i32::from(type_number), std_fields(nodes));
    Built {
        fields,
        reference,
        leaves,
    }
}

/// The `std` fields alone (`MapScheme::new` panics on a scheme it refuses).
pub fn std_fields(nodes: &[Node]) -> Vec<packbin::Field> {
    let mut id = 0u16;
    let mut anchor = 0u32;
    nodes
        .iter()
        .map(|n| to_std(n, &mut id, &mut anchor))
        .collect()
}

/// The `nostd` table alone.
pub fn nostd_fields(nodes: &[Node]) -> Vec<nostd::Field> {
    let mut fields = Vec::new();
    let (mut next, mut anchor) = (0u16, 0u32);
    for node in nodes {
        to_nostd(node, &mut next, &mut anchor, &mut fields, &mut Vec::new());
    }
    fields
}

fn leaf_field(kind: Kind, id: u16) -> nostd::Field {
    match kind {
        Kind::U8 => nostd::u8(id),
        Kind::U16 => nostd::u16(id),
        Kind::U32 => nostd::u32(id),
        Kind::U64 => nostd::u64(id),
        Kind::I8 => nostd::i8(id),
        Kind::I16 => nostd::i16(id),
        Kind::I32 => nostd::i32(id),
        Kind::I64 => nostd::i64(id),
        Kind::F32 => nostd::f32(id),
        Kind::F64 => nostd::f64(id),
        other => panic!("not a number: {other:?}"),
    }
}

/// `next` is the `nostd` order id, `anchor` the `std` one (kept to name a `times`' rounds).
fn to_nostd(
    node: &Node,
    next: &mut u16,
    anchor: &mut u32,
    out: &mut Vec<nostd::Field>,
    leaves: &mut Vec<(u16, Leaf)>,
) {
    let id = *next;
    let here = *anchor;
    let leaf = match node {
        Node::Num(k) | Node::Be(k) => Some((Leaf::Num(*k), leaf_field(*k, id))),
        Node::Bytes(n) => Some((Leaf::Bytes(*n), nostd::bytes(id, *n))),
        Node::Bool => Some((Leaf::Bool, nostd::boolean(id))),
        Node::Utf8 => Some((Leaf::Utf8, nostd::utf8(id))),
        Node::Wire => Some((Leaf::Wire, nostd::utf8_wire(id))),
        Node::Sized(c) => Some((Leaf::Sized(*c), nostd::sized(id, *c))),
        Node::Bits(c) => Some((Leaf::Bits(*c), nostd::bits(id, *c))),
        Node::Packed(w, c, b) => Some((Leaf::Packed(*w, *c, *b), nostd::packed(*w, id, *c, *b))),
        _ => None,
    };
    if let Some((leaf, field)) = leaf {
        leaves.push((id, leaf));
        out.push(if matches!(node, Node::Be(_)) {
            nostd::be(field)
        } else {
            field
        });
        *next += 1;
        *anchor += 1;
        return;
    }
    let head = out.len();
    match node {
        Node::FlagByte(n) => {
            out.push(nostd::flag_byte(*n));
            *anchor += 1;
            return;
        }
        Node::U2(n) => {
            out.push(nostd::u2(id, *n));
            for k in 0..*n {
                leaves.push((id + k, Leaf::U2));
                out.push(nostd::u8(id + k));
            }
            *next += n;
            *anchor += u32::from(*n);
            return;
        }
        Node::Flags(body) | Node::When(_, _, body) | Node::Group(body) => {
            out.push(match node {
                Node::When(source, value, _) => nostd::when(id, *source, *value, 0),
                Node::Group(_) => nostd::group(id, 0),
                _ => nostd::flags(id, 0),
            });
            for member in body {
                to_nostd(member, next, anchor, out, leaves);
            }
        }
        Node::Repeat(body) | Node::Times(_, body) => {
            out.push(match node {
                Node::Times(count, _) => nostd::times(id, *count, 0),
                _ => nostd::repeat(id, 0),
            });
            let mut inner = Vec::new();
            for member in body {
                to_nostd(member, next, anchor, out, &mut inner);
            }
            leaves.push(match node {
                Node::Times(count, _) => {
                    (id, Leaf::Times(format!("__times_{here}"), *count, inner))
                }
                _ => (id, Leaf::Repeat(inner)),
            });
        }
        Node::List(element) => {
            out.push(nostd::list(id, 0));
            let mut inner = Vec::new();
            let (mut e, mut a) = (0u16, 0u32);
            to_nostd(element, &mut e, &mut a, out, &mut inner);
            let (_, leaf) = inner.pop().expect("an element");
            leaves.push((id, Leaf::List(Box::new(leaf))));
            *next += 1;
        }
        Node::Dict(element) => {
            out.push(nostd::dict(id, 0));
            out.push(nostd::key());
            let mut inner = Vec::new();
            let (mut e, mut a) = (0u16, 0u32);
            to_nostd(element, &mut e, &mut a, out, &mut inner);
            let (_, leaf) = inner.pop().expect("an element");
            leaves.push((id, Leaf::Dict(Box::new(leaf))));
            *next += 1;
        }
        Node::FlagBit(n, inner) => {
            out.push(nostd::flag_bit(*n, 0));
            to_nostd(inner, next, anchor, out, leaves);
        }
        _ => unreachable!("leaves are handled above"),
    }
    out[head].span = (out.len() - head) as u16;
}

fn name(id: u16) -> String {
    format!("f{id}")
}

fn std_number(kind: Kind, n: &str) -> packbin::Field {
    match kind {
        Kind::U8 => packbin::u8(n),
        Kind::U16 => packbin::u16(n),
        Kind::U32 => packbin::u32(n),
        Kind::U64 => packbin::u64(n),
        Kind::I8 => packbin::i8(n),
        Kind::I16 => packbin::i16(n),
        Kind::I32 => packbin::i32(n),
        Kind::I64 => packbin::i64(n),
        Kind::F32 => packbin::f32(n),
        Kind::F64 => packbin::f64(n),
        other => panic!("not a number: {other:?}"),
    }
}

fn eq_value(value: i64) -> Value {
    if value < 0 {
        Value::I64(value)
    } else {
        Value::U64(value as u64)
    }
}

fn step(id: &mut u16, anchor: &mut u32) -> String {
    let n = name(*id);
    *id += 1;
    *anchor += 1;
    n
}

/// A list element in `std`: one field named `e`.
fn std_element(node: &Node) -> packbin::Field {
    match node {
        Node::Num(k) => std_number(*k, "e"),
        Node::Be(k) => packbin::be(std_number(*k, "e")),
        Node::Bytes(n) => packbin::bytes("e", usize::from(*n)),
        Node::U2(1) => packbin::u2(&["e"]),
        Node::List(inner) => packbin::list("e", std_element(inner)),
        Node::Utf8 => packbin::utf8("e"),
        Node::Dict(inner) => packbin::dict("e", std_element(inner)),
        other => panic!("not an element: {other:?}"),
    }
}

/// `id` follows the `nostd` order ids, `anchor` the `std` ones (a `std` flag byte takes one, a
/// `std` list none).
fn to_std(node: &Node, id: &mut u16, anchor: &mut u32) -> packbin::Field {
    let here = *anchor;
    match node {
        Node::Num(k) => std_number(*k, &step(id, anchor)),
        Node::Be(k) => packbin::be(std_number(*k, &step(id, anchor))),
        Node::Bytes(n) => packbin::bytes(step(id, anchor), usize::from(*n)),
        Node::Utf8 => packbin::utf8(step(id, anchor)),
        Node::Wire => panic!("a wire string has no std field"),
        Node::Bool => packbin::group(here, step(id, anchor), vec![]),
        Node::Sized(c) => packbin::sized(step(id, anchor), name(*c)),
        Node::Bits(c) => packbin::bits(step(id, anchor), name(*c)),
        Node::Packed(w, c, b) => packbin::packed(*w, step(id, anchor), name(*c), *b),
        Node::U2(n) => {
            let names: Vec<String> = (0..*n).map(|_| step(id, anchor)).collect();
            let refs: Vec<&str> = names.iter().map(String::as_str).collect();
            packbin::u2(&refs)
        }
        Node::Dict(element) => {
            let n = name(*id);
            *id += 1;
            packbin::dict(n, std_element(element))
        }
        Node::FlagByte(n) => {
            *anchor += 1;
            packbin::flag_byte(format!("b{n}")).byte()
        }
        Node::FlagBit(n, inner) => {
            packbin::flag_byte(format!("b{n}")).bit(to_std(inner, id, anchor))
        }
        Node::Flags(body) => {
            let members = body.iter().map(|m| to_std(m, id, anchor)).collect();
            packbin::flags(here, format!("x{here}"), members)
        }
        Node::Group(body) => {
            let members = body.iter().map(|m| to_std(m, id, anchor)).collect();
            packbin::group(here, format!("g{here}"), members)
        }
        Node::When(source, value, body) => {
            let members = body.iter().map(|m| to_std(m, id, anchor)).collect();
            packbin::when(here, packbin::eq(name(*source), eq_value(*value)), members)
        }
        Node::Repeat(body) => {
            let members = body.iter().map(|m| to_std(m, id, anchor)).collect();
            packbin::repeat(here, members)
        }
        Node::Times(count, body) => {
            let members = body.iter().map(|m| to_std(m, id, anchor)).collect();
            packbin::times(here, name(*count), members)
        }
        Node::List(element) => {
            let n = name(*id);
            *id += 1;
            packbin::list(n, std_element(element))
        }
    }
}

/// The `std` values of a `nostd` row: absent members (and false bools) are left out.
pub fn values_of(row: &dyn Row, leaves: &[(u16, Leaf)]) -> Values {
    let mut values = Values::new();
    for (id, leaf) in leaves {
        if let Some(v) = value_of(row, *id, leaf) {
            insert(&mut values, key_of(*id, leaf), Some(v));
        }
    }
    values
}

fn key_of(id: u16, leaf: &Leaf) -> String {
    match leaf {
        Leaf::Repeat(_) => "__repeat__".to_string(),
        Leaf::Times(key, ..) => key.clone(),
        _ => name(id),
    }
}

fn items(row: &dyn Row, id: u16) -> Vec<&dyn Row> {
    let n = row.count(id).unwrap_or(0);
    (0..n).filter_map(|k| row.item(id, k)).collect()
}

pub fn value_of(row: &dyn Row, id: u16, leaf: &Leaf) -> Option<Value> {
    match leaf {
        Leaf::Num(_) | Leaf::U2 => row.num(id).map(to_value),
        Leaf::Bytes(_) | Leaf::Sized(_) => row.bytes(id).map(|b| Value::Bytes(b.to_vec())),
        Leaf::Bits(_) | Leaf::Packed(..) => row
            .bytes(id)
            .map(|b| Value::List(b.iter().map(|v| Value::U8(*v)).collect())),
        Leaf::Bool => row.flag(id).then_some(Value::U8(1)),
        Leaf::Utf8 => row
            .bytes(id)
            .map(|b| Value::Str(String::from_utf8_lossy(b).into_owned())),
        Leaf::Wire => row.bytes(id).map(|b| Value::Bytes(b.to_vec())),
        Leaf::Dict(element) => row.count(id).map(|_| {
            Value::Map(
                items(row, id)
                    .iter()
                    .map(|r| {
                        let key = String::from_utf8_lossy(r.bytes(DICT_KEY).unwrap_or(&[]));
                        (
                            key.into_owned(),
                            value_of(*r, 0, element).unwrap_or(Value::Bytes(vec![0xEE; 99])),
                        )
                    })
                    .collect(),
            )
        }),
        Leaf::Repeat(body) => {
            let rounds = items(row, id);
            (!rounds.is_empty())
                .then(|| Value::Groups(rounds.iter().map(|r| values_of(*r, body)).collect()))
        }
        Leaf::Times(_, _, body) => row
            .count(id)
            .map(|_| Value::Groups(items(row, id).iter().map(|r| values_of(*r, body)).collect())),
        Leaf::List(element) => row.count(id).map(|_| {
            Value::List(
                items(row, id)
                    .iter()
                    .map(|r| value_of(*r, 0, element).unwrap_or(Value::Bytes(vec![0xEE; 99])))
                    .collect(),
            )
        }),
    }
}

pub fn to_value(num: Num) -> Value {
    match num {
        Num::U8(v) => Value::U8(v),
        Num::U16(v) => Value::U16(v),
        Num::U32(v) => Value::U32(v),
        Num::U64(v) => Value::U64(v),
        Num::I8(v) => Value::I8(v),
        Num::I16(v) => Value::I16(v),
        Num::I32(v) => Value::I32(v),
        Num::I64(v) => Value::I64(v),
        Num::F32(v) => Value::F32(v),
        Num::F64(v) => Value::F64(v),
    }
}

/// Equal values, floats by their bits.
pub fn same(a: &Value, b: &Value) -> bool {
    match (a, b) {
        (Value::F32(x), Value::F32(y)) => x.to_bits() == y.to_bits(),
        (Value::F64(x), Value::F64(y)) => x.to_bits() == y.to_bits(),
        (Value::List(x), Value::List(y)) => {
            x.len() == y.len() && x.iter().zip(y).all(|(p, q)| same(p, q))
        }
        (Value::Map(x), Value::Map(y)) => {
            x.len() == y.len() && x.iter().zip(y).all(|(p, q)| p.0 == q.0 && same(p.1, q.1))
        }
        _ => a == b,
    }
}

/// The `std` value of `id` in `values`, as `values_of` would write it.
pub fn std_value(values: &Values, id: u16) -> Option<&Value> {
    values.get(name(id).as_str()).and_then(|v| v.as_ref())
}

/// Every leaf of `row` holds what `read` (a `std` unpack) holds for it; rounds member by member
/// (the `std` rounds also hold the bytes of each `flags` and flag byte, not compared).
pub fn compare(read: &Values, row: &dyn Row, leaves: &[(u16, Leaf)]) -> Result<(), String> {
    for (id, leaf) in leaves {
        let theirs = read
            .get(key_of(*id, leaf).as_str())
            .and_then(|v| v.as_ref());
        match (leaf, theirs) {
            (Leaf::Repeat(body) | Leaf::Times(_, _, body), Some(Value::Groups(rounds))) => {
                let ours = items(row, *id);
                if ours.len() != rounds.len() {
                    return Err(format!(
                        "id {id}: {} rounds, std {}",
                        ours.len(),
                        rounds.len()
                    ));
                }
                for (r, (mine, std_round)) in ours.iter().zip(rounds).enumerate() {
                    compare(std_round, *mine, body)
                        .map_err(|e| format!("id {id} round {r}: {e}"))?;
                }
                if matches!(leaf, Leaf::Times(..)) && row.count(*id).is_none() {
                    return Err(format!("id {id}: no rounds, std {}", rounds.len()));
                }
            }
            _ => {
                let ours = value_of(row, *id, leaf);
                let equal = match (&ours, theirs) {
                    (Some(x), Some(y)) => same(x, y),
                    (None, None) => true,
                    _ => false,
                };
                if !equal {
                    return Err(format!("id {id}: nostd {ours:?} std {theirs:?}"));
                }
            }
        }
    }
    Ok(())
}

/// True when the `std` walker refuses the scheme (`MapScheme::new` panics), with the panic message
/// kept off the test output.
pub fn std_refuses(nodes: &[Node]) -> bool {
    let nodes = nodes.to_vec();
    let quiet = std::panic::take_hook();
    std::panic::set_hook(Box::new(|_| {}));
    let refused = std::panic::catch_unwind(move || MapScheme::new(1, std_fields(&nodes))).is_err();
    std::panic::set_hook(quiet);
    refused
}
