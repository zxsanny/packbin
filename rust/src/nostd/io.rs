use super::error::{Error, Fault};

/// Output over a caller buffer. A write that does not fit is [`Error::BufferFull`] and writes
/// nothing.
#[derive(Debug)]
pub struct Writer<'a> {
    buf: &'a mut [u8],
    len: usize,
}

impl<'a> Writer<'a> {
    pub fn new(buf: &'a mut [u8]) -> Self {
        Writer { buf, len: 0 }
    }

    /// Bytes written so far.
    pub fn len(&self) -> usize {
        self.len
    }

    pub fn is_empty(&self) -> bool {
        self.len == 0
    }

    /// Bytes left in the buffer.
    pub(crate) fn room(&self) -> usize {
        self.buf.len().saturating_sub(self.len)
    }

    /// The next `n` bytes of the buffer, not yet counted as written ([`Writer::advance`] does).
    pub(crate) fn reserve(&mut self, n: usize, field: i32) -> Result<&mut [u8], Fault> {
        let at = self.len;
        let full = || Fault::new(Error::BufferFull, at, field, n);
        let end = at.checked_add(n).ok_or_else(full)?;
        self.buf.get_mut(at..end).ok_or_else(full)
    }

    /// Counts `n` reserved bytes as written.
    pub(crate) fn advance(&mut self, n: usize) {
        self.len = self.len.saturating_add(n).min(self.buf.len());
    }

    pub fn put(&mut self, src: &[u8], field: i32) -> Result<(), Fault> {
        let full = || Fault::new(Error::BufferFull, self.len, field, src.len());
        let end = self.len.checked_add(src.len()).ok_or_else(full)?;
        let dst = self.buf.get_mut(self.len..end).ok_or_else(full)?;
        for (slot, byte) in dst.iter_mut().zip(src) {
            *slot = *byte;
        }
        self.len = end;
        Ok(())
    }
}

/// Input over a caller buffer. A read past the end is [`Error::ShortPacket`] and moves nothing.
#[derive(Clone, Copy, Debug)]
pub struct Reader<'a> {
    data: &'a [u8],
    pos: usize,
}

impl<'a> Reader<'a> {
    pub fn new(data: &'a [u8]) -> Self {
        Reader { data, pos: 0 }
    }

    /// Bytes read so far.
    pub fn pos(&self) -> usize {
        self.pos
    }

    pub fn take(&mut self, n: usize, field: i32) -> Result<&'a [u8], Fault> {
        let short = || Fault::new(Error::ShortPacket, self.pos, field, n);
        let end = self.pos.checked_add(n).ok_or_else(short)?;
        let bytes = self.data.get(self.pos..end).ok_or_else(short)?;
        self.pos = end;
        Ok(bytes)
    }

    /// True when bytes are left to read.
    pub(crate) fn has_more(&self) -> bool {
        self.pos < self.data.len()
    }

    /// Fails with [`Error::TrailingBytes`] when bytes are left.
    pub fn finish(&self) -> Result<(), Fault> {
        if self.pos < self.data.len() {
            return Err(Fault::new(Error::TrailingBytes, self.pos, -1, 0));
        }
        Ok(())
    }
}
