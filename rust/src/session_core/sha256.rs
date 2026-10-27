const K: [u32; 64] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

fn rotr(x: u32, n: u32) -> u32 {
    x.rotate_right(n)
}

/// Word `i` modulo 16 of the rolling message schedule.
fn at(w: &[u32; 16], i: usize) -> u32 {
    w.get(i & 15).copied().unwrap_or(0)
}

/// One block. The message schedule is a window of 16 words (not 64) to keep the stack small; the
/// block is read byte by byte, since `chunks_exact` links a division and a panic path.
fn compress(state: &mut [u32; 8], block: &[u8; 64]) {
    #[cfg(all(test, feature = "std"))]
    super::counters::sha_compression();
    let mut w = [0u32; 16];
    let mut word = 0u32;
    for (i, byte) in block.iter().enumerate() {
        word = (word << 8) | u32::from(*byte);
        if i & 3 == 3 {
            if let Some(slot) = w.get_mut(i >> 2) {
                *slot = word;
            }
        }
    }

    let [mut a, mut b, mut c, mut d, mut e, mut f, mut g, mut h] = *state;
    for i in 0..64usize {
        let wi = if i < 16 {
            at(&w, i)
        } else {
            let x = at(&w, i - 15);
            let y = at(&w, i - 2);
            let s0 = rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3);
            let s1 = rotr(y, 17) ^ rotr(y, 19) ^ (y >> 10);
            let v = at(&w, i - 16)
                .wrapping_add(s0)
                .wrapping_add(at(&w, i - 7))
                .wrapping_add(s1);
            if let Some(slot) = w.get_mut(i & 15) {
                *slot = v;
            }
            v
        };
        let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        let ch = (e & f) ^ ((!e) & g);
        let t1 = h
            .wrapping_add(s1)
            .wrapping_add(ch)
            .wrapping_add(K.get(i).copied().unwrap_or(0))
            .wrapping_add(wi);
        let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        let maj = (a & b) ^ (a & c) ^ (b & c);
        let t2 = s0.wrapping_add(maj);
        h = g;
        g = f;
        f = e;
        e = d.wrapping_add(t1);
        d = c;
        c = b;
        b = a;
        a = t1.wrapping_add(t2);
    }

    for (slot, v) in state.iter_mut().zip([a, b, c, d, e, f, g, h]) {
        *slot = slot.wrapping_add(v);
    }
    // The last 16 schedule words give back the whole block when the recurrence is run backwards, and at key load
    // the block is the key XOR a pad (security review, loop 73).
    super::wipe::wipe(&mut w);
}

const INITIAL: [u32; 8] = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
];

/// SHA-256 over input given in pieces, so a caller needs no buffer for the joined message.
pub struct Sha256 {
    state: [u32; 8],
    block: [u8; 64],
    filled: usize,
    total: u64,
}

impl Sha256 {
    pub fn new() -> Self {
        Sha256 {
            state: INITIAL,
            block: [0u8; 64],
            filled: 0,
            total: 0,
        }
    }

    /// A hash that continues from the chaining state `state` after `bytes_done` bytes (a multiple of 64):
    /// the HMAC pad blocks are compressed once, at key load.
    #[cfg(feature = "frame")]
    pub fn resume(state: [u32; 8], bytes_done: u64) -> Self {
        Sha256 {
            state,
            block: [0u8; 64],
            filled: 0,
            total: bytes_done,
        }
    }

    pub fn update(&mut self, data: &[u8]) {
        self.total = self.total.wrapping_add(data.len() as u64);
        for byte in data {
            if let Some(slot) = self.block.get_mut(self.filled) {
                *slot = *byte;
            }
            self.filled += 1;
            if self.filled == 64 {
                compress(&mut self.state, &self.block);
                self.filled = 0;
            }
        }
    }

    /// The digest. Call it once per hasher: it keeps its padded state, so a second call or a later `update` gives a
    /// wrong digest. A caller that hashed key bytes wipes the hasher where it lives.
    pub fn finish(&mut self) -> [u8; 32] {
        let bit_len = self.total.wrapping_mul(8);
        self.update_padding(0x80);
        while self.filled != 56 {
            self.update_padding(0);
        }
        for (slot, byte) in self.block.iter_mut().skip(56).zip(bit_len.to_be_bytes()) {
            *slot = byte;
        }
        compress(&mut self.state, &self.block);
        let mut out = [0u8; 32];
        let words = self.state.iter().flat_map(|word| word.to_be_bytes());
        for (slot, byte) in out.iter_mut().zip(words) {
            *slot = byte;
        }
        out
    }

    /// Overwrites the chaining state and the block buffer, which hold key-derived words while a key is hashed.
    pub(crate) fn wipe(&mut self) {
        super::wipe::wipe(&mut self.state);
        super::wipe::wipe(&mut self.block);
    }

    /// One padding byte; the length counter is not touched.
    fn update_padding(&mut self, byte: u8) {
        if let Some(slot) = self.block.get_mut(self.filled) {
            *slot = byte;
        }
        self.filled += 1;
        if self.filled == 64 {
            compress(&mut self.state, &self.block);
            self.filled = 0;
        }
    }
}

/// The chaining state after the one block `block` (the start of a precomputed HMAC pad).
#[cfg(feature = "frame")]
pub fn midstate(block: &[u8; 64]) -> [u32; 8] {
    let mut state = INITIAL;
    compress(&mut state, block);
    state
}

pub fn hash(data: &[u8]) -> [u8; 32] {
    let mut sha = Sha256::new();
    sha.update(data);
    let digest = sha.finish();
    sha.wipe();
    digest
}

#[cfg(test)]
mod tests {
    use super::*;
    #[cfg(not(feature = "std"))]
    use std::{format, string::String};

    fn hex(bytes: &[u8]) -> String {
        bytes.iter().map(|b| format!("{b:02x}")).collect()
    }

    #[test]
    fn nist_vectors_and_pieces_agree() {
        assert_eq!(
            hex(&hash(b"")),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        );
        assert_eq!(
            hex(&hash(b"abc")),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
        let long = [0x61u8; 200];
        let mut pieces = Sha256::new();
        pieces.update(&long[..63]);
        pieces.update(&long[63..64]);
        pieces.update(&long[64..]);
        assert_eq!(pieces.finish(), hash(&long));
        let two_blocks = b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
        assert_eq!(
            hex(&hash(two_blocks)),
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        );
    }
}
