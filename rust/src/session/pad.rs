fn quarter(w: &mut [u32; 16], a: usize, b: usize, c: usize, d: usize) {
    w[a] = w[a].wrapping_add(w[b]);
    w[d] ^= w[a];
    w[d] = w[d].rotate_left(16);
    w[c] = w[c].wrapping_add(w[d]);
    w[b] ^= w[c];
    w[b] = w[b].rotate_left(12);
    w[a] = w[a].wrapping_add(w[b]);
    w[d] ^= w[a];
    w[d] = w[d].rotate_left(8);
    w[c] = w[c].wrapping_add(w[d]);
    w[b] ^= w[c];
    w[b] = w[b].rotate_left(7);
}

fn block(key: &[u8; 32], nonce: &[u8; 12], counter: u32, output: &mut [u8; 64]) {
    let mut state = [0u32; 16];
    state[0] = 0x61707865;
    state[1] = 0x3320646e;
    state[2] = 0x79622d32;
    state[3] = 0x6b206574;
    for i in 0..8 {
        state[4 + i] = u32::from_le_bytes([
            key[i * 4],
            key[i * 4 + 1],
            key[i * 4 + 2],
            key[i * 4 + 3],
        ]);
    }
    state[12] = counter;
    state[13] = u32::from_le_bytes([nonce[0], nonce[1], nonce[2], nonce[3]]);
    state[14] = u32::from_le_bytes([nonce[4], nonce[5], nonce[6], nonce[7]]);
    state[15] = u32::from_le_bytes([nonce[8], nonce[9], nonce[10], nonce[11]]);

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

    for i in 0..16 {
        let word = work[i].wrapping_add(state[i]);
        output[i * 4..(i + 1) * 4].copy_from_slice(&word.to_le_bytes());
    }
}

pub fn xor(key: &[u8; 32], packet: u64, data: &mut [u8]) {
    let mut nonce = [0u8; 12];
    nonce[..8].copy_from_slice(&packet.to_le_bytes());
    let mut counter = 0u32;
    let mut offset = 0;
    let mut pad = [0u8; 64];
    while offset < data.len() {
        block(key, &nonce, counter, &mut pad);
        let n = (data.len() - offset).min(64);
        for i in 0..n {
            data[offset + i] ^= pad[i];
        }
        offset += n;
        counter = counter.wrapping_add(1);
    }
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
