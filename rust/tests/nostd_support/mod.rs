//! A row for the nostd tests: numbers and byte strings kept by field id.
#![allow(dead_code)]

use packbin::nostd::{Num, Row};

#[derive(Default, Clone, Debug, PartialEq)]
pub struct Slots {
    pub nums: Vec<Option<Num>>,
    pub blobs: Vec<Option<Vec<u8>>>,
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
