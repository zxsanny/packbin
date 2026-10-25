fn quarter(w: &mut [u32; 16], a: usize, b: usize, c: usize, d: usize) {
    let (Some(&wa), Some(&wb), Some(&wc), Some(&wd)) = (w.get(a), w.get(b), w.get(c), w.get(d))
    else {
        return;
    };
    let mut x = (wa, wb, wc, wd);
    x.0 = x.0.wrapping_add(x.1);
    x.3 = (x.3 ^ x.0).rotate_left(16);
    x.2 = x.2.wrapping_add(x.3);
    x.1 = (x.1 ^ x.2).rotate_left(12);
    x.0 = x.0.wrapping_add(x.1);
    x.3 = (x.3 ^ x.0).rotate_left(8);
    x.2 = x.2.wrapping_add(x.3);
    x.1 = (x.1 ^ x.2).rotate_left(7);
    for (i, v) in [(a, x.0), (b, x.1), (c, x.2), (d, x.3)] {
        if let Some(slot) = w.get_mut(i) {
            *slot = v;
        }
    }
}

/// Word `i` of `bytes`, little-endian (0 past the end).
fn le_word(bytes: &[u8], i: usize) -> u32 {
    let at = i.saturating_mul(4);
    let mut word = [0u8; 4];
    for (k, slot) in word.iter_mut().enumerate() {
        *slot = bytes.get(at.saturating_add(k)).copied().unwrap_or(0);
    }
    u32::from_le_bytes(word)
}

fn block(key: &[u8; 32], nonce: &[u8; 12], counter: u32, output: &mut [u8; 64]) {
    #[cfg(all(test, feature = "std"))]
    super::counters::chacha_block();
    let mut state = [0u32; 16];
    for (i, slot) in state.iter_mut().enumerate() {
        *slot = match i {
            0 => 0x61707865,
            1 => 0x3320646e,
            2 => 0x79622d32,
            3 => 0x6b206574,
            4..=11 => le_word(key, i - 4),
            12 => counter,
            _ => le_word(nonce, i - 13),
        };
    }

    let mut work = state;
    for _ in 0..10 {
        quarter(&mut work, 0, 4, 8, 12);
        quarter(&mut work, 1, 5, 9, 13);
        quarter(&mut work, 2, 6, 10, 14);
        quarter(&mut work, 3, 7, 11, 15);
        quarter(&mut work, 0, 5, 10, 15);
        quarter(&mut work, 1, 6, 11, 12);
        quarter(&mut work, 2, 7, 8, 13);
        quarter(&mut work, 3, 4, 9, 14);
    }

    let mixed = work.iter().zip(state.iter()).map(|(m, o)| m.wrapping_add(*o));
    for (slot, byte) in output.iter_mut().zip(mixed.flat_map(u32::to_le_bytes)) {
        *slot = byte;
    }
}

/// XORs the ChaCha20 stream of `key` and packet number `packet` into `data`.
#[cfg(any(feature = "std", feature = "session"))]
pub fn xor(key: &[u8; 32], packet: u64, data: &mut [u8]) {
    let mut nonce = [0u8; 12];
    for (slot, byte) in nonce.iter_mut().zip(packet.to_le_bytes()) {
        *slot = byte;
    }
    let mut counter = 0u32;
    let mut pad = [0u8; 64];
    let mut used = 64usize;
    for byte in data.iter_mut() {
        if used == 64 {
            block(key, &nonce, counter, &mut pad);
            counter = counter.wrapping_add(1);
            used = 0;
        }
        *byte ^= pad.get(used).copied().unwrap_or(0);
        used += 1;
    }
}

/// XORs the RFC 8439 ChaCha20 stream of `key` and the 12-byte `nonce`, block counter from 0, into `data`.
#[cfg(feature = "frame")]
pub fn xor_with_nonce(key: &[u8; 32], nonce: &[u8; 12], data: &mut [u8]) {
    let mut counter = 0u32;
    let mut pad = [0u8; 64];
    let mut used = 64usize;
    for byte in data.iter_mut() {
        if used == 64 {
            block(key, nonce, counter, &mut pad);
            counter = counter.wrapping_add(1);
            used = 0;
        }
        *byte ^= pad.get(used).copied().unwrap_or(0);
        used += 1;
    }
    for byte in pad.iter_mut() {
        *byte = 0;
    }
}

/// The ChaCha20 block of any 12-byte nonce and counter, for the reference-vector tests.
#[cfg(test)]
pub(crate) fn block_of(key: &[u8; 32], nonce: &[u8; 12], counter: u32) -> [u8; 64] {
    let mut output = [0u8; 64];
    block(key, nonce, counter, &mut output);
    output
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rfc8439_block_vector() {
        let mut key = [0u8; 32];
        for (i, b) in key.iter_mut().enumerate() {
            *b = i as u8;
        }
        let nonce = [
            0x00, 0x00, 0x00, 0x09, 0x00, 0x00, 0x00, 0x4a, 0x00, 0x00, 0x00, 0x00,
        ];
        let mut out = [0u8; 64];
        block(&key, &nonce, 1, &mut out);
        let expected = [
            0x10, 0xf1, 0xe7, 0xe4, 0xd1, 0x3b, 0x59, 0x15, 0x50, 0x0f, 0xdd, 0x1f, 0xa3, 0x20,
            0x71, 0xc4, 0xc7, 0xd1, 0xf4, 0xc7, 0x33, 0xc0, 0x68, 0x03, 0x04, 0x22, 0xaa, 0x9a,
            0xc3, 0xd4, 0x6c, 0x4e,
        ];
        assert_eq!(&out[..32], &expected);
    }
}
