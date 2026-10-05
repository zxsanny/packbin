use super::{field_name, Field, FieldKind};
use crate::value::Name;

/// Bits in one flags byte or flag byte: bit 0 is the first member or bit.
const FLAG_BITS: usize = 8;

/// Checks the shape rules of a whole scheme and binds its split flag bits. Returns the number
/// of flag bytes the scheme reads.
///
/// - A bool (an empty `group`) is a presence bit with no payload, so it is allowed only as a
///   direct child of `flags` or of a flag bit.
/// - `flags` holds at most 8 members and a flag byte at most 8 bits.
/// - A flag bit belongs to the latest read of its flag byte that it can see: one read earlier
///   in the same scope (the top level, or one `repeat` / `times` round or `list` / `dict`
///   element), outside any part that may not run (`when`, a `flags` member, a flag bit). Its
///   position is its order among the bits of that read.
/// - No `repeat` inside a `repeat` or `times` round, and no `times` inside a `times` round, at
///   any depth: unpack keeps no inner `repeat` rounds, and a `times` round passes no values to
///   an inner `times`. A `times` inside a `repeat` round works. A `list` or `dict` element
///   starts outside any round.
pub(crate) fn check_shape(fields: &mut [Field]) -> usize {
    let mut scope = Scope::default();
    shape_seq(fields, false, &mut scope);
    scope.bits.len()
}

#[derive(Clone, Copy, Default, PartialEq)]
enum Round {
    #[default]
    None,
    Repeat,
    Times,
}

/// What the shape pass knows at one point of the scheme.
#[derive(Default)]
struct Scope {
    /// Flag bytes this point can see: name and slot, latest last.
    visible: Vec<(Name, usize)>,
    /// Bits bound so far to each flag byte read, by slot (one slot per read in the scheme).
    bits: Vec<u8>,
    /// The innermost `repeat` or `times` round around this point.
    round: Round,
}

impl Scope {
    fn read(&mut self, name: &Name) -> usize {
        let slot = self.bits.len();
        self.bits.push(0);
        self.visible.push((name.clone(), slot));
        slot
    }

    /// Slot and position of the next bit of `flag`.
    fn bind(&mut self, flag: &str, inner: &Field) -> (usize, u8) {
        let Some(&(_, slot)) = self.visible.iter().rev().find(|(n, _)| n.as_ref() == flag) else {
            panic!(
                "flag bit {} of flag byte \"{flag}\" is not in the same scope as its flag byte",
                label(inner)
            );
        };
        let taken = self.bits[slot];
        if usize::from(taken) >= FLAG_BITS {
            panic!(
                "flag byte \"{flag}\" has more than 8 bits; the 9th is field {}",
                label(inner)
            );
        }
        self.bits[slot] = taken + 1;
        (slot, taken)
    }

    /// A part that may not run: flag bytes read inside it are not seen after it.
    fn conditional(&mut self, run: impl FnOnce(&mut Self)) {
        let mark = self.visible.len();
        run(self);
        self.visible.truncate(mark);
    }

    /// A container with its own values, which sees none of the flag bytes around it: a round
    /// or a `list` / `dict` element (`Round::None`).
    fn nested(&mut self, round: Round, run: impl FnOnce(&mut Self)) {
        let outer = std::mem::take(&mut self.visible);
        let outer_round = std::mem::replace(&mut self.round, round);
        run(self);
        self.visible = outer;
        self.round = outer_round;
    }

    fn enter_repeat(&mut self, anchor: u32, run: impl FnOnce(&mut Self)) {
        if self.round != Round::None {
            panic!(
                "repeat at id {anchor} is inside a repeat or times round; a round keeps no inner \
                 repeat rounds"
            );
        }
        self.nested(Round::Repeat, run);
    }

    fn enter_times(&mut self, anchor: u32, run: impl FnOnce(&mut Self)) {
        if self.round == Round::Times {
            panic!(
                "times at id {anchor} is inside a times round; a times round passes no values to \
                 an inner times"
            );
        }
        self.nested(Round::Times, run);
    }
}

/// `presence_ok`: the fields are direct children of `flags` or of a flag bit.
fn shape_seq(fields: &mut [Field], presence_ok: bool, flags: &mut Scope) {
    for field in fields {
        shape_one(field, presence_ok, flags);
    }
}

fn shape_one(field: &mut Field, presence_ok: bool, flags: &mut Scope) {
    match &mut field.kind {
        FieldKind::Group {
            anchor, members, ..
        } if members.is_empty() => {
            if !presence_ok {
                panic!(
                    "field id {anchor}: a bool or empty group is allowed only directly inside \
                     flags or under a flag bit"
                );
            }
        }
        FieldKind::Flags {
            anchor, members, ..
        } => {
            if let Some(ninth) = members.get(FLAG_BITS) {
                panic!(
                    "flags at id {anchor} has more than 8 members; the 9th is field {}",
                    label(ninth)
                );
            }
            flags.conditional(|f| shape_seq(members, true, f));
        }
        FieldKind::FlagByte { name, slot } => *slot = flags.read(name),
        FieldKind::FlagBit {
            flag,
            slot,
            bit,
            inner,
        } => {
            (*slot, *bit) = flags.bind(flag, inner);
            flags.conditional(|f| shape_one(inner, true, f));
        }
        FieldKind::Group { members, .. } => shape_seq(members, false, flags),
        FieldKind::When { members, .. } => {
            flags.conditional(|f| shape_seq(members, false, f));
        }
        FieldKind::Repeat { anchor, members } => {
            flags.enter_repeat(*anchor, |f| shape_seq(members, false, f));
        }
        FieldKind::Times {
            anchor, members, ..
        } => {
            flags.enter_times(*anchor, |f| shape_seq(members, false, f));
        }
        FieldKind::List { element, .. } | FieldKind::Dict { element, .. } => {
            flags.nested(Round::None, |f| shape_one(element, false, f));
        }
        FieldKind::Int { .. }
        | FieldKind::Float { .. }
        | FieldKind::Bytes { .. }
        | FieldKind::Sized { .. }
        | FieldKind::U2 { .. }
        | FieldKind::Bits { .. }
        | FieldKind::Packed { .. }
        | FieldKind::Utf8 { .. } => {}
    }
}

pub(super) fn label(field: &Field) -> String {
    if let Some(name) = field_name(field) {
        return format!("\"{name}\"");
    }
    match &field.kind {
        FieldKind::When { anchor, .. }
        | FieldKind::Repeat { anchor, .. }
        | FieldKind::Times { anchor, .. } => format!("at id {anchor}"),
        _ => "with no name".to_string(),
    }
}
