//! The memo of the last raw field (see [`forget_raw`]) and the raw field itself.

use super::super::count::put_field;
use super::super::error::Fault;
use super::super::io::Writer;
use super::RAW_PREFIX;

/// Scratch words 0 and 1 remember, between two strings of one `pack`, the last string written raw:
/// the offset of its payload (0 for none) and its length. A later string that equals it is known to
/// lose to the raw form without a parse (the parse is a function of the text alone), the memo the
/// C++ core and the `std` walker keep. A parse overwrites the words, so it clears word 0 unless it
/// ends raw, and a pack starts by clearing it ([`forget_raw`]).
const RAW_MEMO_WORDS: usize = 2;

/// Clears the memo; every pack starts here, so a scratch left by an earlier call is not believed.
pub(crate) fn forget_raw(scratch: &mut [u32]) {
    if scratch.len() >= RAW_MEMO_WORDS {
        if let Some(word) = scratch.first_mut() {
            *word = 0;
        }
    }
}

/// True when `s` equals the text of the last field written raw in this packet (its bytes are read
/// back from the output, inside what was written).
pub(super) fn is_last_raw(w: &Writer<'_>, scratch: &[u32], s: &[u8]) -> bool {
    let (Some(&at), Some(&len)) = (scratch.first(), scratch.get(1)) else {
        return false;
    };
    if at == 0 || usize::try_from(len).ok() != Some(s.len()) {
        return false;
    }
    let from = usize::try_from(at).unwrap_or(usize::MAX).saturating_add(1);
    let to = from.saturating_add(s.len());
    w.written().get(from..to) == Some(s)
}

/// Writes the raw field (the prefix byte, then the text) and remembers it.
pub(super) fn put_raw(
    w: &mut Writer<'_>,
    scratch: &mut [u32],
    id: i32,
    s: &[u8],
) -> Result<(), Fault> {
    let raw = s.len().saturating_add(1);
    let p = put_field(w, raw, id)?;
    if let Some((prefix, text)) = p.split_first_mut() {
        *prefix = RAW_PREFIX;
        for (slot, byte) in text.iter_mut().zip(s) {
            *slot = *byte;
        }
    }
    if scratch.len() >= RAW_MEMO_WORDS {
        let at = u32::try_from(w.len().saturating_sub(raw)).unwrap_or(0);
        let len = u32::try_from(s.len()).unwrap_or(0);
        for (slot, value) in scratch.iter_mut().zip([at, len]) {
            *slot = value;
        }
    }
    Ok(())
}
