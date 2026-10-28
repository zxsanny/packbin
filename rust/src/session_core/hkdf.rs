use super::sha256::Sha256;
use super::wipe::wipe;

const BLOCK: usize = 64;

/// HMAC-SHA-256 of the pieces of a message joined, with no buffer for the joined message. One
/// 64-byte block holds the key, then the inner pad, then the outer pad. The block, the inner digest
/// and both hashers are wiped before the tag is returned (AZ-3275).
fn hmac_sha256(key: &[u8], parts: &[&[u8]]) -> [u8; 32] {
    let mut block = [0u8; BLOCK];
    if key.len() > BLOCK {
        let mut hashed = super::sha256::hash(key);
        for (slot, byte) in block.iter_mut().zip(hashed.iter()) {
            *slot = *byte;
        }
        wipe(&mut hashed);
    } else {
        for (slot, byte) in block.iter_mut().zip(key) {
            *slot = *byte;
        }
    }
    for byte in block.iter_mut() {
        *byte ^= 0x36;
    }
    let mut inner = Sha256::new();
    inner.update(&block);
    for part in parts {
        inner.update(part);
    }
    let mut digest = inner.finish();
    for byte in block.iter_mut() {
        *byte ^= 0x36 ^ 0x5c;
    }
    let mut outer = Sha256::new();
    outer.update(&block);
    outer.update(&digest);
    let tag = outer.finish();
    wipe(&mut block);
    wipe(&mut digest);
    inner.wipe();
    outer.wipe();
    tag
}

/// HKDF-SHA-256 (RFC 5869): fills `output` (at most 255 blocks of 32 bytes; a longer tail stays
/// as it was). `prk` and the last block are wiped on every way out.
pub fn derive(ikm: &[u8], salt: &[u8], info: &[u8], output: &mut [u8]) {
    let mut prk = hmac_sha256(salt, &[ikm]);
    let mut previous = [0u8; 32];
    let mut have_previous = false;
    let mut counter = 0u8;
    let mut offset = 0usize;
    while offset < output.len() {
        let Some(next) = counter.checked_add(1) else {
            break;
        };
        counter = next;
        let prior: &[u8] = if have_previous { &previous } else { &[] };
        previous = hmac_sha256(&prk, &[prior, info, &[counter]]);
        have_previous = true;
        let end = offset.saturating_add(32).min(output.len());
        let Some(chunk) = output.get_mut(offset..end) else {
            break;
        };
        for (slot, byte) in chunk.iter_mut().zip(previous.iter()) {
            *slot = *byte;
        }
        offset = end;
    }
    wipe(&mut prk);
    wipe(&mut previous);
}

/// HMAC-SHA-256 of one message, for the reference-vector tests (crypto_vectors_tests, which has this cfg).
#[cfg(all(test, feature = "std"))]
pub(crate) fn hmac_sha256_of(key: &[u8], data: &[u8]) -> [u8; 32] {
    hmac_sha256(key, &[data])
}

#[cfg(test)]
mod tests {
    use super::*;
    #[cfg(not(feature = "std"))]
    use std::{format, string::String, vec::Vec};

    fn hex(bytes: &[u8]) -> String {
        bytes.iter().map(|b| format!("{b:02x}")).collect()
    }

    #[test]
    fn rfc5869_case_1() {
        let ikm = [0x0bu8; 22];
        let salt: Vec<u8> = (0u8..=0x0c).collect();
        let info: Vec<u8> = (0xf0u8..=0xf9).collect();
        let mut okm = [0u8; 42];
        derive(&ikm, &salt, &info, &mut okm);
        assert_eq!(
            hex(&okm),
            "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865"
        );
    }
}
