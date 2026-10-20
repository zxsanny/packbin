//! The unpack walk over a checked table (the C++ `unpack.cpp` port). Counts and `when`s read the
//! values this walk has already stored in the row.

use super::error::{Error, Fault};
use super::io::Reader;
use super::pack::Budget;
use super::present::{clear, source_value, when_matches};
use super::row::{Num, Row};
use super::scheme::{Field, Kind};
use super::table::{
    bit_position, end, flag_byte_of, get, id_of, level, members, round_width, slot_of,
};

/// Flag byte numbers are 0 to 7.
const FLAG_BYTES: usize = 8;

pub(crate) struct Unpack<'t, 'r, 'b> {
    pub t: &'t [Field],
    pub r: &'r mut Reader<'b>,
    pub row: &'r mut dyn Row,
    /// The last value read for each flag byte number in the scope being read (a round starts
    /// with none, and the scope around it gets its own back when the container ends).
    pub flag_bytes: [u8; FLAG_BYTES],
    pub budget: &'r mut Budget,
}

fn bad(at: usize, f: &Field) -> Fault {
    Fault::new(Error::BadValue, at, id_of(f), 0)
}

/// A count read from a packet as a length: one that does not fit `usize` fails the ordinary
/// short-packet or capacity checks.
fn clamp(count: u64) -> usize {
    usize::try_from(count).unwrap_or(usize::MAX)
}

impl Unpack<'_, '_, '_> {
    pub(crate) fn top(&mut self) -> Result<(), Fault> {
        for j in level(self.t, 0, self.t.len()) {
            self.one(j)?;
        }
        Ok(())
    }

    fn field(&self, i: usize) -> Result<Field, Fault> {
        get(self.t, i)
            .copied()
            .ok_or_else(|| Fault::new(Error::SchemeInvalid, self.r.pos(), -1, 0))
    }

    /// Reads entry `i` (or its members), then brings back the flag bytes of the scope around
    /// it, so a flag byte read inside a part that may not run is not seen after it.
    fn scoped(&mut self, i: usize, whole: bool) -> Result<(), Fault> {
        let outer = self.flag_bytes;
        let result = if whole {
            self.one(i)
        } else {
            members(self.t, i).try_for_each(|j| self.one(j))
        };
        self.flag_bytes = outer;
        result
    }

    fn one(&mut self, i: usize) -> Result<(), Fault> {
        let f = self.field(i)?;
        if let Some(width) = f.kind.width() {
            return self.number(&f, width);
        }
        match f.kind {
            Kind::Bool => {
                let at = self.r.pos();
                self.row
                    .set_flag(f.id, true)
                    .then_some(())
                    .ok_or_else(|| bad(at, &f))
            }
            Kind::Bytes => {
                let at = self.r.pos();
                let value = self.r.take(usize::from(f.size), id_of(&f))?;
                self.row
                    .set_bytes(f.id, value)
                    .then_some(())
                    .ok_or_else(|| bad(at, &f))
            }
            Kind::Sized => self.sized(i, &f),
            Kind::When if when_matches(self.t, i, &*self.row) => self.scoped(i, false),
            Kind::When => Ok(()),
            Kind::Flags => self.flags(i, &f),
            Kind::FlagByte => {
                let byte = *self.r.take(1, id_of(&f))?.first().unwrap_or(&0);
                if let Some(slot) = self.flag_bytes.get_mut(usize::from(f.size)) {
                    *slot = byte;
                }
                Ok(())
            }
            Kind::FlagBit => {
                let byte = self
                    .flag_bytes
                    .get(usize::from(f.size))
                    .copied()
                    .unwrap_or(0);
                let position = flag_byte_of(self.t, i).map_or(0, |b| bit_position(self.t, b, i));
                let mask = 1u8.checked_shl(position as u32).unwrap_or(0);
                if byte & mask != 0 {
                    self.scoped(i.saturating_add(1), true)
                } else {
                    Ok(())
                }
            }
            Kind::U2 => self.u2(i, &f),
            Kind::Bits | Kind::Packed => self.small(i, &f),
            Kind::Group => members(self.t, i).try_for_each(|j| self.one(j)),
            Kind::Repeat | Kind::Times | Kind::List => self.container(i, &f),
            _ => Err(Fault::new(Error::SchemeInvalid, self.r.pos(), id_of(&f), 0)),
        }
    }

    /// Items of a `repeat` (until the packet ends), a `times` (its count as read) or a `list` (a
    /// u16 count), each read into the row's next item. A `repeat` round that reads nothing ends
    /// it (the bytes left are trailing); a `list` element that reads nothing is `BadValue`.
    fn container(&mut self, i: usize, f: &Field) -> Result<(), Fault> {
        let n = match f.kind {
            Kind::Times => source_value(self.t, i, &*self.row)
                .and_then(|c| u64::try_from(c).ok())
                .map(clamp)
                .ok_or_else(|| bad(self.r.pos(), f))?,
            Kind::List => {
                let wire = self.r.take(2, id_of(f))?;
                let lo = wire.first().copied().unwrap_or(0);
                let hi = wire.get(1).copied().unwrap_or(0);
                usize::from(u16::from_le_bytes([lo, hi]))
            }
            _ => usize::MAX,
        };
        let to_end = f.kind == Kind::Repeat;
        let rounds = f.kind != Kind::List;
        let width = round_width(self.t, i.saturating_add(1), end(self.t, i));
        let mut filled = 0usize;
        while if to_end {
            self.r.has_more()
        } else {
            filled < n
        } {
            let at = self.r.pos();
            if rounds {
                self.budget.start_round(f, at, filled, width)?;
            }
            let wanted = if to_end { filled.saturating_add(1) } else { n };
            let item = self.row.item_mut(f.id, filled).ok_or(Fault::new(
                Error::TooMany,
                at,
                id_of(f),
                wanted,
            ))?;
            clear(self.t, i.saturating_add(1), end(self.t, i), item);
            Unpack {
                t: self.t,
                r: &mut *self.r,
                row: item,
                flag_bytes: [0; FLAG_BYTES],
                budget: &mut *self.budget,
            }
            .top_of(i)?;
            if self.r.pos() == at {
                if to_end {
                    break;
                }
                if !rounds {
                    return Err(bad(at, f));
                }
            }
            filled = filled.saturating_add(1);
        }
        let done = self.r.pos();
        self.row
            .set_count(f.id, filled)
            .then_some(())
            .ok_or_else(|| bad(done, f))
    }

    /// The members of entry `i`, into this walk's row.
    fn top_of(&mut self, i: usize) -> Result<(), Fault> {
        members(self.t, i).try_for_each(|j| self.one(j))
    }

    fn number(&mut self, f: &Field, width: usize) -> Result<(), Fault> {
        let at = self.r.pos();
        let wire = self.r.take(width, id_of(f))?;
        let mut bits: u64 = 0;
        if f.big_endian {
            for byte in wire {
                bits = (bits << 8) | u64::from(*byte);
            }
        } else {
            for byte in wire.iter().rev() {
                bits = (bits << 8) | u64::from(*byte);
            }
        }
        let num = Num::from_bits(f.kind, bits).ok_or_else(|| bad(at, f))?;
        self.row
            .set_num(f.id, num)
            .then_some(())
            .ok_or_else(|| bad(at, f))
    }

    /// Bytes whose length is the value of the count as read.
    fn sized(&mut self, i: usize, f: &Field) -> Result<(), Fault> {
        let count = source_value(self.t, i, &*self.row)
            .and_then(|n| u64::try_from(n).ok())
            .ok_or_else(|| bad(self.r.pos(), f))?;
        let body = self.r.pos();
        let value = self.r.take(clamp(count), id_of(f))?;
        self.store(f, body, value.len(), |slots| {
            for (slot, byte) in slots.iter_mut().zip(value) {
                *slot = *byte;
            }
        })
    }

    /// Fills the row's storage of `f` with `n` values; storage shorter than `n` is `TooMany`
    /// with nothing written.
    fn store(
        &mut self,
        f: &Field,
        at: usize,
        n: usize,
        fill: impl FnOnce(&mut [u8]),
    ) -> Result<(), Fault> {
        let slots = self.row.slots(f.id).ok_or_else(|| bad(at, f))?;
        let room = slots
            .get_mut(..n)
            .ok_or(Fault::new(Error::TooMany, at, id_of(f), n))?;
        fill(room);
        self.row
            .set_count(f.id, n)
            .then_some(())
            .ok_or_else(|| bad(at, f))
    }

    fn flags(&mut self, i: usize, f: &Field) -> Result<(), Fault> {
        let byte = *self.r.take(1, id_of(f))?.first().unwrap_or(&0);
        for (k, j) in members(self.t, i).enumerate() {
            if byte & 1u8.checked_shl(k as u32).unwrap_or(0) != 0 {
                self.scoped(j, true)?;
            }
        }
        Ok(())
    }

    fn u2(&mut self, i: usize, f: &Field) -> Result<(), Fault> {
        let k = usize::from(f.span).saturating_sub(1);
        let wire = self.r.take(k.div_ceil(4), id_of(f))?;
        for (c, j) in members(self.t, i).enumerate() {
            let child = self.field(j)?;
            let (at, shift) = slot_of(c, 2);
            let value = wire
                .get(at)
                .copied()
                .unwrap_or(0)
                .checked_shr(shift)
                .unwrap_or(0)
                & 3;
            if !self.row.set_num(child.id, Num::U8(value)) {
                return Err(bad(self.r.pos(), &child));
            }
        }
        Ok(())
    }

    /// `bits` (width 1) or `packed` numbers (width 1 or 2) into the row's storage.
    fn small(&mut self, i: usize, f: &Field) -> Result<(), Fault> {
        let mut count = source_value(self.t, i, &*self.row).ok_or_else(|| bad(self.r.pos(), f))?;
        let width: u64 = if f.kind == Kind::Bits {
            1
        } else {
            u64::from(f.width)
        };
        if f.kind == Kind::Packed {
            count = count.saturating_add(i64::from(f.bias));
        }
        let count = u64::try_from(count).map_err(|_| bad(self.r.pos(), f))?;
        let at = self.r.pos();
        // count <= i64::MAX and width <= 2, so the bit count fits in 64 bits.
        let nbits = count.saturating_mul(width);
        let wire = self.r.take(clamp(nbits.div_ceil(8)), id_of(f))?;
        let mask = if width == 2 { 3 } else { 1 };
        self.store(f, at, clamp(count), |slots| {
            for (k, slot) in slots.iter_mut().enumerate() {
                let (byte, shift) = slot_of(k, width);
                let value = wire.get(byte).copied().unwrap_or(0);
                *slot = value.checked_shr(shift).unwrap_or(0) & mask;
            }
        })
    }
}
