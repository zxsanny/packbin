//! The heap-free API: plain-data schemes, caller buffers, errors as values.
//!
//! It builds with `#![no_std]` and no allocator (`default-features = false`). A scheme is a
//! `const` slice of [`Field`]s in order, a parent entry followed by its members (`span` counts
//! them: `flags(1, 2), u8(1), u16(2)`); the caller's data is read and written through the
//! [`Row`] trait by field id, and the items of a `repeat`, `times` or `list` are rows of their
//! own. [`pack`] writes into a caller buffer and [`unpack`] reads from one. Every call returns a
//! `Result`; no path reachable from untrusted bytes panics. The bytes are those of the `std` API
//! (the wire format does not change).
//!
//! Cargo features: `text` adds strings ([`utf8`]: the row holds UTF-8 text through
//! [`Row::bytes`] on pack and [`Row::slots`] with [`Row::set_count`] on unpack) and dictionaries
//! ([`dict`] with [`key()`]: an item row holds its key under [`DICT_KEY`] and its element under id
//! 0; keys are strictly ascending by their UTF-8 bytes). The compact encoder keeps its parse in
//! the caller's scratch words ([`pack_with`], [`SCRATCH_WORDS_PER_CHAR`] per code point);
//! [`utf8_wire`] keeps a string as it is on the wire and needs no feature. `ecc` adds parity
//! bytes after every packet ([`Scheme::with_parity`], [`unpack_repair`], the codec in
//! [`ecc`]). `session` adds the stream session and `frame` adds frame mode of the session (sealed,
//! authenticated radio frames, a replay window and the MAC-only [`MacKey`]; `pack-session.md` 2.0.0).
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
mod count;
#[cfg(feature = "ecc")]
pub mod ecc;
mod error;
#[cfg(feature = "frame")]
mod frame;
mod io;
mod pack;
mod present;
mod row;
mod scheme;
#[cfg(any(feature = "session", feature = "frame"))]
mod session;
mod strings;
mod table;
#[cfg(feature = "text")]
mod text;
mod unpack;
mod walk;

pub use check::validate;
pub use error::{Error, Fault};
pub use io::{Reader, Writer};
pub use row::{Num, Row};
pub use scheme::{
    be, bits, boolean, bytes, dict, f32, f64, flag_bit, flag_byte, flags, group, i16, i32, i64, i8,
    key, list, packed, repeat, sized, times, u16, u2, u32, u64, u8, utf8, utf8_wire, when, Field,
    Kind, Scheme, DEFAULT_MAX_ROUNDS, DEFAULT_MAX_SLOTS, DICT_KEY, MAX_FIELDS, MAX_PARITY, NO_ID,
};
#[cfg(feature = "text")]
pub use text::SCRATCH_WORDS_PER_CHAR;
#[cfg(feature = "frame")]
pub use frame::{
    Direction, Directions, Freshness, FrameConfig, MacKey, MsgCtx, Opened, ReplayWindow, Slot, MAX_BODY,
};
#[cfg(any(feature = "session", feature = "frame"))]
pub use session::Session;
#[cfg(feature = "session")]
pub use session::{NONCE_SIZE, SEED_SIZE};
pub use walk::{pack, pack_with, unpack};
#[cfg(feature = "ecc")]
pub use walk::{unpack_repair, Unpacked};

#[cfg(feature = "alloc")]
pub use walk::pack_vec;
