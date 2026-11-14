//! The four shared scheme-depth cases (`construct_depth_*`, `pack_depth_*`; AZ-4302), written as
//! loops, innermost first, so no builder here recurses.

use crate::walk::pack;
use crate::{eq, group, insert, u8, when, Field, MapScheme, PackError, Value, Values};

/// `u8 "0"`, then `depth` `when("0" == 1)` inside each other, the innermost holding `u8 "1"`.
pub(super) fn when_scheme(depth: usize) -> MapScheme {
    let mut inner = vec![u8("1")];
    for _ in 0..depth {
        inner = vec![when(1, eq("0", Value::U8(1)), inner)];
    }
    let mut fields: Vec<Field> = vec![u8("0")];
    fields.extend(inner);
    MapScheme::new(1, fields)
}

/// `depth` anchored groups inside each other, the innermost holding `u8 "b"`.
pub(super) fn group_scheme(depth: usize) -> MapScheme {
    let mut inner = vec![u8("b")];
    for level in (0..depth).rev() {
        inner = vec![group(0, format!("g{level}"), inner)];
    }
    MapScheme::new(1, inner)
}

fn packed(scheme: MapScheme, pairs: &[(&str, u8)]) -> Result<Vec<u8>, PackError> {
    let mut values = Values::new();
    for (name, value) in pairs {
        insert(&mut values, name, Some(Value::U8(*value)));
    }
    pack(&scheme, &values)
}

/// `pack_depth_when_256`: `{a: 1, b: 7}` packs `010107`.
pub(super) fn pack_when_256() -> Result<Vec<u8>, PackError> {
    packed(when_scheme(256), &[("0", 1), ("1", 7)])
}

/// `pack_depth_group_256`: `{b: 7}` packs `0107`.
pub(super) fn pack_group_256() -> Result<Vec<u8>, PackError> {
    packed(group_scheme(256), &[("b", 7)])
}

/// True when a 256-level pack and unpack fit the stack of the thread that runs the test: always in
/// a release build; in a debug build the frames of `pack_one` and `unpack_one` are about 11 KiB per
/// level and 256 levels need about 3 MiB, so a 2 MiB test thread overflows above about 145 levels
/// unless `RUST_MIN_STACK` raises the stack of the test threads to 8 MiB or more.
pub(crate) fn walk_fits_stack() -> bool {
    const NEEDED: usize = 8 << 20;
    !cfg!(debug_assertions)
        || std::env::var("RUST_MIN_STACK")
            .ok()
            .and_then(|bytes| bytes.parse::<usize>().ok())
            .is_some_and(|bytes| bytes >= NEEDED)
}

/// Why the loader does not run a pack case here, or `None` when it does.
pub(super) fn stack_skip(id: &str) -> Option<&'static str> {
    let deep = matches!(id, "pack_depth_when_256" | "pack_depth_group_256");
    (deep && !walk_fits_stack()).then_some(
        "a debug build overflows the 2 MiB test thread above about 145 levels (pack_one frame); \
         runs in a release build or with RUST_MIN_STACK of 8 MiB or more",
    )
}
