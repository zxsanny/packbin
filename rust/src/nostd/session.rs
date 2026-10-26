//! The session pad on caller buffers (the C++ `session.hpp` port): keys come from HKDF-SHA-256 over
//! the shared seed and the opener's nonce, and every packet is XORed in place with a ChaCha20 stream
//! keyed by the packet index. The hash, the key derivation and the pad are the code the `std`
//! `PackSession` runs, so the bytes are the same. No heap, no OS calls: the nonce is the caller's.

#[cfg(feature = "session")]
use super::error::{Error, Fault};
#[cfg(feature = "session")]
use super::io::Writer;
#[cfg(feature = "session")]
use super::row::Row;
#[cfg(feature = "session")]
use super::scheme::Scheme;
#[cfg(feature = "session")]
use super::walk::{pack_clear, read};
#[cfg(feature = "session")]
use crate::session_core::{pad, split_keys, wipe::wipe, NONCE_SIZE as NONCE, SEED_SIZE as SEED};

#[cfg(all(feature = "session", feature = "ecc"))]
use super::walk::Unpacked;

/// The bytes of a seed.
#[cfg(feature = "session")]
pub const SEED_SIZE: usize = SEED;
/// The bytes of a nonce.
#[cfg(feature = "session")]
pub const NONCE_SIZE: usize = NONCE;

#[cfg(feature = "session")]
fn refused(needed: usize) -> Fault {
    Fault::new(Error::BadValue, 0, -1, needed)
}

#[cfg(feature = "session")]
struct Keys {
    send: [u8; SEED_SIZE],
    recv: [u8; SEED_SIZE],
}

/// A session between two nodes that share a seed. Not `Clone`: a copy would reuse the send pad for
/// the same packet index. The caller supplies the nonce of [`Session::start`]; one nonce must open
/// only one session per seed, which the library cannot check.
pub struct Session {
    #[cfg(feature = "session")]
    seed: Option<[u8; SEED_SIZE]>,
    #[cfg(feature = "session")]
    keys: Option<Keys>,
    #[cfg(feature = "session")]
    send_count: u64,
    #[cfg(feature = "session")]
    recv_count: u64,
    /// The frame-mode keys, set by `load_frame` (`frame` module); a session is a stream or a frame session.
    #[cfg(feature = "frame")]
    pub(super) frame: super::frame::FrameState,
}

#[cfg(feature = "frame")]
impl Session {
    /// A session with no keys at all and zeroed frame slots: a constant, so it is written where it is declared.
    pub(super) const fn unloaded() -> Session {
        Session {
            #[cfg(feature = "session")]
            seed: None,
            #[cfg(feature = "session")]
            keys: None,
            #[cfg(feature = "session")]
            send_count: 0,
            #[cfg(feature = "session")]
            recv_count: 0,
            frame: super::frame::FrameState::empty(),
        }
    }

    /// True when this session holds stream state (a seed or keys).
    #[cfg(feature = "session")]
    pub(super) fn has_stream_state(&self) -> bool {
        self.seed.is_some() || self.keys.is_some()
    }
}

#[cfg(feature = "session")]
impl Session {
    /// Keeps `seed`. A seed that is not [`SEED_SIZE`] bytes is [`Error::BadValue`] (`needed` 32).
    pub fn load(seed: &[u8]) -> Result<Self, Fault> {
        if seed.len() != SEED_SIZE {
            return Err(refused(SEED_SIZE));
        }
        let mut owned = [0u8; SEED_SIZE];
        for (slot, byte) in owned.iter_mut().zip(seed) {
            *slot = *byte;
        }
        Ok(Session {
            seed: Some(owned),
            keys: None,
            send_count: 0,
            recv_count: 0,
            #[cfg(feature = "frame")]
            frame: super::frame::FrameState::empty(),
        })
    }

    /// Opens as the initiator with the caller's `nonce`. A nonce of another length (`needed` 16)
    /// or a session that is already open is [`Error::BadValue`].
    pub fn start(&mut self, nonce: &[u8]) -> Result<(), Fault> {
        self.open(nonce, true)
    }

    /// Opens as the responder with the initiator's `nonce`.
    pub fn join(&mut self, nonce: &[u8]) -> Result<(), Fault> {
        self.open(nonce, false)
    }

    pub fn is_open(&self) -> bool {
        self.keys.is_some()
    }

    fn open(&mut self, nonce: &[u8], initiator: bool) -> Result<(), Fault> {
        if nonce.len() != NONCE_SIZE {
            return Err(refused(NONCE_SIZE));
        }
        if self.keys.is_some() {
            return Err(refused(0));
        }
        // The seed is wiped where it lives before the slot is emptied: `take` would leave its bytes there.
        let seed = self.seed.as_mut().ok_or_else(|| refused(0))?;
        let (send, recv) = split_keys(seed, nonce, initiator);
        wipe(seed);
        self.seed = None;
        self.keys = Some(Keys { send, recv });
        Ok(())
    }

    /// Packs `row` into `out`, pads it in place with the next send position, then appends the
    /// scheme's parity bytes (the code covers the padded bytes). Returns the bytes written. The
    /// send position moves only when the pack succeeds; on a failure the bytes written are zeroed.
    pub fn pack(
        &mut self,
        scheme: &Scheme<'_>,
        row: &dyn Row,
        out: &mut [u8],
    ) -> Result<usize, Fault> {
        self.pack_with(scheme, row, out, &mut [])
    }

    /// Like [`Session::pack`], with the scratch words of [`pack_with`](super::pack_with).
    pub fn pack_with(
        &mut self,
        scheme: &Scheme<'_>,
        row: &dyn Row,
        out: &mut [u8],
        scratch: &mut [u32],
    ) -> Result<usize, Fault> {
        let keys = self.keys.as_ref().ok_or_else(|| refused(0))?;
        let mut writer = Writer::new(out);
        let sealed = pack_clear(scheme, row, &mut writer, scratch)
            .and_then(|()| parity_room(scheme, &mut writer));
        if let Err(fault) = sealed {
            writer.zero();
            return Err(fault);
        }
        pad::xor(&keys.send, self.send_count, writer.written_mut());
        self.send_count = self.send_count.wrapping_add(1);
        #[cfg(feature = "ecc")]
        if scheme.parity != 0 {
            super::ecc::seal(&mut writer, usize::from(scheme.parity))?;
        }
        Ok(writer.len())
    }

    /// Removes the pad from `data` in place, then reads the packet into `row` and returns the bytes
    /// read (parity included). A protected scheme is checked, not repaired (see
    /// [`Session::unpack_repair`]). `data` ends as the clear packet. The receive position moves for
    /// every packet that reaches the pad, a refused one included, so the next packet from the sender
    /// is still read at its own position; only a refused argument leaves it alone.
    pub fn unpack(
        &mut self,
        scheme: &Scheme<'_>,
        data: &mut [u8],
        row: &mut dyn Row,
    ) -> Result<usize, Fault> {
        let keys = self.keys.as_ref().ok_or_else(|| refused(0))?;
        super::check::validate(scheme)?;
        let index = self.recv_count;
        self.recv_count = self.recv_count.wrapping_add(1);
        #[cfg(feature = "ecc")]
        if scheme.parity != 0 {
            let n = usize::from(scheme.parity);
            super::ecc::detect(data, n)?;
            let clear = data.len().saturating_sub(n);
            let clear_bytes = data.get_mut(..clear).unwrap_or(&mut []);
            pad::xor(&keys.recv, index, clear_bytes);
            return read(scheme, clear_bytes, row).map(|used| used.saturating_add(n));
        }
        pad::xor(&keys.recv, index, data);
        read(scheme, data, row)
    }

    /// Repairs up to `limit` wrong bytes of the padded packet and its parity first, drops the
    /// parity, removes the pad, then reads (the code covers the padded bytes). `data` ends as the
    /// clear packet followed by the parity bytes, which stay as they were. A `limit` above parity / 2
    /// is [`Error::BadValue`] before the receive position moves.
    #[cfg(feature = "ecc")]
    pub fn unpack_repair(
        &mut self,
        scheme: &Scheme<'_>,
        data: &mut [u8],
        row: &mut dyn Row,
        limit: usize,
    ) -> Result<Unpacked, Fault> {
        let keys = self.keys.as_ref().ok_or_else(|| refused(0))?;
        super::check::validate(scheme)?;
        let n = usize::from(scheme.parity);
        if limit > n / 2 {
            return Err(refused(n / 2));
        }
        let index = self.recv_count;
        self.recv_count = self.recv_count.wrapping_add(1);
        let repaired = super::ecc::fix(data, n, limit)?;
        let clear = data.len().saturating_sub(n);
        let clear_bytes = data.get_mut(..clear).unwrap_or(&mut []);
        pad::xor(&keys.recv, index, clear_bytes);
        let used = read(scheme, clear_bytes, row)?;
        Ok(Unpacked {
            bytes: used.saturating_add(n),
            repaired,
        })
    }
}

#[cfg(feature = "session")]
impl Drop for Session {
    /// Wipes the seed and both keys through the volatile wipe. The frame keys wipe themselves.
    fn drop(&mut self) {
        if let Some(seed) = self.seed.as_mut() {
            wipe(seed);
        }
        if let Some(keys) = self.keys.as_mut() {
            wipe(&mut keys.send);
            wipe(&mut keys.recv);
        }
    }
}

/// The room a protected scheme's parity bytes need, checked before the pad uses a position.
#[cfg(feature = "session")]
fn parity_room(scheme: &Scheme<'_>, writer: &mut Writer<'_>) -> Result<(), Fault> {
    #[cfg(feature = "ecc")]
    if scheme.parity != 0 {
        return super::ecc::room(writer, usize::from(scheme.parity));
    }
    let _ = (scheme, writer);
    Ok(())
}
