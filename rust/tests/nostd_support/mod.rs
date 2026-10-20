//! A row for the nostd tests: numbers and byte strings kept by field id.
#![allow(dead_code)]

#[cfg(feature = "std")]
pub mod tree;

use packbin::nostd::{Num, Row};

/// Storage each `sized`, `bits` or `packed` field gets on unpack unless `cap` says otherwise.
pub const SLOTS: usize = 64;

#[derive(Default, Clone, Debug, PartialEq)]
pub struct Slots {
    pub nums: Vec<Option<Num>>,
    pub blobs: Vec<Option<Vec<u8>>>,
    pub flags: Vec<bool>,
    /// The storage `slots` offers, `SLOTS` when `None`.
    pub cap: Option<usize>,
}

impl Slots {
    pub fn with(nums: &[(u16, Num)], blobs: &[(u16, &[u8])]) -> Slots {
        let mut slots = Slots::default();
        for (id, n) in nums {
            slots.set_num(*id, *n);
        }
        for (id, b) in blobs {
            slots.set_bytes(*id, b);
        }
        slots
    }
}

impl Row for Slots {
    fn num(&self, id: u16) -> Option<Num> {
        self.nums.get(usize::from(id)).copied().flatten()
    }
    fn bytes(&self, id: u16) -> Option<&[u8]> {
        self.blobs.get(usize::from(id))?.as_deref()
    }
    fn set_num(&mut self, id: u16, value: Num) -> bool {
        let at = usize::from(id);
        if self.nums.len() <= at {
            self.nums.resize(at + 1, None);
        }
        self.nums[at] = Some(value);
        true
    }
    fn set_bytes(&mut self, id: u16, value: &[u8]) -> bool {
        let at = usize::from(id);
        if self.blobs.len() <= at {
            self.blobs.resize(at + 1, None);
        }
        self.blobs[at] = Some(value.to_vec());
        true
    }
    fn flag(&self, id: u16) -> bool {
        self.flags.get(usize::from(id)).copied().unwrap_or(false)
    }
    fn set_flag(&mut self, id: u16, on: bool) -> bool {
        let at = usize::from(id);
        if self.flags.len() <= at {
            self.flags.resize(at + 1, false);
        }
        self.flags[at] = on;
        true
    }
    fn clear(&mut self, id: u16) {
        let at = usize::from(id);
        if let Some(n) = self.nums.get_mut(at) {
            *n = None;
        }
        if let Some(b) = self.blobs.get_mut(at) {
            *b = None;
        }
        if let Some(f) = self.flags.get_mut(at) {
            *f = false;
        }
    }
    fn slots(&mut self, id: u16) -> Option<&mut [u8]> {
        let at = usize::from(id);
        if self.blobs.len() <= at {
            self.blobs.resize(at + 1, None);
        }
        let cap = self.cap.unwrap_or(SLOTS);
        self.blobs[at] = Some(vec![0; cap]);
        self.blobs[at].as_deref_mut()
    }
    fn set_count(&mut self, id: u16, n: usize) -> bool {
        match self.blobs.get_mut(usize::from(id)) {
            Some(Some(b)) if n <= b.len() => {
                b.truncate(n);
                true
            }
            _ => false,
        }
    }
}

pub fn from_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).expect("hex digit"))
        .collect()
}

pub fn golden() -> Vec<u8> {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/../fixtures/golden.hex");
    from_hex(std::fs::read_to_string(path).expect("golden.hex").trim())
}
