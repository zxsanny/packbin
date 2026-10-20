//! The images of the embedded stage call these functions: a 14-field scheme packed and unpacked
//! (the size and stack figures), and the golden fixture decoded. Everything the library does
//! here must be free of the heap and of panic paths; the stage checks the linked image.
#![no_std]

use packbin::nostd::{
    be, bytes, f32, i16, i32, i8, pack, u16, u32, u64, u8, unpack, Num, Row, Scheme,
};

// A user program defines the panic handler; the image must not link it (checked in the stage).
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}

#[cfg(feature = "seed_heap")]
mod seeded_heap {
    extern crate alloc;
    use core::alloc::{GlobalAlloc, Layout};

    extern "C" {
        fn malloc(size: usize) -> *mut u8;
        fn free(ptr: *mut u8);
    }
    struct Libc;
    unsafe impl GlobalAlloc for Libc {
        unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
            malloc(layout.size())
        }
        unsafe fn dealloc(&self, ptr: *mut u8, _layout: Layout) {
            free(ptr)
        }
    }
    #[global_allocator]
    static LIBC: Libc = Libc;

    pub fn boxed(input: &[u8]) -> i32 {
        let mut copy = alloc::vec::Vec::with_capacity(input.len());
        for byte in input {
            copy.push(*byte);
        }
        core::hint::black_box(&copy);
        i32::from(copy.last().copied().unwrap_or(0))
    }
}

/// 14 fields: the size probe's table (the C++ probe also has 14 entries).
static ROUTE_FIELDS: [packbin::nostd::Field; 14] = [
    u16(0),
    u16(1),
    u8(2),
    i32(3),
    i32(4),
    u32(5),
    u64(6),
    i16(7),
    i8(8),
    f32(9),
    be(u16(10)),
    be(u32(11)),
    bytes(12, 4),
    u8(13),
];
static ROUTE: Scheme = Scheme::new(0x34, &ROUTE_FIELDS);

static POSITION_FIELDS: [packbin::nostd::Field; 5] = [u16(0), i32(1), i32(2), u8(3), u8(4)];
static POSITION: Scheme = Scheme::new(0x40, &POSITION_FIELDS);

#[derive(Clone, Copy, PartialEq)]
struct Route {
    sid: u16,
    owner: u16,
    n: u8,
    lat: i32,
    lon: i32,
    ts: u32,
    id: u64,
    alt: i16,
    temp: i8,
    hdg: f32,
    port: u16,
    seq: u32,
    tag4: [u8; 4],
    tag: u8,
}

const SAMPLE: Route = Route {
    sid: 0x1234,
    owner: 7,
    n: 3,
    lat: 500_000_000,
    lon: -300_000_000,
    ts: 1_700_000_000,
    id: 0x0102_0304_0506_0708,
    alt: -120,
    temp: -5,
    hdg: 90.5,
    port: 4242,
    seq: 99,
    tag4: [1, 2, 3, 4],
    tag: 9,
};

impl Route {
    const EMPTY: Route = Route {
        sid: 0,
        owner: 0,
        n: 0,
        lat: 0,
        lon: 0,
        ts: 0,
        id: 0,
        alt: 0,
        temp: 0,
        hdg: 0.0,
        port: 0,
        seq: 0,
        tag4: [0; 4],
        tag: 0,
    };
}

impl Row for Route {
    fn num(&self, id: u16) -> Option<Num> {
        match id {
            0 => Some(Num::U16(self.sid)),
            1 => Some(Num::U16(self.owner)),
            2 => Some(Num::U8(self.n)),
            3 => Some(Num::I32(self.lat)),
            4 => Some(Num::I32(self.lon)),
            5 => Some(Num::U32(self.ts)),
            6 => Some(Num::U64(self.id)),
            7 => Some(Num::I16(self.alt)),
            8 => Some(Num::I8(self.temp)),
            9 => Some(Num::F32(self.hdg)),
            10 => Some(Num::U16(self.port)),
            11 => Some(Num::U32(self.seq)),
            13 => Some(Num::U8(self.tag)),
            _ => None,
        }
    }
    fn bytes(&self, id: u16) -> Option<&[u8]> {
        if id == 12 {
            Some(&self.tag4)
        } else {
            None
        }
    }
    fn set_num(&mut self, id: u16, value: Num) -> bool {
        match (id, value) {
            (0, Num::U16(v)) => self.sid = v,
            (1, Num::U16(v)) => self.owner = v,
            (2, Num::U8(v)) => self.n = v,
            (3, Num::I32(v)) => self.lat = v,
            (4, Num::I32(v)) => self.lon = v,
            (5, Num::U32(v)) => self.ts = v,
            (6, Num::U64(v)) => self.id = v,
            (7, Num::I16(v)) => self.alt = v,
            (8, Num::I8(v)) => self.temp = v,
            (9, Num::F32(v)) => self.hdg = v,
            (10, Num::U16(v)) => self.port = v,
            (11, Num::U32(v)) => self.seq = v,
            (13, Num::U8(v)) => self.tag = v,
            _ => return false,
        }
        true
    }
    fn set_bytes(&mut self, id: u16, value: &[u8]) -> bool {
        match (id, <[u8; 4]>::try_from(value)) {
            (12, Ok(v)) => {
                self.tag4 = v;
                true
            }
            _ => false,
        }
    }
}

#[derive(Default)]
struct Position {
    sid: u16,
    lat: i32,
    lon: i32,
    profile: u8,
    flags: u8,
}

impl Row for Position {
    fn num(&self, id: u16) -> Option<Num> {
        match id {
            0 => Some(Num::U16(self.sid)),
            1 => Some(Num::I32(self.lat)),
            2 => Some(Num::I32(self.lon)),
            3 => Some(Num::U8(self.profile)),
            4 => Some(Num::U8(self.flags)),
            _ => None,
        }
    }
    fn bytes(&self, _id: u16) -> Option<&[u8]> {
        None
    }
    fn set_num(&mut self, id: u16, value: Num) -> bool {
        match (id, value) {
            (0, Num::U16(v)) => self.sid = v,
            (1, Num::I32(v)) => self.lat = v,
            (2, Num::I32(v)) => self.lon = v,
            (3, Num::U8(v)) => self.profile = v,
            (4, Num::U8(v)) => self.flags = v,
            _ => return false,
        }
        true
    }
    fn set_bytes(&mut self, _id: u16, _value: &[u8]) -> bool {
        false
    }
}

/// Packs the sample route into `out`; returns the length, or minus the error number.
///
/// # Safety
/// `out` points to `cap` writable bytes.
#[no_mangle]
pub unsafe extern "C" fn pb_rs_route_pack(out: *mut u8, cap: usize) -> i32 {
    let out = core::slice::from_raw_parts_mut(out, cap);
    match pack(&ROUTE, &SAMPLE, out) {
        Ok(n) => n as i32,
        Err(fault) => -(fault.error as i32) - 1,
    }
}

/// Unpacks a route packet; 0 when it equals the sample, else an error number or 100.
///
/// # Safety
/// `input` points to `len` readable bytes.
#[no_mangle]
#[allow(unused_variables)]
pub unsafe extern "C" fn pb_rs_route_unpack(input: *const u8, len: usize) -> i32 {
    let input = core::slice::from_raw_parts(input, len);
    #[cfg(feature = "seed_panic")]
    {
        // A table indexed by input: the bounds check is a panic path.
        let table = [1u8, 2, 3, 4];
        if let Some(first) = input.first() {
            return i32::from(table[usize::from(*first)]);
        }
    }
    #[cfg(feature = "seed_heap")]
    {
        return seeded_heap::boxed(input);
    }
    #[allow(unreachable_code)]
    {
        let mut row = Route::EMPTY;
        match unpack(&ROUTE, input, &mut row) {
            Ok(_) if row == SAMPLE => 0,
            Ok(_) => 100,
            Err(fault) => fault.error as i32 + 1,
        }
    }
}

/// Decodes the golden fixture with the position scheme; 0 when every field is as expected.
///
/// # Safety
/// `input` points to `len` readable bytes.
#[no_mangle]
pub unsafe extern "C" fn pb_rs_golden(input: *const u8, len: usize) -> i32 {
    let input = core::slice::from_raw_parts(input, len);
    let mut row = Position::default();
    match unpack(&POSITION, input, &mut row) {
        Ok(13) => {}
        Ok(_) => return 101,
        Err(fault) => return fault.error as i32 + 1,
    }
    let same = row.sid == 1
        && row.lat == 500_000_000
        && row.lon == 300_000_000
        && row.profile == 1
        && row.flags == 0;
    if same {
        0
    } else {
        100
    }
}

/// A string and a dictionary: packed with the compact encoder in scratch, read back.
#[cfg(feature = "text")]
mod text_extra {
    use packbin::nostd::{
        dict, key, pack_with, u8, unpack, utf8, Field, Num, Row, Scheme, DICT_KEY,
    };

    // A string that the compact form shortens, and a dictionary of two entries.
    static FIELDS: [Field; 4] = [utf8(0), dict(1, 2), key(), u8(0)];
    static SCHEME: Scheme = Scheme::new(0x50, &FIELDS);
    const TEXT: &[u8] = "привіт, світе".as_bytes();

    #[derive(Clone, Copy, PartialEq)]
    struct Entry {
        key: [u8; 8],
        klen: usize,
        value: u8,
    }

    impl Row for Entry {
        fn num(&self, id: u16) -> Option<Num> {
            (id == 0).then_some(Num::U8(self.value))
        }
        fn bytes(&self, id: u16) -> Option<&[u8]> {
            if id == DICT_KEY {
                self.key.get(..self.klen)
            } else {
                None
            }
        }
        fn set_num(&mut self, id: u16, value: Num) -> bool {
            match (id, value) {
                (0, Num::U8(v)) => {
                    self.value = v;
                    true
                }
                _ => false,
            }
        }
        fn set_bytes(&mut self, _id: u16, _value: &[u8]) -> bool {
            false
        }
        fn slots(&mut self, id: u16) -> Option<&mut [u8]> {
            (id == DICT_KEY).then_some(&mut self.key[..])
        }
        fn set_count(&mut self, id: u16, n: usize) -> bool {
            id == DICT_KEY && n <= self.key.len() && {
                self.klen = n;
                true
            }
        }
    }

    #[derive(Clone, Copy, PartialEq)]
    struct Message {
        text: [u8; 32],
        tlen: usize,
        entries: [Entry; 2],
        n: usize,
    }

    const NO_ENTRY: Entry = Entry {
        key: [0; 8],
        klen: 0,
        value: 0,
    };

    impl Row for Message {
        fn num(&self, _id: u16) -> Option<Num> {
            None
        }
        fn bytes(&self, id: u16) -> Option<&[u8]> {
            if id == 0 {
                self.text.get(..self.tlen)
            } else {
                None
            }
        }
        fn set_num(&mut self, _id: u16, _value: Num) -> bool {
            false
        }
        fn set_bytes(&mut self, _id: u16, _value: &[u8]) -> bool {
            false
        }
        fn slots(&mut self, id: u16) -> Option<&mut [u8]> {
            (id == 0).then_some(&mut self.text[..])
        }
        fn set_count(&mut self, id: u16, n: usize) -> bool {
            match id {
                0 if n <= self.text.len() => {
                    self.tlen = n;
                    true
                }
                1 if n <= self.entries.len() => {
                    self.n = n;
                    true
                }
                _ => false,
            }
        }
        fn count(&self, id: u16) -> Option<usize> {
            (id == 1).then_some(self.n)
        }
        fn item(&self, id: u16, k: usize) -> Option<&dyn Row> {
            if id == 1 && k < self.n {
                self.entries.get(k).map(|e| e as &dyn Row)
            } else {
                None
            }
        }
        fn item_mut(&mut self, id: u16, k: usize) -> Option<&mut dyn Row> {
            if id == 1 {
                self.entries.get_mut(k).map(|e| e as &mut dyn Row)
            } else {
                None
            }
        }
    }

    pub fn roundtrip() -> i32 {
        let mut sent = Message {
            text: [0; 32],
            tlen: TEXT.len(),
            entries: [NO_ENTRY; 2],
            n: 2,
        };
        for (slot, byte) in sent.text.iter_mut().zip(TEXT) {
            *slot = *byte;
        }
        sent.entries[0].key[0] = b'a';
        sent.entries[0].klen = 1;
        sent.entries[0].value = 1;
        sent.entries[1].key[0] = b'b';
        sent.entries[1].klen = 1;
        sent.entries[1].value = 2;
        let mut out = [0u8; 64];
        let mut scratch = [0u32; 48];
        let n = match pack_with(&SCHEME, &sent, &mut out, &mut scratch) {
            Ok(n) => n,
            Err(fault) => return fault.error as i32 + 1,
        };
        let mut back = Message {
            text: [0; 32],
            tlen: 0,
            entries: [NO_ENTRY; 2],
            n: 0,
        };
        match out.get(..n).map(|wire| unpack(&SCHEME, wire, &mut back)) {
            Some(Ok(_)) if back == sent => 0,
            Some(Ok(_)) => 100,
            Some(Err(fault)) => fault.error as i32 + 20,
            None => 101,
        }
    }
}

/// A protected position message: packed with 4 parity bytes, two bytes damaged, repaired in place
/// within the limit of 2 and read back.
#[cfg(feature = "ecc")]
mod ecc_extra {
    use super::{Position, POSITION_FIELDS};
    use packbin::nostd::{pack, unpack_repair, Scheme};

    static SCHEME: Scheme = Scheme::new(0x40, &POSITION_FIELDS).with_parity(4);

    pub fn roundtrip() -> i32 {
        let sent = Position {
            sid: 1,
            lat: 500_000_000,
            lon: 300_000_000,
            profile: 1,
            flags: 0,
        };
        let mut out = [0u8; 32];
        let n = match pack(&SCHEME, &sent, &mut out) {
            Ok(n) => n,
            Err(fault) => return fault.error as i32 + 1,
        };
        let Some(wire) = out.get_mut(..n) else {
            return 101;
        };
        let good = [wire.first().copied(), wire.get(5).copied()];
        if let Some(b) = wire.get_mut(0) {
            *b ^= 0x5A;
        }
        if let Some(b) = wire.get_mut(5) {
            *b ^= 0xA5;
        }
        let mut back = Position::default();
        match unpack_repair(&SCHEME, wire, &mut back, 2) {
            Ok(done) if done.repaired == 2 && back.sid == 1 && back.lat == 500_000_000 => {
                if [wire.first().copied(), wire.get(5).copied()] == good {
                    0
                } else {
                    102
                }
            }
            Ok(_) => 100,
            Err(fault) => fault.error as i32 + 20,
        }
    }
}

#[cfg(feature = "session")]
mod session_extra {
    use super::{Position, POSITION_FIELDS};
    use packbin::nostd::{Scheme, Session};

    static SCHEME: Scheme = Scheme::new(0x40, &POSITION_FIELDS);
    const SEED: [u8; 32] = [7; 32];
    const NONCE: [u8; 16] = [3; 16];

    /// A node seals a report and a peer opens it; the packet differs from the clear bytes.
    pub fn roundtrip() -> i32 {
        let (Ok(mut node), Ok(mut peer)) = (Session::load(&SEED), Session::load(&SEED)) else {
            return 1;
        };
        if node.start(&NONCE).is_err() || peer.join(&NONCE).is_err() {
            return 2;
        }
        let sent = Position {
            sid: 1,
            lat: 500_000_000,
            lon: 300_000_000,
            profile: 1,
            flags: 0,
        };
        let mut out = [0u8; 32];
        let n = match node.pack(&SCHEME, &sent, &mut out) {
            Ok(n) => n,
            Err(fault) => return fault.error as i32 + 10,
        };
        let Some(wire) = out.get_mut(..n) else {
            return 3;
        };
        if wire.get(1).copied() == Some(1) && wire.get(2).copied() == Some(0) {
            return 4;
        }
        let mut back = Position::default();
        match peer.unpack(&SCHEME, wire, &mut back) {
            Ok(_) if back.sid == 1 && back.lat == 500_000_000 && back.lon == 300_000_000 => 0,
            Ok(_) => 5,
            Err(fault) => fault.error as i32 + 30,
        }
    }
}

/// What a feature set adds to the image: the round trips of the parts that set builds, called by
/// `main.cpp` when the symbol exists (a weak reference); defined only by a set with parts. 0 when
/// every round trip holds, else a number that names the step.
///
/// # Safety
/// No arguments.
#[cfg(any(feature = "text", feature = "ecc", feature = "session"))]
#[no_mangle]
pub extern "C" fn pb_rs_extra() -> i32 {
    #[cfg(feature = "text")]
    {
        let r = text_extra::roundtrip();
        if r != 0 {
            return r;
        }
    }
    #[cfg(feature = "ecc")]
    {
        let r = ecc_extra::roundtrip();
        if r != 0 {
            return r + 200;
        }
    }
    #[cfg(feature = "session")]
    {
        let r = session_extra::roundtrip();
        if r != 0 {
            return r + 300;
        }
    }
    0
}
