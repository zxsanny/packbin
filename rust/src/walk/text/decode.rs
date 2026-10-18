//! The decoder: bounded by the payload length, accepts every stream the rules allow.
use super::{
    alpha_len, cap_symbol, lock_symbol, tables, ModeTable, Refusal, ALPHA, MAX_CODE_LEN,
    MAX_TEXT_BYTES, NUM, NUMSET, RAW_PREFIX, SHARED, UPPER,
};

/// Bit `p` of the payload (bit 0 is the most significant bit of the first byte).
fn bit(payload: &[u8], p: usize) -> u32 {
    ((payload[p >> 3] >> (7 - (p & 7))) & 1) as u32
}

/// The 8 bits that start at bit `p`; the caller has checked that they are inside the payload.
fn byte_at(payload: &[u8], p: usize) -> u8 {
    let i = p >> 3;
    let next = payload.get(i + 1).copied().unwrap_or(0);
    let word = ((payload[i] as u16) << 8) | next as u16;
    (word >> (8 - (p & 7))) as u8
}

/// Reads one UTF-8 scalar of 8-bit groups at bit `pos`; returns it and the next position.
fn escaped_char(payload: &[u8], pos: usize, total: usize) -> Result<(char, usize), &'static str> {
    if pos + 8 > total {
        return Err("esc");
    }
    let lead = byte_at(payload, pos);
    let n = match lead {
        0..=0x7f => 1,
        0xc0..=0xdf => 2,
        0xe0..=0xef => 3,
        0xf0..=0xf7 => 4,
        _ => return Err("utf8"),
    };
    if pos + 8 * n > total {
        return Err("esc");
    }
    let mut bytes = [0u8; 4];
    for (j, b) in bytes.iter_mut().enumerate().take(n) {
        *b = byte_at(payload, pos + 8 * j);
    }
    match std::str::from_utf8(&bytes[..n])
        .ok()
        .and_then(|s| s.chars().next())
    {
        Some(ch) => Ok((ch, pos + 8 * n)),
        None => Err("utf8"),
    }
}

fn next_symbol(
    mode: &ModeTable,
    payload: &[u8],
    pos: usize,
    total: usize,
) -> Result<(usize, usize), &'static str> {
    let mut code = 0u32;
    for l in 1..=MAX_CODE_LEN {
        if pos + l > total {
            return Err("code");
        }
        code = (code << 1) | bit(payload, pos + l - 1);
        let first = mode.first[l];
        if code >= first && code - first < mode.count[l] {
            let sym = mode.sorted[(mode.start[l] + code - first) as usize];
            return Ok((sym as usize, pos + l));
        }
    }
    Err("code")
}

/// Decodes one non-empty payload.
fn decode_payload(payload: &[u8]) -> Result<String, &'static str> {
    let first = payload[0];
    let mut mode = ((first >> 2) & 7) as usize;
    if mode == 4 {
        if first != RAW_PREFIX {
            return Err("raw");
        }
        let text = std::str::from_utf8(&payload[1..]).map_err(|_| "utf8")?;
        if text.len() > MAX_TEXT_BYTES {
            return Err("length");
        }
        return Ok(text.to_string());
    }
    if mode > 4 {
        return Err("mode");
    }
    let pad = (first >> 5) as usize;
    let total = 8 * payload.len() - pad;
    if total < 6 {
        return Err("pad");
    }
    if (total..8 * payload.len()).any(|p| bit(payload, p) == 1) {
        return Err("pad");
    }
    let t = tables();
    let mut pos = 6;
    let (mut lock, mut cap) = (false, false);
    let mut out = String::with_capacity((2 * payload.len() + 8).min(MAX_TEXT_BYTES));
    while pos < total {
        let (sym, after) = next_symbol(&t.modes[mode], payload, pos, total)?;
        pos = after;
        let ch;
        if mode == NUM {
            if sym < NUMSET.len() {
                if cap {
                    return Err("cap");
                }
                ch = NUMSET[sym];
            } else if sym < NUMSET.len() + 3 {
                if cap {
                    return Err("cap");
                }
                mode = sym - NUMSET.len();
                continue;
            } else {
                if cap {
                    return Err("cap");
                }
                let (c, next) = escaped_char(payload, pos, total)?;
                pos = next;
                ch = c as u32;
            }
        } else {
            let letters = alpha_len(mode);
            let shared_end = letters + SHARED.len();
            if sym < letters {
                let up = UPPER[mode][sym];
                if cap {
                    if up == 0 {
                        return Err("cap");
                    }
                    ch = up;
                    cap = false;
                } else if lock && up != 0 {
                    ch = up;
                } else {
                    ch = ALPHA[mode][sym];
                }
            } else if sym < shared_end {
                if cap {
                    return Err("cap");
                }
                ch = SHARED[sym - letters];
            } else if sym < shared_end + 3 {
                if cap {
                    return Err("cap");
                }
                let j = sym - shared_end;
                mode = j + usize::from(j >= mode);
                continue;
            } else if sym == cap_symbol(mode) {
                if lock || cap {
                    return Err("cap");
                }
                cap = true;
                continue;
            } else if sym == lock_symbol(mode) {
                if cap {
                    return Err("cap");
                }
                lock = !lock;
                continue;
            } else {
                if cap {
                    return Err("cap");
                }
                let (c, next) = escaped_char(payload, pos, total)?;
                pos = next;
                ch = c as u32;
            }
        }
        let ch = char::from_u32(ch).ok_or("utf8")?;
        if out.len() + ch.len_utf8() > MAX_TEXT_BYTES {
            return Err("length");
        }
        out.push(ch);
    }
    if cap {
        return Err("cap");
    }
    Ok(out)
}

/// Decodes the string field at the start of `buf`: the text and the bytes the field uses.
pub(crate) fn decode(buf: &[u8]) -> Result<(String, usize), Refusal> {
    let mut count = 0usize;
    let mut used = 0;
    loop {
        if used == 3 {
            return Err(Refusal {
                kind: "varint",
                needed: count,
                left: 0,
            });
        }
        let Some(&b) = buf.get(used) else {
            return Err(Refusal {
                kind: "short",
                needed: 1,
                left: 0,
            });
        };
        count |= ((b & 0x7f) as usize) << (7 * used);
        used += 1;
        if b & 0x80 == 0 {
            if used > 1 && b == 0 {
                return Err(Refusal {
                    kind: "varint",
                    needed: count,
                    left: 0,
                });
            }
            break;
        }
    }
    if count == 0 {
        return Ok((String::new(), used));
    }
    if buf.len() - used < count {
        return Err(Refusal {
            kind: "short",
            needed: count,
            left: buf.len() - used,
        });
    }
    match decode_payload(&buf[used..used + count]) {
        Ok(text) => Ok((text, used + count)),
        Err(kind) => Err(Refusal {
            kind,
            needed: count,
            left: 0,
        }),
    }
}
