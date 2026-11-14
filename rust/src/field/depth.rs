use super::{Field, FieldKind};
use std::slice::from_ref;

/// The most levels a scheme may nest (`_docs/02_document/contracts/library/scheme-depth.md`).
pub(crate) const MAX_DEPTH: usize = 256;

/// Panics with the refusal of a scheme nested deeper than [`MAX_DEPTH`].
pub(crate) fn too_deep() -> ! {
    panic!("scheme nested too deep: more than {MAX_DEPTH} levels; the limit is {MAX_DEPTH}")
}

/// What one field adds to the nesting: its direct children and whether it is a level itself. A
/// `when`, `flags`, non-empty group, `repeat`, `times`, `list` and `dict` are a level (a list's
/// element row is its own child, so `list(group)` is two); a flag bit adds none, and an empty group
/// is a bool, not a container.
fn children(field: &Field) -> (&[Field], bool) {
    match &field.kind {
        FieldKind::When { members, .. }
        | FieldKind::Flags { members, .. }
        | FieldKind::Repeat { members, .. }
        | FieldKind::Times { members, .. } => (members, true),
        FieldKind::Group { members, .. } => (members, !members.is_empty()),
        FieldKind::FlagBit { inner, .. } => (from_ref(&**inner), false),
        FieldKind::List { element, .. } | FieldKind::Dict { element, .. } => {
            (from_ref(&**element), true)
        }
        _ => (&[], false),
    }
}

/// The deepest nesting of `fields` when `open` levels are already open around them, counted with an
/// explicit stack. It stops at the first level above [`MAX_DEPTH`] and returns that number.
pub(crate) fn levels(fields: &[Field], open: usize) -> usize {
    let mut stack = vec![(fields.iter(), false)];
    let (mut depth, mut deepest) = (open, open);
    while let Some((rest, _)) = stack.last_mut() {
        let Some(field) = rest.next() else {
            if let Some((_, counted)) = stack.pop() {
                depth -= usize::from(counted);
            }
            continue;
        };
        let (inner, counted) = children(field);
        depth += usize::from(counted);
        deepest = deepest.max(depth);
        if deepest > MAX_DEPTH {
            return deepest;
        }
        if inner.is_empty() {
            depth -= usize::from(counted);
        } else {
            stack.push((inner.iter(), counted));
        }
    }
    deepest
}

/// Refuses a scheme nested deeper than [`MAX_DEPTH`] before any walk that recurses over it. The
/// refused fields are taken apart first, level by level: dropping a chain of tens of thousands
/// of nested fields would recurse once per level and overflow the stack while the panic unwinds.
pub(crate) fn check_depth(fields: Vec<Field>) -> Vec<Field> {
    if levels(&fields, 0) > MAX_DEPTH {
        dismantle(fields);
        too_deep();
    }
    fields
}

/// Drops `fields` with a stack of their member lists instead of one frame per level.
pub(crate) fn dismantle(fields: Vec<Field>) {
    let mut pending = vec![fields];
    while let Some(mut list) = pending.pop() {
        for field in list.iter_mut() {
            match &mut field.kind {
                FieldKind::When { members, .. }
                | FieldKind::Flags { members, .. }
                | FieldKind::Repeat { members, .. }
                | FieldKind::Times { members, .. }
                | FieldKind::Group { members, .. } => pending.push(std::mem::take(members)),
                FieldKind::FlagBit { inner, .. } => pending.push(vec![take(inner)]),
                FieldKind::List { element, .. } | FieldKind::Dict { element, .. } => {
                    pending.push(vec![take(element)]);
                }
                _ => {}
            }
        }
    }
}

/// The field behind a box, leaving a leaf in its place.
fn take(slot: &mut Field) -> Field {
    std::mem::replace(slot, super::u8(""))
}
