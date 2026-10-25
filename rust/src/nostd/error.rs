/// Why a call failed. The kinds are those of the C++ core, so the packages read alike.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Error {
    /// The packet ends before a field does (`Fault::needed` bytes were wanted).
    ShortPacket,
    /// Bytes are left after the last field.
    TrailingBytes,
    /// The first byte is not the scheme's type number (`Fault::needed` is the expected one).
    TypeMismatch,
    /// The output buffer is full (`Fault::needed` bytes were wanted).
    BufferFull,
    /// A count is above a limit.
    TooMany,
    /// A row has no value for a field, or one of another kind or length.
    BadValue,
    /// The scheme is not valid; nothing was read or written.
    SchemeInvalid,
    /// A string needs more scratch than the caller gave (`Fault::needed` words).
    ScratchTooSmall,
    /// A protected message has more wrong bytes than the correction limit allows.
    Uncorrectable,
    /// A protected message is longer than 254 bytes; a frame body is longer than 255 bytes, or its
    /// associated data is longer than 255 bytes.
    TooLong,
    /// Frame mode: the tag of a frame does not match (a changed byte, or another key, epoch,
    /// direction, `kind` or `msg_id`).
    TagMismatch,
    /// Frame mode: the replay window has already seen the counter of this frame.
    Duplicate,
    /// Frame mode: the counter of this frame is 64 or more behind the highest the window saw.
    TooOld,
}

/// A failed call: what, and where. `offset` is the byte where the failure was found, `field` the
/// order id (-1 when no field applies) and `needed` the bytes (or words) that field required.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Fault {
    pub error: Error,
    pub offset: usize,
    pub field: i32,
    pub needed: usize,
}

impl Fault {
    /// `BadValue` at `offset` naming the field with order id `field`.
    pub(crate) const fn bad(offset: usize, field: i32) -> Self {
        Fault::new(Error::BadValue, offset, field, 0)
    }

    pub(crate) const fn new(error: Error, offset: usize, field: i32, needed: usize) -> Self {
        Fault {
            error,
            offset,
            field,
            needed,
        }
    }
}
