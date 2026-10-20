//! Strings and dictionaries in the two walks: `Utf8Wire` (the payload as it is), and with the
//! `text` feature `Utf8` (decoded text, the codec) and the key order of a `Dict`.

use super::count::{get_count, put_field, MAX_COUNT};
use super::error::Fault;
use super::pack::Pack;
use super::scheme::Field;
use super::table::id_of;
use super::unpack::Unpack;

impl Pack<'_, '_, '_> {
    /// A string kept as it is: the count of the row's bytes, then the bytes, never decoded or
    /// checked.
    pub(crate) fn utf8_wire(&mut self, f: &Field) -> Result<(), Fault> {
        let at = self.w.len();
        let value = self
            .row
            .bytes(f.id)
            .ok_or_else(|| Fault::bad(at, id_of(f)))?;
        if value.len() > MAX_COUNT {
            return Err(Fault::bad(at, id_of(f)));
        }
        let payload = put_field(self.w, value.len(), id_of(f))?;
        for (slot, byte) in payload.iter_mut().zip(value) {
            *slot = *byte;
        }
        Ok(())
    }
}

impl Unpack<'_, '_, '_> {
    /// A string kept as it is: the row takes the payload after the count.
    pub(crate) fn utf8_wire(&mut self, f: &Field) -> Result<(), Fault> {
        let at = self.r.pos();
        let len = get_count(self.r, id_of(f))?;
        let payload = self.r.take(len, id_of(f))?;
        self.row
            .set_bytes(f.id, payload)
            .then_some(())
            .ok_or_else(|| Fault::bad(at, id_of(f)))
    }
}

#[cfg(feature = "text")]
mod text_walk {
    use super::super::count::get_count;
    use super::super::error::{Error, Fault};
    use super::super::pack::Pack;
    use super::super::scheme::Field;
    use super::super::table::id_of;
    use super::super::text::{compare_payloads, decode_payload, encode_field, Sink};
    use super::super::unpack::Unpack;
    use super::super::DICT_KEY;
    use core::cmp::Ordering;

    impl Pack<'_, '_, '_> {
        /// A string: the compact form of the row's UTF-8 text.
        pub(crate) fn utf8(&mut self, f: &Field) -> Result<(), Fault> {
            let value = self
                .row
                .bytes(f.id)
                .ok_or_else(|| Fault::bad(self.w.len(), id_of(f)))?;
            encode_field(self.w, self.scratch, id_of(f), value)
        }

        /// True when the first `n` items of the `dict` `f` have keys in strictly ascending byte
        /// order.
        pub(crate) fn keys_ascending(&self, f: &Field, n: usize) -> bool {
            let key = |k: usize| self.row.item(f.id, k)?.bytes(DICT_KEY);
            (1..n).all(|k| match (key(k.saturating_sub(1)), key(k)) {
                (Some(a), Some(b)) => a < b,
                _ => false,
            })
        }
    }

    impl Unpack<'_, '_, '_> {
        /// A string into the row's storage, decoded.
        pub(crate) fn utf8(&mut self, f: &Field) -> Result<(), Fault> {
            let at = self.r.pos();
            let len = get_count(self.r, id_of(f))?;
            let body = self.r.pos();
            let payload = self.r.take(len, id_of(f))?;
            if payload.is_empty() {
                // An empty text: the row's storage is asked for, so the member reads as empty.
                self.row.slots(f.id);
                return self.set_len(f, at, 0);
            }
            let slots = self
                .row
                .slots(f.id)
                .ok_or_else(|| Fault::bad(at, id_of(f)))?;
            let mut sink = Sink::new(slots);
            let ok = decode_payload(payload, &mut sink);
            let (len, over) = (sink.len, sink.over);
            if !ok || over {
                // The member reads as empty, as after a clear.
                self.row.set_count(f.id, 0);
                return Err(if ok {
                    Fault::new(Error::TooMany, body, id_of(f), len)
                } else {
                    Fault::bad(at, id_of(f))
                });
            }
            self.set_len(f, at, len)
        }

        fn set_len(&mut self, f: &Field, at: usize, len: usize) -> Result<(), Fault> {
            self.row
                .set_count(f.id, len)
                .then_some(())
                .ok_or_else(|| Fault::bad(at, id_of(f)))
        }

        /// A dictionary key must sort after the key before it by its decoded UTF-8 bytes: an
        /// equal key repeats it, a smaller one is out of order. Both are `BadValue` at the
        /// entry's offset. The keys are compared from their payloads in the input, with no
        /// storage for the earlier one.
        pub(crate) fn check_key_order(&self, f: &Field, prev: usize, at: usize) -> Result<(), Fault> {
            let payload = |from: usize| {
                let mut r = self.r.at(from);
                let n = get_count(&mut r, id_of(f)).ok()?;
                r.take(n, id_of(f)).ok()
            };
            match (payload(prev), payload(at)) {
                (Some(a), Some(b)) if compare_payloads(a, b) == Ordering::Less => Ok(()),
                _ => Err(Fault::bad(at, id_of(f))),
            }
        }
    }
}
