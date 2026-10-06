mod hkdf;
mod pad;
mod sha256;

use crate::scheme::{BinaryPacker, DispatchHandler, Scheme};
use crate::value::{PackError, ShortPacket, UnpackError};
use std::io::Read;

pub const SEED_SIZE: usize = 32;
pub const NONCE_SIZE: usize = 16;

/// Why `PackSession::pack` returned no payload: the session has no send key yet, or the row
/// cannot be packed (the same `PackError` as `BinaryPacker::pack`).
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SessionPackError {
    NotOpen,
    Pack(PackError),
}

pub struct PackSession {
    seed: Option<[u8; SEED_SIZE]>,
    send: Option<[u8; SEED_SIZE]>,
    recv: Option<[u8; SEED_SIZE]>,
    send_count: u64,
    recv_count: u64,
}

impl PackSession {
    pub fn load(seed: &[u8]) -> Option<Self> {
        if seed.len() != SEED_SIZE {
            return None;
        }
        let mut owned = [0u8; SEED_SIZE];
        owned.copy_from_slice(seed);
        Some(Self {
            seed: Some(owned),
            send: None,
            recv: None,
            send_count: 0,
            recv_count: 0,
        })
    }

    pub fn start(&mut self) -> Option<[u8; NONCE_SIZE]> {
        if self.send.is_some() || self.seed.is_none() {
            return None;
        }
        let mut nonce = [0u8; NONCE_SIZE];
        if !fill_random(&mut nonce) {
            return None;
        }
        if !self.open(&nonce, true) {
            return None;
        }
        Some(nonce)
    }

    pub fn start_with(&mut self, nonce: &[u8]) -> Option<[u8; NONCE_SIZE]> {
        if !self.open(nonce, true) {
            return None;
        }
        let mut out = [0u8; NONCE_SIZE];
        out.copy_from_slice(nonce);
        Some(out)
    }

    pub fn join(&mut self, nonce: &[u8]) -> bool {
        self.open(nonce, false)
    }

    /// Packs `row` and encrypts it with the next pad position, which only a successful pack uses.
    pub fn pack<T>(&mut self, scheme: &Scheme<T>, row: &T) -> Result<Vec<u8>, SessionPackError> {
        let send = self.send.as_ref().ok_or(SessionPackError::NotOpen)?;
        let mut clear = BinaryPacker::pack(scheme, row).map_err(SessionPackError::Pack)?;
        pad::xor(send, self.send_count, &mut clear);
        self.send_count = self.send_count.wrapping_add(1);
        Ok(clear)
    }

    pub fn unpack(
        &mut self,
        bytes: &[u8],
        handlers: &mut [&mut dyn DispatchHandler],
    ) -> Result<(), UnpackError> {
        let recv = match self.recv.as_ref() {
            Some(key) => key,
            None => {
                return Err(UnpackError::Short(ShortPacket {
                    field: String::new(),
                    needed: 1,
                    left: 0,
                }));
            }
        };
        let mut clear = bytes.to_vec();
        pad::xor(recv, self.recv_count, &mut clear);
        self.recv_count = self.recv_count.wrapping_add(1);
        BinaryPacker::unpack_with(&clear, handlers)
    }

    fn open(&mut self, nonce: &[u8], initiator: bool) -> bool {
        if self.seed.is_none() || self.send.is_some() || nonce.len() != NONCE_SIZE {
            return false;
        }
        let mut seed = self.seed.take().unwrap();
        let mut both = [0u8; SEED_SIZE * 2];
        hkdf::derive(&seed, nonce, b"packbin", &mut both);
        seed.fill(0);
        let mut first = [0u8; SEED_SIZE];
        let mut second = [0u8; SEED_SIZE];
        first.copy_from_slice(&both[..SEED_SIZE]);
        second.copy_from_slice(&both[SEED_SIZE..]);
        if initiator {
            self.send = Some(first);
            self.recv = Some(second);
        } else {
            self.send = Some(second);
            self.recv = Some(first);
        }
        both.fill(0);
        true
    }
}

fn fill_random(buf: &mut [u8]) -> bool {
    match std::fs::File::open("/dev/urandom") {
        Ok(mut f) => f.read_exact(buf).is_ok(),
        Err(_) => false,
    }
}
