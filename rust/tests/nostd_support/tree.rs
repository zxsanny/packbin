//! One scheme written once and built twice: as a `nostd` table and as a `std` `MapScheme`, so a
//! test packs and unpacks the same row with both walkers. A `std` name is `f<id>` for the field
//! of `nostd` order id `id`; a flag byte number `n` is the `std` flag byte `b<n>`.
#![allow(dead_code)]

use super::Slots;
use packbin::nostd::{self, Kind, Num, Row};
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
}

/// What a row holds for one `nostd` id.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Leaf {
    Num(Kind),
    Bytes(u16),
    Bool,
    Sized(u16),
    Bits(u16),
    Packed(u8, u16, i8),
    U2,
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
    for node in nodes {
        to_nostd(node, &mut next, &mut fields, &mut leaves);
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
    let mut next = 0u16;
    for node in nodes {
        to_nostd(node, &mut next, &mut fields, &mut Vec::new());
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

fn to_nostd(
    node: &Node,
    next: &mut u16,
    out: &mut Vec<nostd::Field>,
    leaves: &mut Vec<(u16, Leaf)>,
) {
    let id = *next;
    let leaf = match node {
        Node::Num(k) | Node::Be(k) => Some((Leaf::Num(*k), leaf_field(*k, id))),
        Node::Bytes(n) => Some((Leaf::Bytes(*n), nostd::bytes(id, *n))),
        Node::Bool => Some((Leaf::Bool, nostd::boolean(id))),
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
        return;
    }
    match node {
        Node::FlagByte(n) => out.push(nostd::flag_byte(*n)),
        Node::U2(n) => {
            out.push(nostd::u2(id, *n));
            for k in 0..*n {
                leaves.push((id + k, Leaf::U2));
                out.push(nostd::u8(id + k));
            }
            *next += n;
        }
        Node::Flags(body) | Node::When(_, _, body) => {
            let head = out.len();
            out.push(match node {
                Node::When(source, value, _) => nostd::when(id, *source, *value, 0),
                _ => nostd::flags(id, 0),
            });
            for member in body {
                to_nostd(member, next, out, leaves);
            }
            out[head].span = (out.len() - head) as u16;
        }
        Node::FlagBit(n, inner) => {
            let head = out.len();
            out.push(nostd::flag_bit(*n, 0));
            to_nostd(inner, next, out, leaves);
            out[head].span = (out.len() - head) as u16;
        }
        _ => unreachable!("leaves are handled above"),
    }
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

/// `id` follows the `nostd` order ids, `anchor` the `std` ones (a `std` flag byte takes one).
fn to_std(node: &Node, id: &mut u16, anchor: &mut u32) -> packbin::Field {
    let here = *anchor;
    match node {
        Node::Num(k) => std_number(*k, &step(id, anchor)),
        Node::Be(k) => packbin::be(std_number(*k, &step(id, anchor))),
        Node::Bytes(n) => packbin::bytes(step(id, anchor), usize::from(*n)),
        Node::Bool => packbin::group(here, step(id, anchor), vec![]),
        Node::Sized(c) => packbin::sized(step(id, anchor), name(*c)),
        Node::Bits(c) => packbin::bits(step(id, anchor), name(*c)),
        Node::Packed(w, c, b) => packbin::packed(*w, step(id, anchor), name(*c), *b),
        Node::U2(n) => {
            let names: Vec<String> = (0..*n).map(|_| step(id, anchor)).collect();
            let refs: Vec<&str> = names.iter().map(String::as_str).collect();
            packbin::u2(&refs)
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
        Node::When(source, value, body) => {
            let members = body.iter().map(|m| to_std(m, id, anchor)).collect();
            packbin::when(here, packbin::eq(name(*source), eq_value(*value)), members)
        }
    }
}

/// The `std` values of a `nostd` row: absent members (and false bools) are left out.
pub fn values_of(row: &Slots, leaves: &[(u16, Leaf)]) -> Values {
    let mut values = Values::new();
    for (id, leaf) in leaves {
        if let Some(v) = value_of(row, *id, *leaf) {
            insert(&mut values, name(*id), Some(v));
        }
    }
    values
}

pub fn value_of(row: &Slots, id: u16, leaf: Leaf) -> Option<Value> {
    match leaf {
        Leaf::Num(_) | Leaf::U2 => row.num(id).map(to_value),
        Leaf::Bytes(_) | Leaf::Sized(_) => row.bytes(id).map(|b| Value::Bytes(b.to_vec())),
        Leaf::Bits(_) | Leaf::Packed(..) => row
            .bytes(id)
            .map(|b| Value::List(b.iter().map(|v| Value::U8(*v)).collect())),
        Leaf::Bool => row.flag(id).then_some(Value::U8(1)),
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
        _ => a == b,
    }
}

/// The `std` value of `id` in `values`, as `values_of` would write it.
pub fn std_value(values: &Values, id: u16) -> Option<&Value> {
    values.get(name(id).as_str()).and_then(|v| v.as_ref())
}
