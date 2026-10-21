//! A node seals a report and a peer opens it; the packet differs from the clear bytes.

use super::{Position, POSITION_FIELDS};
use packbin::nostd::{Scheme, Session};

static SCHEME: Scheme = Scheme::new(0x40, &POSITION_FIELDS);
const SEED: [u8; 32] = [7; 32];
const NONCE: [u8; 16] = [3; 16];

/// A node seals a report and a peer opens it; the packet differs from the clear bytes.
pub fn roundtrip() -> i32 {
    let (Ok(mut node), Ok(mut peer)) = (Session::load(&SEED), Session::load(&SEED)) else {
        return 1;
    };
    if node.start(&NONCE).is_err() || peer.join(&NONCE).is_err() {
        return 2;
    }
    let sent = Position {
        sid: 1,
        lat: 500_000_000,
        lon: 300_000_000,
        profile: 1,
        flags: 0,
    };
    let mut out = [0u8; 32];
    let n = match node.pack(&SCHEME, &sent, &mut out) {
        Ok(n) => n,
        Err(fault) => return fault.error as i32 + 10,
    };
    let Some(wire) = out.get_mut(..n) else {
        return 3;
    };
    if wire.get(1).copied() == Some(1) && wire.get(2).copied() == Some(0) {
        return 4;
    }
    let mut back = Position::default();
    match peer.unpack(&SCHEME, wire, &mut back) {
        Ok(_) if back.sid == 1 && back.lat == 500_000_000 && back.lon == 300_000_000 => 0,
        Ok(_) => 5,
        Err(fault) => fault.error as i32 + 30,
    }
}
