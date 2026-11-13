//! The heap-free API `packbin::nostd`: a scheme is a table of entries, a row is read and written by
//! field id through the `Row` trait, and errors are `Fault` values. The lines carry `-nostd` after
//! the shape name.
//!
//! - S is `flags(0, 3)` (three entries below it), `flags(0, 1)`, `u8(0)`, `boolean(1)`.
//! - `x` is `num(0)` (`None` when absent), `b` is `flag(1)`.
//! - Build is `validate`, which `pack` and `unpack` call first.
use crate::{caught, compared, hex, stopped, values_of, Cells};
use packbin::nostd::{boolean, flags, pack, u8, unpack, validate, Field, Num, Row, Scheme};

const FIELDS: [Field; 4] = [flags(0, 3), flags(0, 1), u8(0), boolean(1)];

#[derive(Clone, Debug, Default, PartialEq)]
struct Slots {
    x: Option<u8>,
    b: bool,
}

impl Row for Slots {
    fn num(&self, id: u16) -> Option<Num> {
        if id == 0 {
            self.x.map(Num::U8)
        } else {
            None
        }
    }
    fn bytes(&self, _id: u16) -> Option<&[u8]> {
        None
    }
    fn set_num(&mut self, id: u16, value: Num) -> bool {
        match (id, value) {
            (0, Num::U8(x)) => {
                self.x = Some(x);
                true
            }
            _ => false,
        }
    }
    fn set_bytes(&mut self, _id: u16, _value: &[u8]) -> bool {
        false
    }
    fn flag(&self, id: u16) -> bool {
        id == 1 && self.b
    }
    fn set_flag(&mut self, id: u16, on: bool) -> bool {
        if id == 1 {
            self.b = on;
        }
        id == 1
    }
    fn clear(&mut self, id: u16) {
        match id {
            0 => self.x = None,
            1 => self.b = false,
            _ => {}
        }
    }
}

pub fn probe(shape: &str) -> Cells {
    let scheme = Scheme::new(1, &FIELDS);
    match caught(|| validate(&scheme)) {
        Ok(Ok(())) => {}
        Ok(Err(fault)) => return stopped(&[format!("refused: {fault:?}")]),
        Err(message) => return stopped(&[format!("refused: panic: {message}")]),
    }
    let (x, b) = values_of(shape);
    let given = Slots {
        x,
        b: b.unwrap_or(false),
    };
    let mut out = [0u8; 16];
    let n = match caught(|| pack(&scheme, &given, &mut out)) {
        Ok(Ok(n)) => n,
        Ok(Err(fault)) => return stopped(&["built".into(), format!("refused: {fault:?}")]),
        Err(message) => return stopped(&["built".into(), format!("refused: panic: {message}")]),
    };
    let packed = &out[..n];
    let mut back = Slots::default();
    let unpacked = match caught(|| unpack(&scheme, packed, &mut back)) {
        Ok(Ok(_)) => compared(&format!("{shape}-nostd"), || {
            if back == given {
                "same".to_string()
            } else {
                format!("differs: {back:?}")
            }
        }),
        Ok(Err(fault)) => format!("refused: {fault:?}"),
        Err(message) => format!("threw: {message}"),
    };
    ["built".into(), hex(packed), unpacked]
}
