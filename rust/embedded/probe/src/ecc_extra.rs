//! A protected position message: packed with 4 parity bytes, two bytes damaged, repaired in place
//! within the limit of 2 and read back; then the same message under a parity percentage (25 % and
//! 50 % of the 13 clear bytes give 4 and 7 parity bytes, rounded up), repaired with a limit above
//! what the message allows, which the core lowers to n / 2.

use super::{Position, POSITION_FIELDS};
use packbin::nostd::{pack, unpack_repair, Scheme};

static SCHEME: Scheme = Scheme::new(0x40, &POSITION_FIELDS).with_parity(4);
static PERCENT_25: Scheme = Scheme::new(0x40, &POSITION_FIELDS).with_parity_percent(25);
static PERCENT_50: Scheme = Scheme::new(0x40, &POSITION_FIELDS).with_parity_percent(50);

/// The type byte, a `u16`, two `i32`, two `u8`.
const CLEAR_BYTES: usize = 13;
const WRONG_AT: [usize; 3] = [0, 5, 9];

pub fn roundtrip() -> i32 {
    let r = count_roundtrip();
    if r != 0 {
        return r;
    }
    let r = percent_roundtrip(&PERCENT_25, 4, 130);
    if r != 0 {
        return r;
    }
    percent_roundtrip(&PERCENT_50, 7, 160)
}

/// Packs under a percentage, checks the parity count (the rounding), damages n / 2 bytes, repairs
/// with the largest limit (16, lowered to n / 2) and compares the clear values. `base` names the
/// step in the result.
fn percent_roundtrip(scheme: &Scheme, parity: usize, base: i32) -> i32 {
    let sent = Position {
        sid: 1,
        lat: 500_000_000,
        lon: 300_000_000,
        profile: 1,
        flags: 0,
    };
    let mut out = [0u8; 48];
    let n = match pack(scheme, &sent, &mut out) {
        Ok(n) => n,
        Err(fault) => return base + fault.error as i32 + 1,
    };
    if n != CLEAR_BYTES + parity {
        return base + 20;
    }
    let Some(wire) = out.get_mut(..n) else {
        return base + 21;
    };
    let damaged = parity / 2;
    for at in WRONG_AT.iter().take(damaged) {
        let Some(b) = wire.get_mut(*at) else {
            return base + 22;
        };
        *b ^= 0xA5;
    }
    let mut back = Position::default();
    match unpack_repair(scheme, wire, &mut back, 16) {
        Ok(done)
            if done.repaired == damaged
                && back.sid == 1
                && back.lat == 500_000_000
                && back.lon == 300_000_000
                && back.profile == 1
                && back.flags == 0 =>
        {
            0
        }
        Ok(_) => base + 23,
        Err(fault) => base + 24 + fault.error as i32,
    }
}

fn count_roundtrip() -> i32 {
    let sent = Position {
        sid: 1,
        lat: 500_000_000,
        lon: 300_000_000,
        profile: 1,
        flags: 0,
    };
    let mut out = [0u8; 32];
    let n = match pack(&SCHEME, &sent, &mut out) {
        Ok(n) => n,
        Err(fault) => return fault.error as i32 + 1,
    };
    let Some(wire) = out.get_mut(..n) else {
        return 101;
    };
    let good = [wire.first().copied(), wire.get(5).copied()];
    if let Some(b) = wire.get_mut(0) {
        *b ^= 0x5A;
    }
    if let Some(b) = wire.get_mut(5) {
        *b ^= 0xA5;
    }
    let mut back = Position::default();
    match unpack_repair(&SCHEME, wire, &mut back, 2) {
        Ok(done) if done.repaired == 2 && back.sid == 1 && back.lat == 500_000_000 => {
            if [wire.first().copied(), wire.get(5).copied()] == good {
                0
            } else {
                102
            }
        }
        Ok(_) => 100,
        Err(fault) => fault.error as i32 + 20,
    }
}
