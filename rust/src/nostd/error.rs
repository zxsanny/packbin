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
    /// A protected message is longer than 254 bytes.
    TooLong,
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
    pub(crate) const fn new(error: Error, offset: usize, field: i32, needed: usize) -> Self {
        Fault {
            error,
            offset,
            field,
            needed,
        }
    }
}
