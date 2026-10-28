use super::from_hex;
use packbin::nostd::{
    Fault, FrameConfig, FrameDirection, FrameDirections, FrameSession, MacKey,
    MsgContext,
};
use std::io::{BufRead, BufReader};

fn bytes_of(token: &str) -> Vec<u8> {
    if token == "-" {
        Vec::new()
    } else {
        from_hex(token).unwrap_or_else(|| panic!("bad hex: {token}"))
    }
}

fn hex_of(data: &[u8]) -> String {
    if data.is_empty() {
        "-".into()
    } else {
        data.iter().map(|b| format!("{b:02x}")).collect()
    }
}

fn fault_kind(fault: &Fault) -> &'static str {
    use packbin::nostd::Error;
    match fault.error {
        Error::BadValue => "BadValue",
        Error::TooLong => "TooLong",
        Error::BufferFull => "BufferFull",
        Error::ShortPacket => "ShortPacket",
        Error::TagMismatch => "TagMismatch",
        _ => "error",
    }
}

// The enum holds no direction outside 1 to 3: the refusal is the type, so `None` is the BadValue of the package, as its
// own vector test (`rust/tests/frame_vectors_tests.rs`) reads a row with direction 0 or 4.
fn direction(d: usize) -> Option<FrameDirection> {
    match d {
        1 => Some(FrameDirection::Up),
        2 => Some(FrameDirection::Down),
        3 => Some(FrameDirection::Group),
        _ => None,
    }
}

// The optional trailing fields of a seal or open line: the directions loaded (digits 1 to 3) and the output buffer size.
fn loaded(w: &[&str]) -> (FrameDirections, usize) {
    let digits = w.get(9).copied().unwrap_or("123");
    let size = w.get(10).map_or(300, |token| token.parse().unwrap());
    let set = digits.chars().fold(FrameDirections::NONE, |set, digit| {
        set.with(direction(digit.to_digit(10).unwrap() as usize).unwrap())
    });
    (set, size)
}

fn key32(raw: &[u8]) -> &[u8; 32] {
    raw.try_into().expect("key must be 32 bytes")
}

fn seal(w: &[&str]) -> String {
    let key = bytes_of(w[0]);
    let epoch: u32 = w[1].parse().unwrap();
    let d: usize = w[2].parse().unwrap();
    let tag_len: u8 = w[3].parse().unwrap();
    let msg_id = bytes_of(w[4]);
    let kind: u8 = w[5].parse().unwrap();
    let ad = bytes_of(w[6]);
    let clear = bytes_of(w[7]);
    let plain = bytes_of(w[8]);
    let mut id = [0u8; 8];
    id[..msg_id.len()].copy_from_slice(&msg_id);
    let (directions, size) = loaded(w);
    let session = match FrameSession::load_frame(
        key32(&key),
        epoch,
        FrameConfig {
            tag_len,
            directions,
        },
    ) {
        Ok(s) => s,
        Err(f) => return fault_kind(&f).into(),
    };
    let Some(dir) = direction(d) else {
        return "BadValue".into();
    };
    let mut out = vec![0u8; size];
    match session.seal_frame(
        dir,
        &MsgContext { msg_id: id, kind },
        &ad,
        &clear,
        &plain,
        &mut out,
    ) {
        Ok(n) => hex_of(&out[..n]),
        Err(f) => fault_kind(&f).into(),
    }
}

fn open(w: &[&str]) -> String {
    let key = bytes_of(w[0]);
    let epoch: u32 = w[1].parse().unwrap();
    let d: usize = w[2].parse().unwrap();
    let tag_len: u8 = w[3].parse().unwrap();
    let msg_id = bytes_of(w[4]);
    let kind: u8 = w[5].parse().unwrap();
    let ad = bytes_of(w[6]);
    let clear_len: usize = w[7].parse().unwrap();
    let body = bytes_of(w[8]);
    let mut id = [0u8; 8];
    id[..msg_id.len()].copy_from_slice(&msg_id);
    let (directions, size) = loaded(w);
    let session = match FrameSession::load_frame(
        key32(&key),
        epoch,
        FrameConfig {
            tag_len,
            directions,
        },
    ) {
        Ok(s) => s,
        Err(f) => return fault_kind(&f).into(),
    };
    let Some(dir) = direction(d) else {
        return "BadValue".into();
    };
    let mut out = vec![0u8; size];
    match session.open_frame(
        dir,
        &MsgContext { msg_id: id, kind },
        &ad,
        &body,
        clear_len,
        None,
        &mut out,
    ) {
        Ok(opened) => hex_of(&out[..opened.plain_len]),
        Err(f) => fault_kind(&f).into(),
    }
}

fn mac(w: &[&str]) -> String {
    let key = bytes_of(w[0]);
    let epoch: u32 = w[1].parse().unwrap();
    let label = bytes_of(w[2]);
    let n: usize = w[3].parse().unwrap();
    let message = bytes_of(w[4]);
    let mk = match MacKey::derive(key32(&key), epoch, &label) {
        Ok(m) => m,
        Err(f) => return fault_kind(&f).into(),
    };
    let mut out = vec![0u8; n];
    match mk.tag(&[&message], &mut out) {
        Ok(()) => hex_of(&out),
        Err(f) => fault_kind(&f).into(),
    }
}

fn verify(w: &[&str]) -> String {
    let key = bytes_of(w[0]);
    let epoch: u32 = w[1].parse().unwrap();
    let label = bytes_of(w[2]);
    let _n: usize = w[3].parse().unwrap();
    let message = bytes_of(w[4]);
    let tag = bytes_of(w[5]);
    let mk = match MacKey::derive(key32(&key), epoch, &label) {
        Ok(m) => m,
        Err(f) => return fault_kind(&f).into(),
    };
    if mk.verify(&[&message], &tag) {
        "valid".into()
    } else {
        "invalid".into()
    }
}

fn frame_line(words: &[&str]) -> String {
    match words[0] {
        "seal" => seal(&words[1..]),
        "open" => open(&words[1..]),
        "mac" => mac(&words[1..]),
        "verify" => verify(&words[1..]),
        "open-skip" | "verify-skip" => "skip".into(),
        _ => panic!("frame line: {}", words[0]),
    }
}

pub fn run(args: &[String]) -> u8 {
    if args.len() == 2 && args[0] == "frame-batch" {
        let file = std::fs::File::open(&args[1]).unwrap_or_else(|e| panic!("frame-batch: {e}"));
        let reader = BufReader::new(file);
        for line in reader.lines() {
            let text = line.expect("read line");
            let words: Vec<&str> = text.split_whitespace().collect();
            if !words.is_empty() {
                println!("{}", frame_line(&words));
            }
        }
        return 0;
    }
    2
}
