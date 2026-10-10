use crate::value::{as_usize, Name, PackError, Value};
use std::borrow::Cow;
use std::collections::HashMap;

/// What pack has written in one scope (the top level, a round of a `repeat` or `times`, a list or
/// dict element), by name, as unpack holds what it has read: each value, each `u2` slot, a flags
/// byte and a flag byte under their own name, and a set bool as `1`. A `when` and a count read
/// it, so one that names a field pack skipped finds nothing, as on unpack. It also holds the bits
/// of each flag byte pack wrote, by slot, for the flag bits that follow it.
pub(super) struct Written<'v> {
    /// False for a list or dict element: it cannot hold a `when` or a count (`check_element`), so
    /// nothing would read what it wrote.
    kept: bool,
    pub(super) items: Vec<(Name, Cow<'v, Value>)>,
    flag_bytes: HashMap<usize, u8>,
}

impl<'v> Written<'v> {
    pub(super) fn new() -> Self {
        // Most scopes write a handful of fields: one allocation, not a growth from 4 to 8.
        Written {
            kept: true,
            items: Vec::with_capacity(8),
            flag_bytes: HashMap::new(),
        }
    }

    pub(super) fn unread() -> Self {
        Written {
            kept: false,
            items: Vec::new(),
            flag_bytes: HashMap::new(),
        }
    }

    pub(super) fn insert(&mut self, name: &Name, value: Cow<'v, Value>) {
        if self.kept {
            self.items.push((name.clone(), value));
        }
    }

    /// The latest value written under `name`, as a later read replaces an earlier one.
    pub(super) fn get(&self, name: &str) -> Option<&Value> {
        self.items
            .iter()
            .rev()
            .find(|(own, _)| own.as_ref() == name)
            .map(|(_, value)| &**value)
    }

    pub(super) fn set_flag_byte(&mut self, slot: usize, bits: u8) {
        self.flag_bytes.insert(slot, bits);
    }

    pub(super) fn flag_byte(&self, slot: usize) -> u8 {
        self.flag_bytes.get(&slot).copied().unwrap_or(0)
    }
}

pub(super) fn written<'a>(wrote: &'a Written<'_>, name: &str) -> Result<&'a Value, PackError> {
    wrote
        .get(name)
        .ok_or_else(|| PackError::Missing(name.to_string()))
}

pub(super) fn borrowed_count(
    wrote: &Written<'_>,
    count: &str,
    bias: i8,
    label: &str,
) -> Result<usize, PackError> {
    let raw = as_usize(written(wrote, count)?).ok_or_else(|| PackError::Type(count.to_string()))?;
    let item_count = i64::try_from(raw)
        .ok()
        .and_then(|n| n.checked_add(i64::from(bias)));
    match item_count {
        Some(n) if n >= 0 => Ok(n as usize),
        Some(n) => Err(PackError::Type(format!("{label}: item count {n}"))),
        None => Err(PackError::Type(format!("{label}: item count out of range"))),
    }
}
