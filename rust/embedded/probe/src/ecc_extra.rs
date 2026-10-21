//! A protected position message: packed with 4 parity bytes, two bytes damaged, repaired in place
//! within the limit of 2 and read back.

use super::{Position, POSITION_FIELDS};
use packbin::nostd::{pack, unpack_repair, Scheme};

static SCHEME: Scheme = Scheme::new(0x40, &POSITION_FIELDS).with_parity(4);

pub fn roundtrip() -> i32 {
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
