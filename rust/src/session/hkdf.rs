use super::sha256;

fn hmac_sha256(key: &[u8], message: &[u8]) -> [u8; 32] {
    let mut key_block = [0u8; 64];
    if key.len() > 64 {
        key_block[..32].copy_from_slice(&sha256::hash(key));
    } else {
        key_block[..key.len()].copy_from_slice(key);
    }

    let mut ipad = [0u8; 64];
    let mut opad = [0u8; 64];
    for i in 0..64 {
        ipad[i] = key_block[i] ^ 0x36;
        opad[i] = key_block[i] ^ 0x5c;
    }

    let mut inner = Vec::with_capacity(64 + message.len());
    inner.extend_from_slice(&ipad);
    inner.extend_from_slice(message);
    let inner_hash = sha256::hash(&inner);

    let mut outer = [0u8; 96];
    outer[..64].copy_from_slice(&opad);
    outer[64..].copy_from_slice(&inner_hash);
    sha256::hash(&outer)
}

pub fn derive(ikm: &[u8], salt: &[u8], info: &[u8], output: &mut [u8]) {
    let prk = hmac_sha256(salt, ikm);
    let hash_len = 32usize;
    let n = (output.len() + hash_len - 1) / hash_len;
    let mut t_prev = Vec::new();
    let mut offset = 0;
    for i in 1..=n {
        let mut msg = Vec::with_capacity(t_prev.len() + info.len() + 1);
        msg.extend_from_slice(&t_prev);
        msg.extend_from_slice(info);
        msg.push(i as u8);
        let t = hmac_sha256(&prk, &msg);
        let take = (output.len() - offset).min(hash_len);
        output[offset..offset + take].copy_from_slice(&t[..take]);
        offset += take;
        t_prev = t.to_vec();
    }
}
