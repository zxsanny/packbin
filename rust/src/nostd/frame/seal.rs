//! Seal and open of frame mode on caller buffers, in the order of the contract.

use super::{
    ct_eq, refuse, DirKeys, Direction, FrameState, Freshness, MsgCtx, Opened, ReplayWindow, Slot,
    SlotKeys, MAX_BODY,
};
use crate::nostd::error::{Error, Fault};
use crate::nostd::session::Session;
use crate::session_core::pad;

/// `msg_id ‖ ((kind << 4) | direction) ‖ epoch` as 24 bits.
fn nonce(ctx: &MsgCtx, direction: Direction, epoch: u32) -> [u8; 12] {
    let [a, b, c, d, e, f, g, h] = ctx.msg_id;
    let [e0, e1, e2, _] = epoch.to_le_bytes();
    [
        a,
        b,
        c,
        d,
        e,
        f,
        g,
        h,
        (ctx.kind << 4) | direction as u8,
        e0,
        e1,
        e2,
    ]
}

fn call_checks(
    state: &FrameState,
    direction: Direction,
    ctx: &MsgCtx,
    ad: &[u8],
) -> Result<(), Fault> {
    if !state.directions.contains(direction) || ctx.kind > 15 {
        return Err(refuse(Error::BadValue, 0));
    }
    if ad.len() > 255 {
        return Err(refuse(Error::TooLong, 255));
    }
    Ok(())
}

fn length_byte(len: usize) -> Result<u8, Fault> {
    u8::try_from(len).map_err(|_| refuse(Error::TooLong, 255))
}

/// The tag over the contract's `M` (nonce, `len(ad)`, `ad`, `len(clear)`, `clear`, ciphertext).
fn tag_of(
    keys: &DirKeys,
    n: &[u8; 12],
    ad: &[u8],
    clear: &[u8],
    ciphertext: &[u8],
) -> Result<[u8; 32], Fault> {
    let lengths = [length_byte(ad.len())?, length_byte(clear.len())?];
    let [ad_len, clear_len] = lengths;
    Ok(keys
        .pads
        .mac(&[n, &[ad_len], ad, &[clear_len], clear, ciphertext]))
}

fn put(dst: &mut [u8], at: usize, src: &[u8]) -> bool {
    let Some(end) = at.checked_add(src.len()) else {
        return false;
    };
    let Some(slot) = dst.get_mut(at..end) else {
        return false;
    };
    for (to, from) in slot.iter_mut().zip(src) {
        *to = *from;
    }
    true
}

fn zero(bytes: &mut [u8]) {
    for byte in bytes.iter_mut() {
        *byte = 0;
    }
}

/// Which slot's tag matches, and the nonce it used.
fn verify(
    slot: &SlotKeys,
    direction: Direction,
    ctx: &MsgCtx,
    ad: &[u8],
    clear: &[u8],
    ciphertext: &[u8],
    tag: &[u8],
) -> Option<[u8; 12]> {
    let keys = slot.dir(direction)?;
    let n = nonce(ctx, direction, slot.epoch);
    let full = tag_of(keys, &n, ad, clear, ciphertext).ok()?;
    ct_eq(full.get(..tag.len())?, tag).then_some(n)
}

impl Session {
    /// Seals `clear ‖ plain` into `out` as `clear ‖ ciphertext ‖ tag` and returns the body length. The same
    /// inputs give the same bytes; the session does not change and the previous key is not used. A direction
    /// the session did not load, or a `kind` above 15, is `BadValue`; `ad` above 255 bytes or a body above
    /// 255 bytes is `TooLong`; an `out` shorter than the body is `BufferFull`; on any refusal nothing is
    /// written.
    ///
    /// **Never seal two different messages with the same `ctx.msg_id` under one key, epoch and direction**:
    /// the library cannot check it, and a reused `msg_id` breaks the confidentiality of both messages.
    pub fn seal_frame(
        &self,
        direction: Direction,
        ctx: &MsgCtx,
        ad: &[u8],
        clear: &[u8],
        plain: &[u8],
        out: &mut [u8],
    ) -> Result<usize, Fault> {
        let state = self
            .frame
            .as_ref()
            .ok_or_else(|| refuse(Error::BadValue, 0))?;
        call_checks(state, direction, ctx, ad)?;
        let tag_len = usize::from(state.tag_len);
        let body_len = clear
            .len()
            .checked_add(plain.len())
            .and_then(|n| n.checked_add(tag_len))
            .filter(|n| *n <= MAX_BODY)
            .ok_or_else(|| refuse(Error::TooLong, MAX_BODY))?;
        if out.len() < body_len {
            return Err(refuse(Error::BufferFull, body_len));
        }
        let keys = state
            .current
            .dir(direction)
            .ok_or_else(|| refuse(Error::BadValue, 0))?;
        let n = nonce(ctx, direction, state.current.epoch);
        let cipher_end = clear.len().saturating_add(plain.len());
        let done = put(out, 0, clear) && put(out, clear.len(), plain);
        let tag = match out.get_mut(clear.len()..cipher_end) {
            Some(ciphertext) if done => {
                pad::xor_with_nonce(&keys.enc, &n, ciphertext);
                tag_of(keys, &n, ad, clear, ciphertext)
            }
            _ => Err(refuse(Error::BufferFull, body_len)),
        };
        let written = tag
            .ok()
            .and_then(|full| full.get(..tag_len).map(|t| put(out, cipher_end, t)));
        if written != Some(true) {
            zero(out.get_mut(..body_len).unwrap_or(&mut []));
            return Err(refuse(Error::BufferFull, body_len));
        }
        Ok(body_len)
    }

    /// Opens `body` (`clear ‖ ciphertext ‖ tag`, the first `clear_len` bytes clear) in the contract's order:
    /// argument checks, the replay window (when given, with the message's counter: `Duplicate` or `TooOld`
    /// before any hashing), the tag with the current key and then once with the previous key
    /// (`TagMismatch`), decryption into `out`, and only then the window commit. A failed open leaves `out`
    /// and the window as they were. A body shorter than `clear_len` plus the tag is `ShortPacket`; an `out`
    /// shorter than the plaintext is `BufferFull`.
    #[allow(clippy::too_many_arguments)]
    pub fn open_frame(
        &self,
        direction: Direction,
        ctx: &MsgCtx,
        ad: &[u8],
        body: &[u8],
        clear_len: usize,
        replay: Option<(&mut ReplayWindow, u64)>,
        out: &mut [u8],
    ) -> Result<Opened, Fault> {
        let state = self
            .frame
            .as_ref()
            .ok_or_else(|| refuse(Error::BadValue, 0))?;
        call_checks(state, direction, ctx, ad)?;
        let tag_len = usize::from(state.tag_len);
        let framing = clear_len.saturating_add(tag_len);
        let plain_len = body
            .len()
            .checked_sub(framing)
            .ok_or_else(|| refuse(Error::ShortPacket, framing))?;
        if out.len() < plain_len {
            return Err(refuse(Error::BufferFull, plain_len));
        }
        if let Some((window, counter)) = replay.as_ref() {
            match window.check(*counter) {
                Freshness::Fresh => {}
                Freshness::Duplicate => return Err(refuse(Error::Duplicate, 0)),
                Freshness::TooOld => return Err(refuse(Error::TooOld, 0)),
            }
        }
        let cipher_end = clear_len.saturating_add(plain_len);
        let (Some(clear), Some(ciphertext), Some(tag)) = (
            body.get(..clear_len),
            body.get(clear_len..cipher_end),
            body.get(cipher_end..),
        ) else {
            return Err(refuse(Error::ShortPacket, framing));
        };
        let (slot, keys, n) =
            match verify(&state.current, direction, ctx, ad, clear, ciphertext, tag) {
                Some(n) => (Slot::Current, &state.current, n),
                None => {
                    let previous = state
                        .previous
                        .as_ref()
                        .ok_or_else(|| refuse(Error::TagMismatch, 0))?;
                    let n = verify(previous, direction, ctx, ad, clear, ciphertext, tag)
                        .ok_or_else(|| refuse(Error::TagMismatch, 0))?;
                    (Slot::Previous, previous, n)
                }
            };
        let enc = &keys
            .dir(direction)
            .ok_or_else(|| refuse(Error::BadValue, 0))?
            .enc;
        let Some(plain_out) = out.get_mut(..plain_len) else {
            return Err(refuse(Error::BufferFull, plain_len));
        };
        for (to, from) in plain_out.iter_mut().zip(ciphertext) {
            *to = *from;
        }
        pad::xor_with_nonce(enc, &n, plain_out);
        if let Some((window, counter)) = replay {
            window.commit(counter);
        }
        Ok(Opened {
            slot,
            clear_len,
            plain_len,
        })
    }
}
