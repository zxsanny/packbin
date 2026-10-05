use super::{Field, FieldKind};
use crate::value::Name;

pub(crate) fn take_id(next: &mut u32, id: u32) {
    if id != *next {
        panic!("field id {id} is not the next order {next}");
    }
    *next = next.saturating_add(1);
}

/// Walks `fields` in order. `scope` is the first id of the enclosing container: a
/// `when`, count or flag-bit reference must name an id in `scope..next`. A flag bit must
/// also follow its flag byte in the same container, outside any part that may not run.
pub(crate) fn check_order(fields: &[Field], next: u32, scope: u32) -> u32 {
    check_seq(fields, next, scope, &mut FlagBytes::new(true))
}

/// As `check_order`, for a piece of a larger scheme: the flag bytes read earlier are not
/// visible here, so flag bits are left to the check of the whole scheme.
pub(crate) fn check_order_part(fields: &[Field], next: u32, scope: u32) -> u32 {
    check_seq(fields, next, scope, &mut FlagBytes::new(false))
}

/// Flag bytes read so far in the current scope, outside any conditional part.
struct FlagBytes {
    names: Vec<Name>,
    enforce: bool,
}

impl FlagBytes {
    fn new(enforce: bool) -> Self {
        FlagBytes {
            names: Vec::new(),
            enforce,
        }
    }

    fn require(&self, flag: &str, bit: u8) {
        if self.enforce && !self.names.iter().any(|n| n.as_ref() == flag) {
            panic!(
                "flag bit {bit} of flag byte \"{flag}\" is not in the same scope as its flag byte"
            );
        }
    }

    /// Runs `run` over a part that may not run (`when`, flags member, flag-bit inner): flag
    /// bytes read inside it stay inside it.
    fn conditional(&mut self, run: impl FnOnce(&mut Self) -> u32) -> u32 {
        let mark = self.names.len();
        let end = run(self);
        self.names.truncate(mark);
        end
    }

    /// Runs `run` over a container with its own values (repeat, times, list, dict), which
    /// cannot see the flag bytes of the enclosing scope.
    fn nested(&mut self, run: impl FnOnce(&mut Self) -> u32) -> u32 {
        let outer = std::mem::take(&mut self.names);
        let end = run(self);
        self.names = outer;
        end
    }
}

fn check_seq(fields: &[Field], mut next: u32, scope: u32, flags: &mut FlagBytes) -> u32 {
    for field in fields {
        next = check_one(field, next, scope, flags);
    }
    next
}

pub(crate) fn nested_element(field: &Field) -> Option<&Field> {
    match &field.kind {
        FieldKind::List { element, .. } | FieldKind::Dict { element, .. } => Some(element),
        _ => None,
    }
}

fn parse_id(name: &str) -> Option<u32> {
    name.parse::<u32>().ok().filter(|id| id.to_string() == name)
}

fn take_value_slot(next: &mut u32, name: &str) {
    if let Some(id) = parse_id(name) {
        take_id(next, id);
    } else {
        *next = next.saturating_add(1);
    }
}

fn require_walked(next: u32, scope: u32, name: &str) {
    if let Some(id) = parse_id(name) {
        if id >= next {
            panic!("field id {id} is not yet walked at order {next}");
        }
    }
    require_in_scope(scope, name);
}

// A repeat or times round reads into its own values, so an outer id is never visible there.
fn require_in_scope(scope: u32, name: &str) {
    if let Some(id) = parse_id(name) {
        if id < scope {
            panic!("field id {id} is not in the same scope (the container starts at id {scope})");
        }
    }
}

fn check_anchor(next: u32, anchor: u32) {
    if anchor != next {
        panic!("field id {anchor} is not the next order {next}");
    }
}

fn check_one(field: &Field, mut next: u32, scope: u32, flags: &mut FlagBytes) -> u32 {
    match &field.kind {
        FieldKind::Int { name, .. }
        | FieldKind::Float { name, .. }
        | FieldKind::Bytes { name, .. }
        | FieldKind::Utf8 { name } => {
            take_value_slot(&mut next, name);
            next
        }
        FieldKind::FlagByte { name } => {
            flags.names.push(name.clone());
            take_value_slot(&mut next, name);
            next
        }
        FieldKind::Sized { name, count } | FieldKind::Bits { name, count } => {
            require_walked(next, scope, count);
            take_value_slot(&mut next, name);
            next
        }
        FieldKind::Packed { name, count, .. } => {
            require_walked(next, scope, count);
            take_value_slot(&mut next, name);
            next
        }
        FieldKind::U2 { names } => {
            for name in names {
                take_value_slot(&mut next, name);
            }
            next
        }
        FieldKind::Flags {
            anchor, members, ..
        } => {
            check_anchor(next, *anchor);
            flags.conditional(|f| check_seq(members, next, scope, f))
        }
        FieldKind::When {
            anchor,
            field,
            members,
            ..
        } => {
            check_anchor(next, *anchor);
            require_walked(next, scope, field);
            flags.conditional(|f| check_seq(members, next, scope, f))
        }
        FieldKind::Repeat { anchor, members } => {
            check_anchor(next, *anchor);
            flags.nested(|f| check_seq(members, next, *anchor, f))
        }
        FieldKind::Times {
            anchor,
            count,
            members,
        } => {
            check_anchor(next, *anchor);
            require_walked(next, scope, count);
            flags.nested(|f| check_seq(members, next, *anchor, f))
        }
        FieldKind::Group { anchor, name, members } => {
            check_anchor(next, *anchor);
            if members.is_empty() {
                take_value_slot(&mut next, name);
                next
            } else {
                check_seq(members, next, scope, flags)
            }
        }
        FieldKind::FlagBit { flag, bit, inner } => {
            require_in_scope(scope, flag);
            flags.require(flag, *bit);
            flags.conditional(|f| check_one(inner, next, scope, f))
        }
        FieldKind::List { element, .. } | FieldKind::Dict { element, .. } => {
            let _ = flags.nested(|f| check_one(element, 0, 0, f));
            next
        }
    }
}
