//! The heap-free API: plain-data schemes, caller buffers, errors as values.
//!
//! It builds with `#![no_std]` and no allocator (`default-features = false`). A scheme is a
//! `const` slice of [`Field`]s; the caller's data is read and written through the [`Row`] trait
//! by field id; [`pack`] writes into a caller buffer and [`unpack`] reads from one. Every call
//! returns a `Result`; no path reachable from untrusted bytes panics. The bytes are those of
//! the `std` API (the wire format does not change).
//!
//! ```
//! use packbin::nostd::{i32, pack, u16, u8, unpack, Fault, Num, Row, Scheme};
//!
//! #[derive(Default)]
//! struct Position { sid: u16, lat: i32, profile: u8 }
//!
//! impl Row for Position {
//!     fn num(&self, id: u16) -> Option<Num> {
//!         match id { 0 => Some(Num::U16(self.sid)), 1 => Some(Num::I32(self.lat)), 2 => Some(Num::U8(self.profile)), _ => None }
//!     }
//!     fn bytes(&self, _id: u16) -> Option<&[u8]> { None }
//!     fn set_num(&mut self, id: u16, value: Num) -> bool {
//!         match (id, value) {
//!             (0, Num::U16(v)) => { self.sid = v; true }
//!             (1, Num::I32(v)) => { self.lat = v; true }
//!             (2, Num::U8(v)) => { self.profile = v; true }
//!             _ => false,
//!         }
//!     }
//!     fn set_bytes(&mut self, _id: u16, _value: &[u8]) -> bool { false }
//! }
//!
//! const SCHEME: Scheme = Scheme::new(0x40, &[u16(0), i32(1), u8(2)]);
//!
//! # fn main() -> Result<(), Fault> {
//! let mut out = [0u8; 16];
//! let n = pack(&SCHEME, &Position { sid: 1, lat: 500_000_000, profile: 1 }, &mut out)?;
//! let mut back = Position::default();
//! unpack(&SCHEME, &out[..n], &mut back)?;
//! assert_eq!((back.sid, back.lat, back.profile), (1, 500_000_000, 1));
//! # Ok(())
//! # }
//! ```
#![deny(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

mod check;
mod error;
mod io;
mod pack;
mod present;
mod row;
mod scheme;
mod table;
mod unpack;
mod walk;

pub use check::validate;
pub use error::{Error, Fault};
pub use io::{Reader, Writer};
pub use row::{Num, Row};
pub use scheme::{
    be, bits, boolean, bytes, f32, f64, flag_bit, flag_byte, flags, group, i16, i32, i64, i8, list,
    packed, repeat, sized, times, u16, u2, u32, u64, u8, when, Field, Kind, Scheme,
    DEFAULT_MAX_ROUNDS, DEFAULT_MAX_SLOTS, MAX_FIELDS, NO_ID,
};
pub use walk::{pack, unpack};

#[cfg(feature = "alloc")]
pub use walk::pack_vec;
