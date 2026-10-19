// The message ECC commands of the handoff driver (AZ-2689; contract message-ecc.md).
//
//   ecc-protect <n> <clear hex>   prints the clear position message packed again with n parity bytes, or the error kind
//   ecc-repair <n> <t> <hex>      prints the position message repaired (hex, then the repaired count), or the error kind
//   ecc-batch <file>              one line per line of the file: `protect <n> <hex>` or `repair <n> <t> <hex>`
//
// "-" is the empty buffer. The kind names are the ones of fixtures/ecc/vectors.txt (uncorrectable, short, too_long,
// bad_parity, bad_limit) plus trailing, type_mismatch and unpack_failed for the walk of the unprotected fields.
use super::{from_hex, position_scheme, Position};
use packbin::{to_hex, BinaryPacker, Scheme, UnpackError};
use std::panic::catch_unwind;

fn bytes_of(token: &str) -> Option<Vec<u8>> {
    if token == "-" {
        Some(Vec::new())
    } else {
        from_hex(token)
    }
}

fn kind_of(error: &UnpackError) -> &'static str {
    match error {
        UnpackError::Uncorrectable => "uncorrectable",
        UnpackError::TooLong { .. } => "too_long",
        UnpackError::BadLimit { .. } => "bad_limit",
        UnpackError::BadParity { .. } => "bad_parity",
        UnpackError::Short(short) if short.field == "parity" => "short",
        UnpackError::Trailing { .. } => "trailing",
        UnpackError::Type { .. } => "type_mismatch",
        _ => "unpack_failed",
    }
}

// `with_parity` panics, naming n and 32, when n is above 32 (the scheme is not built).
fn protected_scheme(n: usize) -> Option<Scheme<Position>> {
    catch_unwind(|| position_scheme().with_parity(n)).ok()
}

fn protect(n: usize, clear: &[u8]) -> String {
    let position = position_scheme();
    let mut got = None;
    if BinaryPacker::unpack_with(clear, &mut [&mut position.on(|row| got = Some(row))]).is_err() {
        return "unpack_failed".into();
    }
    let Some(row) = got else {
        return "unpack_failed".into();
    };
    let Some(scheme) = protected_scheme(n) else {
        return "bad_parity".into();
    };
    match BinaryPacker::pack(&scheme, &row) {
        Ok(bytes) => to_hex(&bytes),
        Err(_) => "pack_error".into(),
    }
}

fn repair(n: usize, t: usize, received: &[u8]) -> String {
    let Some(scheme) = protected_scheme(n) else {
        return "bad_parity".into();
    };
    let mut got = None;
    let repaired =
        BinaryPacker::unpack_with_repair(received, &mut [&mut scheme.on(|row| got = Some(row))], t);
    match (repaired, got) {
        (Ok(count), Some(row)) => match BinaryPacker::pack(&position_scheme(), &row) {
            Ok(bytes) => format!("{} {count}", to_hex(&bytes)),
            Err(_) => "pack_error".into(),
        },
        (Ok(_), None) => "unpack_failed".into(),
        (Err(error), _) => kind_of(&error).into(),
    }
}

fn line(words: &[&str]) -> Option<String> {
    match words {
        ["protect", n, hex] => Some(protect(n.parse().ok()?, &bytes_of(hex)?)),
        ["repair", n, t, hex] => Some(repair(n.parse().ok()?, t.parse().ok()?, &bytes_of(hex)?)),
        _ => None,
    }
}

// Returns the exit status of an ecc command.
pub fn run(args: &[String]) -> u8 {
    // A refused n panics inside with_parity and is caught and reported as bad_parity: the default hook would also
    // print that panic to stderr.
    std::panic::set_hook(Box::new(|_| {}));
    let words: Vec<&str> = args.iter().map(String::as_str).collect();
    match words.as_slice() {
        ["ecc-protect", n, hex] => print_line(&["protect", n, hex]),
        ["ecc-repair", n, t, hex] => print_line(&["repair", n, t, hex]),
        ["ecc-batch", file] => {
            let Ok(text) = std::fs::read_to_string(file) else {
                eprintln!("ecc-batch: cannot read {file}");
                return 1;
            };
            for text_line in text.lines().filter(|l| !l.trim().is_empty()) {
                let parts: Vec<&str> = text_line.split_whitespace().collect();
                if print_line(&parts) != 0 {
                    return 1;
                }
            }
            0
        }
        _ => 2,
    }
}

fn print_line(words: &[&str]) -> u8 {
    match line(words) {
        Some(out) => {
            println!("{out}");
            0
        }
        None => {
            eprintln!("ecc line: {}", words.join(" "));
            1
        }
    }
}
