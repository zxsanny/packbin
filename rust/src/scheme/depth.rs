use super::SchemeItem;
use crate::field::{dismantle, levels, too_deep, u8, MAX_DEPTH};

/// The deepest nesting of `items` (see `field/depth.rs`), counted with an explicit stack; it stops
/// at the first level above the limit. A `when` or `flags` is a level, a `times` is a level plus the
/// depth of its elements (kept when it was built), a bound or raw field is its own field's depth.
pub(super) fn item_levels<T>(items: &[SchemeItem<T>]) -> usize {
    let mut stack = vec![items.iter()];
    let mut deepest = 0;
    while let Some(rest) = stack.last_mut() {
        let Some(item) = rest.next() else {
            stack.pop();
            continue;
        };
        let open = stack.len() - 1;
        let reached = match item {
            SchemeItem::When { members, .. } | SchemeItem::Flags { members, .. } => {
                stack.push(members.iter());
                open + 1
            }
            SchemeItem::Times(times) => open + 1 + times.depth,
            SchemeItem::Bound(bound) => levels(std::slice::from_ref(&bound.field), open),
            SchemeItem::Field(field) => levels(std::slice::from_ref(field), open),
        };
        deepest = deepest.max(reached);
        if deepest > MAX_DEPTH {
            return deepest;
        }
    }
    deepest
}

/// Refuses typed items nested deeper than the limit before they are compiled (that walk recurses).
/// The refused items are taken apart level by level first, as `field/depth.rs` does for fields.
pub(super) fn check_items<T>(items: Vec<SchemeItem<T>>) -> Vec<SchemeItem<T>> {
    if item_levels(&items) > MAX_DEPTH {
        dismantle_items(items);
        too_deep();
    }
    items
}

fn dismantle_items<T>(items: Vec<SchemeItem<T>>) {
    let mut pending = vec![items];
    while let Some(mut list) = pending.pop() {
        for item in list.iter_mut() {
            match item {
                SchemeItem::When { members, .. } | SchemeItem::Flags { members, .. } => {
                    pending.push(std::mem::take(members));
                }
                SchemeItem::Bound(bound) => {
                    dismantle(vec![std::mem::replace(&mut bound.field, u8(""))])
                }
                SchemeItem::Field(field) => dismantle(vec![std::mem::replace(field, u8(""))]),
                SchemeItem::Times(_) => {}
            }
        }
    }
}
