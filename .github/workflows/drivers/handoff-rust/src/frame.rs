use super::from_hex;
use packbin::nostd::{
    Fault, FrameConfig, FrameDirection, FrameDirections, FrameSession, MacKey,
    MsgContext,
};
use std::io::{BufRead, BufReader};

// A token that is not hex (a bad digit, an odd length), a number with other characters and a missing field are errors of
// the line, never a zero or a cut; the batch loop reports the line number and stops.
type Parsed<T> = Result<T, String>;

fn word<'a>(w: &[&'a str], i: usize) -> Parsed<&'a str> {
    w.get(i).copied().ok_or_else(|| format!("missing field {i}"))
}

fn bytes_of(w: &[&str], i: usize) -> Parsed<Vec<u8>> {
    let token = word(w, i)?;
    if token == "-" {
        return Ok(Vec::new());
    }
    from_hex(token).ok_or_else(|| format!("bad hex: {token}"))
}

// The top of each number field: a number is decimal digits only (no sign, space or `_`; `parse` would take a `+`) and at
// most its top; no digit string wraps or overflows into another value.
const BYTE: u64 = 255;
const LENGTH: u64 = 65535;
const EPOCH: u64 = 4294967295;

fn num<T: TryFrom<u64>>(w: &[&str], i: usize, top: u64) -> Parsed<T> {
    let token = word(w, i)?;
    let bad = || format!("bad number: {token} (digits of 0 to {top})");
    if token.is_empty() {
        return Err(bad());
    }
    let mut n = 0u64;
    for c in token.bytes() {
        if !c.is_ascii_digit() {
            return Err(bad());
        }
        n = n * 10 + u64::from(c - b'0');
        if n > top {
            return Err(bad());
        }
    }
    T::try_from(n).map_err(|_| bad())
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
fn loaded(w: &[&str]) -> Parsed<(FrameDirections, usize)> {
    let digits = w.get(9).copied().unwrap_or("123");
    let size = if w.len() > 10 { num(w, 10, LENGTH)? } else { 300 };
    let mut set = FrameDirections::NONE;
    for digit in digits.chars() {
        let d = digit.to_digit(10).map(|d| d as usize).and_then(direction);
        set = set.with(d.ok_or_else(|| format!("bad dirs: {digits}"))?);
    }
    Ok((set, size))
}

// A key that is not 32 bytes and a msg_id that is not 8 bytes cannot be handed to the package (`&[u8; 32]`, `[u8; 8]`): the
// refusal is the type, so `None` is the BadValue of the package, as for a direction (fixtures/frame/README.md).
fn key32(raw: &[u8]) -> Option<&[u8; 32]> {
    raw.try_into().ok()
}

fn msg_id8(raw: &[u8]) -> Option<[u8; 8]> {
    raw.try_into().ok()
}

fn seal(w: &[&str]) -> Parsed<String> {
    let key = bytes_of(w, 0)?;
    let epoch: u32 = num(w, 1, EPOCH)?;
    let d: usize = num(w, 2, BYTE)?;
    let tag_len: u8 = num(w, 3, BYTE)?;
    let id = bytes_of(w, 4)?;
    let kind: u8 = num(w, 5, BYTE)?;
    let ad = bytes_of(w, 6)?;
    let clear = bytes_of(w, 7)?;
    let plain = bytes_of(w, 8)?;
    let (directions, size) = loaded(w)?;
    let (Some(key), Some(id)) = (key32(&key), msg_id8(&id)) else {
        return Ok("BadValue".into());
    };
    let session = match FrameSession::load_frame(
        key,
        epoch,
        FrameConfig {
            tag_len,
            directions,
        },
    ) {
        Ok(s) => s,
        Err(f) => return Ok(fault_kind(&f).into()),
    };
    let Some(dir) = direction(d) else {
        return Ok("BadValue".into());
    };
    let mut out = vec![0u8; size];
    Ok(
        match session.seal_frame(dir, &MsgContext { msg_id: id, kind }, &ad, &clear, &plain, &mut out) {
            Ok(n) => hex_of(&out[..n]),
            Err(f) => fault_kind(&f).into(),
        },
    )
}

fn open(w: &[&str]) -> Parsed<String> {
    let key = bytes_of(w, 0)?;
    let epoch: u32 = num(w, 1, EPOCH)?;
    let d: usize = num(w, 2, BYTE)?;
    let tag_len: u8 = num(w, 3, BYTE)?;
    let id = bytes_of(w, 4)?;
    let kind: u8 = num(w, 5, BYTE)?;
    let ad = bytes_of(w, 6)?;
    let clear_len: usize = num(w, 7, LENGTH)?;
    let body = bytes_of(w, 8)?;
    let (directions, size) = loaded(w)?;
    let (Some(key), Some(id)) = (key32(&key), msg_id8(&id)) else {
        return Ok("BadValue".into());
    };
    let session = match FrameSession::load_frame(
        key,
        epoch,
        FrameConfig {
            tag_len,
            directions,
        },
    ) {
        Ok(s) => s,
        Err(f) => return Ok(fault_kind(&f).into()),
    };
    let Some(dir) = direction(d) else {
        return Ok("BadValue".into());
    };
    let mut out = vec![0u8; size];
    Ok(
        match session.open_frame(dir, &MsgContext { msg_id: id, kind }, &ad, &body, clear_len, None, &mut out) {
            Ok(opened) => hex_of(&out[..opened.plain_len]),
            Err(f) => fault_kind(&f).into(),
        },
    )
}

fn mac(w: &[&str]) -> Parsed<String> {
    let key = bytes_of(w, 0)?;
    let epoch: u32 = num(w, 1, EPOCH)?;
    let label = bytes_of(w, 2)?;
    let n: usize = num(w, 3, BYTE)?;
    let message = bytes_of(w, 4)?;
    let Some(key) = key32(&key) else {
        return Ok("BadValue".into());
    };
    let mk = match MacKey::derive(key, epoch, &label) {
        Ok(m) => m,
        Err(f) => return Ok(fault_kind(&f).into()),
    };
    let mut out = vec![0u8; n];
    Ok(match mk.tag(&[&message], &mut out) {
        Ok(()) => hex_of(&out),
        Err(f) => fault_kind(&f).into(),
    })
}

fn verify(w: &[&str]) -> Parsed<String> {
    let key = bytes_of(w, 0)?;
    let epoch: u32 = num(w, 1, EPOCH)?;
    let label = bytes_of(w, 2)?;
    let _n: usize = num(w, 3, BYTE)?;
    let message = bytes_of(w, 4)?;
    let tag = bytes_of(w, 5)?;
    let Some(key) = key32(&key) else {
        return Ok("BadValue".into());
    };
    let mk = match MacKey::derive(key, epoch, &label) {
        Ok(m) => m,
        Err(f) => return Ok(fault_kind(&f).into()),
    };
    Ok(if mk.verify(&[&message], &tag) {
        "valid".into()
    } else {
        "invalid".into()
    })
}

fn frame_line(words: &[&str]) -> Parsed<String> {
    match words[0] {
        "seal" => seal(&words[1..]),
        "open" => open(&words[1..]),
        "mac" => mac(&words[1..]),
        "verify" => verify(&words[1..]),
        "open-skip" | "verify-skip" => Ok("skip".into()),
        other => Err(format!("unknown word {other}")),
    }
}

pub fn run(args: &[String]) -> u8 {
    if args.len() == 2 && args[0] == "frame-batch" {
        let file = match std::fs::File::open(&args[1]) {
            Ok(f) => f,
            Err(e) => {
                eprintln!("frame-batch: {e}");
                return 1;
            }
        };
        for (index, line) in BufReader::new(file).lines().enumerate() {
            let text = match line {
                Ok(t) => t,
                Err(e) => {
                    eprintln!("frame line {}: {e}", index + 1);
                    return 1;
                }
            };
            let words: Vec<&str> = text.split_whitespace().collect();
            if words.is_empty() {
                continue;
            }
            match frame_line(&words) {
                Ok(out) => println!("{out}"),
                Err(e) => {
                    eprintln!("frame line {}: {e}", index + 1);
                    return 1;
                }
            }
        }
        return 0;
    }
    2
}
