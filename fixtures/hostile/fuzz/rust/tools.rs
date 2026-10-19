// Probe tools: the seeded stream, CPU and peak RSS, hex and varint, the fixtures and a compact text
// writer built from the frozen code lengths (included by main.rs).

// ---------------------------------------------------------------- small tools

struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
    fn below(&mut self, n: usize) -> usize {
        if n == 0 {
            0
        } else {
            (self.next() % n as u64) as usize
        }
    }
    fn byte(&mut self) -> u8 {
        self.next() as u8
    }
    fn fill(&mut self, n: usize) -> Vec<u8> {
        (0..n).map(|_| self.byte()).collect()
    }
}

#[repr(C)]
struct Timeval {
    sec: i64,
    usec: i32,
    _pad: i32,
}

#[repr(C)]
struct Rusage {
    utime: Timeval,
    stime: Timeval,
    maxrss: i64,
    rest: [i64; 13],
}

extern "C" {
    fn getrusage(who: i32, usage: *mut Rusage) -> i32;
}

/// (CPU seconds, peak RSS in MB) of this process so far.
fn usage() -> (f64, f64) {
    let mut r = Rusage {
        utime: Timeval { sec: 0, usec: 0, _pad: 0 },
        stime: Timeval { sec: 0, usec: 0, _pad: 0 },
        maxrss: 0,
        rest: [0; 13],
    };
    unsafe {
        getrusage(0, &mut r);
    }
    let cpu = r.utime.sec as f64 + r.utime.usec as f64 / 1e6 + r.stime.sec as f64 + r.stime.usec as f64 / 1e6;
    let rss_bytes = if cfg!(target_os = "macos") { r.maxrss as f64 } else { r.maxrss as f64 * 1024.0 };
    (cpu, rss_bytes / 1e6)
}

fn report_usage(label: &str) {
    let (cpu, rss) = usage();
    println!("usage {label}: cpu {cpu:.2} s, peak RSS {rss:.1} MB");
}

fn hex(s: &str) -> Vec<u8> {
    if s == "-" {
        return Vec::new();
    }
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).expect("hex"))
        .collect()
}

fn to_hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

fn head(b: &[u8]) -> String {
    let h = to_hex(&b[..b.len().min(40)]);
    if b.len() > 40 {
        format!("{h}...({} bytes)", b.len())
    } else {
        h
    }
}

fn varint(mut c: usize) -> Vec<u8> {
    let mut out = Vec::new();
    loop {
        let b = (c & 0x7f) as u8;
        c >>= 7;
        if c == 0 {
            out.push(b);
            return out;
        }
        out.push(b | 0x80);
    }
}

fn field(payload: &[u8]) -> Vec<u8> {
    let mut f = varint(payload.len());
    f.extend_from_slice(payload);
    f
}

/// Runs `f`, catching a panic. Returns the result (None on a panic) and the time it took.
fn guarded<R>(f: impl FnOnce() -> R) -> (Option<R>, Duration) {
    let started = Instant::now();
    let r = catch_unwind(AssertUnwindSafe(f)).ok();
    (r, started.elapsed())
}

// ---------------------------------------------------------------- fixtures

struct Seeds {
    text: Vec<Vec<u8>>,
    ecc: Vec<(usize, Vec<u8>)>,
    corpus: Vec<Vec<u8>>,
}

fn load_seeds(checkout: &str) -> Seeds {
    let read = |p: &str| std::fs::read_to_string(format!("{checkout}/{p}")).unwrap_or_else(|e| panic!("{p}: {e}"));
    let mut text = Vec::new();
    for line in read("fixtures/text/vectors.txt").lines() {
        let w: Vec<&str> = line.split_whitespace().collect();
        match w.first() {
            Some(&"enc") | Some(&"alt") if w.len() == 4 => text.push(hex(w[3])),
            Some(&"bad") if w.len() == 4 => text.push(hex(w[3])),
            _ => {}
        }
    }
    let mut ecc = Vec::new();
    for line in read("fixtures/ecc/vectors.txt").lines() {
        let w: Vec<&str> = line.split_whitespace().collect();
        match w.first() {
            Some(&"enc") if w.len() == 5 => ecc.push((w[2].parse().unwrap(), hex(w[4]))),
            Some(&"fix") if w.len() == 7 => ecc.push((w[2].parse().unwrap(), hex(w[4]))),
            Some(&"bad") if w.len() == 6 => ecc.push((w[2].parse().unwrap(), hex(w[4]))),
            _ => {}
        }
    }
    let mut corpus = Vec::new();
    for line in read("fixtures/hostile/fuzz/corpus.txt").lines() {
        if line.starts_with('#') {
            continue;
        }
        let w: Vec<&str> = line.split_whitespace().collect();
        if w.len() == 3 {
            corpus.push(hex(w[2]));
        }
    }
    Seeds { text, ecc, corpus }
}

// ---------------------------------------------------------------- compact text writer (from the frozen lengths)

struct Codes {
    modes: Vec<Vec<(u32, u8)>>,
}

fn parse_lengths(src: &str, name: &str) -> Vec<u8> {
    let start = src.find(&format!("pub const {name}:")).unwrap_or_else(|| panic!("{name}"));
    let rest = &src[start..];
    let open = rest.find("= [").expect("[") + 3;
    let close = rest[open..].find("];").expect("];") + open;
    rest[open..close].split(',').filter_map(|s| s.trim().parse().ok()).collect()
}

fn canonical(lengths: &[u8]) -> Vec<(u32, u8)> {
    let mut order: Vec<usize> = (0..lengths.len()).collect();
    order.sort_by_key(|&s| (lengths[s], s));
    let mut codes = vec![(0u32, 0u8); lengths.len()];
    let mut code = 0u32;
    let mut prev = lengths[order[0]];
    for (k, &s) in order.iter().enumerate() {
        let l = lengths[s];
        if k > 0 {
            code = (code + 1) << (l - prev);
        }
        codes[s] = (code, l);
        prev = l;
    }
    codes
}

impl Codes {
    fn load(checkout: &str) -> Codes {
        let src = std::fs::read_to_string(format!("{checkout}/rust/src/walk/text_tables.rs")).expect("text_tables.rs");
        let modes = ["LENGTHS_UA", "LENGTHS_RU", "LENGTHS_EN", "LENGTHS_NUM"]
            .iter()
            .map(|n| canonical(&parse_lengths(&src, n)))
            .collect();
        Codes { modes }
    }
}

const LETTERS: [usize; 3] = [34, 33, 27];
const UA: usize = 0;
const RU: usize = 1;
const EN: usize = 2;
const NUM: usize = 3;

fn sw_base(mode: usize) -> usize {
    if mode == NUM {
        15
    } else {
        LETTERS[mode] + 32
    }
}
fn sw(mode: usize, target: usize) -> usize {
    sw_base(mode) + target - usize::from(target > mode)
}
fn cap(mode: usize) -> usize {
    sw_base(mode) + 3
}
fn lock(mode: usize) -> usize {
    sw_base(mode) + 4
}
fn esc(mode: usize) -> usize {
    if mode == NUM {
        18
    } else {
        sw_base(mode) + 5
    }
}
/// Index of the shared character `c` (0 = space) in a text mode.
fn shared(mode: usize, k: usize) -> usize {
    LETTERS[mode] + k
}

struct Bits<'a> {
    codes: &'a Codes,
    v: Vec<u8>,
    n: usize,
}

impl<'a> Bits<'a> {
    fn new(codes: &'a Codes, start_mode: usize) -> Self {
        let mut b = Bits { codes, v: Vec::new(), n: 0 };
        b.raw(0, 3);
        b.raw(start_mode as u32, 3);
        b
    }
    fn raw(&mut self, code: u32, len: u8) {
        for i in (0..len).rev() {
            if self.n % 8 == 0 {
                self.v.push(0);
            }
            if (code >> i) & 1 == 1 {
                let idx = self.n / 8;
                self.v[idx] |= 0x80 >> (self.n % 8);
            }
            self.n += 1;
        }
    }
    fn sym(&mut self, mode: usize, idx: usize) {
        let (c, l) = self.codes.modes[mode][idx];
        self.raw(c, l);
    }
    fn byte(&mut self, b: u8) {
        self.raw(b as u32, 8);
    }
    fn finish(mut self) -> Vec<u8> {
        let pad = (8 - self.n % 8) % 8;
        self.v[0] |= (pad as u8) << 5;
        self.v
    }
}
