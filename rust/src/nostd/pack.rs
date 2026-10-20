//! The pack walk over a checked table (the C++ `pack.cpp` port).

use super::error::{Error, Fault};
use super::io::Writer;
use super::present::{present, read_int, source_value, when_matches};
use super::row::Row;
use super::scheme::{Field, Kind};
use super::table::{
    bit_position, end, flag_byte_of, for_each_late, get, id_of, level, members, round_width,
    slot_of,
};

/// The round limits of one call and the slots its rounds have charged so far.
pub(crate) struct Budget {
    pub max_rounds: usize,
    pub max_slots: usize,
    pub slots: usize,
}

impl Budget {
    /// Admits round number `started` (from 0) of the container `f` that charges `width` slots;
    /// the round that would pass a limit is `TooMany` naming the limit.
    pub(crate) fn start_round(
        &mut self,
        f: &Field,
        at: usize,
        started: usize,
        width: usize,
    ) -> Result<(), Fault> {
        if started >= self.max_rounds {
            return Err(Fault::new(Error::TooMany, at, id_of(f), self.max_rounds));
        }
        let total = self.slots.saturating_add(width);
        if total > self.max_slots {
            return Err(Fault::new(Error::TooMany, at, id_of(f), self.max_slots));
        }
        self.slots = total;
        Ok(())
    }
}

pub(crate) struct Pack<'t, 'w, 'b> {
    pub t: &'t [Field],
    pub w: &'w mut Writer<'b>,
    pub row: &'t dyn Row,
    pub budget: &'w mut Budget,
}

fn bad(at: usize, f: &Field) -> Fault {
    Fault::new(Error::BadValue, at, id_of(f), 0)
}

/// A number as its little-endian bytes, reversed for a big-endian field.
pub(crate) fn number_bytes(bits: u64, width: usize, big_endian: bool) -> [u8; 8] {
    let little = bits.to_le_bytes();
    let mut ordered = [0u8; 8];
    let low = little.get(..width).unwrap_or(&[]);
    // `reverse()` and `copy_from_slice` have panic paths; zipped copies do not.
    if big_endian {
        for (slot, byte) in ordered.iter_mut().zip(low.iter().rev()) {
            *slot = *byte;
        }
    } else {
        for (slot, byte) in ordered.iter_mut().zip(low.iter()) {
            *slot = *byte;
        }
    }
    ordered
}

/// Bytes that `n` values of `width` bits take.
fn clamp_bits(n: usize, width: u64) -> usize {
    let bits = u64::try_from(n).unwrap_or(u64::MAX).saturating_mul(width);
    usize::try_from(bits.div_ceil(8)).unwrap_or(usize::MAX)
}

impl Pack<'_, '_, '_> {
    pub(crate) fn top(&mut self) -> Result<(), Fault> {
        for j in level(self.t, 0, self.t.len()) {
            self.one(j)?;
        }
        Ok(())
    }

    fn field(&self, i: usize) -> Result<&Field, Fault> {
        get(self.t, i).ok_or_else(|| Fault::new(Error::SchemeInvalid, self.w.len(), -1, 0))
    }

    fn members(&mut self, i: usize) -> Result<(), Fault> {
        for j in members(self.t, i) {
            self.one(j)?;
        }
        Ok(())
    }

    fn one(&mut self, i: usize) -> Result<(), Fault> {
        let f = *self.field(i)?;
        if let Some(width) = f.kind.width() {
            return self.number(&f, width);
        }
        match f.kind {
            Kind::Bool => Ok(()),
            Kind::FlagByte => self.flag_byte(i, &f),
            Kind::Bytes | Kind::Sized => self.bytes(i, &f),
            Kind::When if when_matches(self.t, i, self.row) => self.members(i),
            Kind::When => Ok(()),
            Kind::Flags => self.flags(i, &f),
            Kind::FlagBit => {
                let body = i.saturating_add(1);
                if present(self.t, body, self.row, false) {
                    self.one(body)
                } else {
                    Ok(())
                }
            }
            Kind::U2 => self.u2(i, &f),
            Kind::Bits | Kind::Packed => self.small(i, &f),
            Kind::Group => self.members(i),
            Kind::Repeat | Kind::Times | Kind::List => self.container(i, &f),
            _ => Err(Fault::new(Error::SchemeInvalid, self.w.len(), id_of(&f), 0)),
        }
    }

    /// The items of a `repeat` (as many as the row holds), a `times` (its count, which must be
    /// the row's) or a `list` (a u16 count first), each packed from its own item row.
    fn container(&mut self, i: usize, f: &Field) -> Result<(), Fault> {
        let at = self.w.len();
        let held = self.row.count(f.id);
        let n = match f.kind {
            Kind::Times => {
                let count = source_value(self.t, i, self.row)
                    .and_then(|c| usize::try_from(c).ok())
                    .ok_or_else(|| bad(at, f))?;
                if held.unwrap_or(0) != count {
                    return Err(bad(at, f));
                }
                count
            }
            Kind::List => {
                let n = held.ok_or_else(|| bad(at, f))?;
                let wire = u16::try_from(n).map_err(|_| bad(at, f))?;
                self.w.put(&wire.to_le_bytes(), id_of(f))?;
                n
            }
            _ => held.unwrap_or(0),
        };
        let rounds = f.kind != Kind::List;
        if rounds && n > self.budget.max_rounds {
            return Err(Fault::new(
                Error::TooMany,
                at,
                id_of(f),
                self.budget.max_rounds,
            ));
        }
        let width = round_width(self.t, i.saturating_add(1), end(self.t, i));
        for k in 0..n {
            if rounds {
                self.budget.start_round(f, self.w.len(), k, width)?;
            }
            let item = self.row.item(f.id, k).ok_or_else(|| bad(self.w.len(), f))?;
            Pack {
                t: self.t,
                w: &mut *self.w,
                row: item,
                budget: &mut *self.budget,
            }
            .members(i)?;
        }
        Ok(())
    }

    fn number(&mut self, f: &Field, width: usize) -> Result<(), Fault> {
        let num = self
            .row
            .num(f.id)
            .filter(|n| n.kind() == f.kind)
            .ok_or_else(|| bad(self.w.len(), f))?;
        let ordered = number_bytes(num.bits(), width, f.big_endian);
        let wire = ordered.get(..width).ok_or_else(|| bad(self.w.len(), f))?;
        self.w.put(wire, id_of(f))
    }

    /// `bytes` (length checked against the field) and `sized` (against its count as written).
    fn bytes(&mut self, i: usize, f: &Field) -> Result<(), Fault> {
        let value = self.row.bytes(f.id).ok_or_else(|| bad(self.w.len(), f))?;
        let want = if f.kind == Kind::Sized {
            source_value(self.t, i, self.row).and_then(|n| usize::try_from(n).ok())
        } else {
            Some(usize::from(f.size))
        };
        if want != Some(value.len()) {
            return Err(bad(self.w.len(), f));
        }
        self.w.put(value, id_of(f))
    }

    fn flags(&mut self, i: usize, f: &Field) -> Result<(), Fault> {
        let mut byte = 0u8;
        for (k, j) in members(self.t, i).enumerate() {
            if present(self.t, j, self.row, false) {
                byte |= 1u8.checked_shl(k as u32).unwrap_or(0);
            }
        }
        self.w.put(&[byte], id_of(f))?;
        for (k, j) in members(self.t, i).enumerate() {
            if byte & 1u8.checked_shl(k as u32).unwrap_or(0) != 0 {
                self.one(j)?;
            }
        }
        Ok(())
    }

    /// The bits of a flag byte: one per flag bit of this byte whose member is present. A member
    /// that only its late `when`s hold cannot be read back, so pack refuses it.
    fn flag_byte(&mut self, i: usize, f: &Field) -> Result<(), Fault> {
        let mut byte = 0u8;
        for j in i.saturating_add(1)..self.t.len() {
            let body = j.saturating_add(1);
            let mine = get(self.t, j).is_some_and(|b| b.kind == Kind::FlagBit)
                && flag_byte_of(self.t, j) == Some(i);
            if !mine || !present(self.t, body, self.row, false) {
                continue;
            }
            if !present(self.t, body, self.row, true) {
                let mut refused = None;
                for_each_late(self.t, j, |k| {
                    if present(self.t, k, self.row, false) {
                        refused = Some(k);
                    }
                    refused.is_none()
                });
                if let Some(k) = refused {
                    return Err(bad(self.w.len(), self.field(k)?));
                }
            }
            let position = bit_position(self.t, i, j) as u32;
            byte |= 1u8.checked_shl(position).unwrap_or(0);
        }
        self.w.put(&[byte], id_of(f))
    }

    fn u2(&mut self, i: usize, f: &Field) -> Result<(), Fault> {
        let k = usize::from(f.span).saturating_sub(1);
        let nbytes = k.div_ceil(4);
        let mut raw = [0u8; 16];
        let at = self.w.len();
        if self.w.room() < nbytes {
            return Err(Fault::new(Error::BufferFull, at, id_of(f), nbytes));
        }
        for (c, j) in members(self.t, i).enumerate() {
            let child = self.field(j)?;
            let value = read_int(child, self.row)
                .filter(|v| (0..=3).contains(v))
                .ok_or_else(|| bad(at, child))?;
            let (byte, shift) = slot_of(c, 2);
            let slot = raw.get_mut(byte).ok_or_else(|| bad(at, f))?;
            *slot |= (value as u8).checked_shl(shift).unwrap_or(0);
        }
        let wire = raw.get(..nbytes).ok_or_else(|| bad(at, f))?;
        self.w.put(wire, id_of(f))
    }

    /// `bits` (width 1) or `packed` numbers (width 1 or 2) from the row's values.
    fn small(&mut self, i: usize, f: &Field) -> Result<(), Fault> {
        let at = self.w.len();
        let mut count = source_value(self.t, i, self.row).ok_or_else(|| bad(at, f))?;
        let width: u64 = if f.kind == Kind::Bits {
            1
        } else {
            u64::from(f.width)
        };
        if f.kind == Kind::Packed {
            count = count.saturating_add(i64::from(f.bias));
        }
        let values = self.row.bytes(f.id).ok_or_else(|| bad(at, f))?;
        if usize::try_from(count).ok() != Some(values.len()) {
            return Err(bad(at, f));
        }
        let max = if width == 2 { 3 } else { 1 };
        let nbytes = clamp_bits(values.len(), width);
        let dst = self.w.reserve(nbytes, id_of(f))?;
        for slot in dst.iter_mut() {
            *slot = 0;
        }
        for (k, value) in values.iter().enumerate() {
            if *value > max {
                return Err(bad(at, f));
            }
            let (byte, shift) = slot_of(k, width);
            let slot = dst.get_mut(byte).ok_or_else(|| bad(at, f))?;
            *slot |= value.checked_shl(shift).unwrap_or(0);
        }
        self.w.advance(nbytes);
        Ok(())
    }
}
