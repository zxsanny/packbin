//! Pack and unpack a caller-owned field list.
//!
//! Two APIs share one wire format. The `std` API (`MapScheme`, `Values`, [`pack`], [`unpack`],
//! [`PackSession`]) builds schemes at run time and owns its values; it is on by default. The
//! [`nostd`] API is plain data and caller buffers: it builds with `#![no_std]` and no allocator
//! (`default-features = false`) for firmware. Cargo features: `std` (default, implies `alloc`),
//! `alloc` (convenience wrappers that return `Vec<u8>`), `text`, `ecc` and `session` (parts of
//! the [`nostd`] API; the `std` API always has all three).
#![cfg_attr(not(feature = "std"), no_std)]

#[cfg(feature = "alloc")]
extern crate alloc;

pub mod nostd;

#[cfg(feature = "std")]
mod ecc;
#[cfg(any(feature = "std", feature = "ecc"))]
mod ecc_core;
#[cfg(feature = "std")]
mod field;
#[cfg(feature = "std")]
mod scheme;
#[cfg(feature = "std")]
mod session;
#[cfg(feature = "std")]
mod value;
#[cfg(feature = "std")]
mod walk;

#[cfg(feature = "std")]
pub use ecc::MAX_PARITY;
#[cfg(feature = "std")]
pub use field::{
    be, bits, bytes, dict, eq, f32, f64, flag_byte, flags, group, i16, i32, i64, i8, id_name, list,
    packed, repeat, sized, times, u16, u2, u32, u64, u8, utf8, when, Eq, Field, FieldKey, FlagByte,
    MapScheme, DEFAULT_MAX_BYTES, DEFAULT_MAX_ROUNDS, DEFAULT_MAX_SLOTS,
};
#[cfg(feature = "std")]
pub use scheme::{BinaryPacker, BoundField, DispatchHandler, On, Scheme, SchemeItem};
#[cfg(feature = "std")]
pub use session::{PackSession, SessionPackError, NONCE_SIZE, SEED_SIZE};
#[cfg(feature = "std")]
pub use value::{
    insert, mismatched_bytes, motion_field_count, to_hex, Name, PackError, ShortPacket,
    UnpackError, Value, Values,
};
#[cfg(feature = "std")]
pub use walk::{pack, unpack, unpack_repair};

#[cfg(all(test, feature = "std"))]
mod borrowed_count_tests;
#[cfg(all(test, feature = "std"))]
mod counted_tests;
#[cfg(all(test, feature = "std"))]
mod dict_order_tests;
#[cfg(all(test, feature = "std"))]
mod duplicate_names_kept_tests;
#[cfg(all(test, feature = "std"))]
mod duplicate_names_tests;
#[cfg(all(test, feature = "std"))]
mod ecc_repair_tests;
#[cfg(all(test, feature = "std"))]
mod ecc_reverify_tests;
#[cfg(all(test, feature = "std"))]
mod ecc_vectors_tests;
#[cfg(all(test, feature = "std"))]
mod element_tests;
#[cfg(all(test, feature = "std"))]
mod eq_bool_true_tests;
#[cfg(all(test, feature = "std"))]
mod eq_range_tests;
#[cfg(all(test, feature = "std"))]
mod flag_bits_tests;
#[cfg(all(test, feature = "std"))]
mod flag_group_tests;
#[cfg(all(test, feature = "std"))]
mod flag_presence_tests;
#[cfg(all(test, feature = "std"))]
mod flags_member_scope_tests;
#[cfg(all(test, feature = "std"))]
mod flags_round_member_tests;
#[cfg(all(test, feature = "std"))]
mod flags_when_member_tests;
#[cfg(all(test, feature = "std"))]
mod flags_zero_rounds_tests;
#[cfg(all(test, feature = "std"))]
mod hostile_tests;
#[cfg(all(test, feature = "std"))]
mod integrity_tests;
#[cfg(all(test, feature = "std"))]
mod lone_bytes_in_round_tests;
#[cfg(all(test, feature = "std"))]
mod loop20_parity_pins_tests;
#[cfg(all(test, feature = "std"))]
mod name_scope_tests;
#[cfg(all(test, feature = "std"))]
mod pack_output_budget_tests;
#[cfg(all(test, feature = "std"))]
mod pack_repeat_cap_tests;
#[cfg(all(test, feature = "std"))]
mod pack_round_cap_tests;
#[cfg(all(test, feature = "std"))]
mod packbin_tests;
#[cfg(all(test, feature = "std"))]
mod repeat_lists_without_groups_tests;
#[cfg(all(test, feature = "std"))]
mod round_tests;
#[cfg(all(test, feature = "std"))]
mod scope_tests;
#[cfg(all(test, feature = "std"))]
mod session_hostile_tests;
#[cfg(all(test, feature = "std"))]
mod split_form_loud_tests;
#[cfg(all(test, feature = "std"))]
mod text_concurrency_tests;
#[cfg(all(test, feature = "std"))]
mod text_positions_tests;
#[cfg(all(test, feature = "std"))]
mod text_repeat_tests;
#[cfg(all(test, feature = "std"))]
mod text_vectors_tests;
#[cfg(all(test, feature = "std"))]
mod times_count_zero_tests;
#[cfg(all(test, feature = "std"))]
mod times_lone_value_tests;
#[cfg(all(test, feature = "std"))]
mod times_longer_tests;
#[cfg(all(test, feature = "std"))]
mod times_stale_tests;
#[cfg(all(test, feature = "std"))]
mod times_tests;
#[cfg(all(test, feature = "std"))]
mod when_kept_tests;
#[cfg(all(test, feature = "std"))]
mod when_names_tests;
#[cfg(all(test, feature = "std"))]
mod timing_support;
#[cfg(all(test, feature = "std"))]
mod when_written_tests;
