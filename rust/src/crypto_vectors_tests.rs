use crate::session_core::hkdf::{derive, hmac_sha256_of};
use crate::session_core::pad::{block_of, xor_with_nonce};
use crate::session_core::sha256::{hash, Sha256};

// AZ-3201: every row of fixtures/crypto/vectors.txt (sha256, hmac256, hkdf256, chacha-block, chacha-xor) against
// the private primitives of session_core.

const VECTORS: &str = concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../fixtures/crypto/vectors.txt"
);

struct Row<'a> {
    kind: &'a str,
    id: &'a str,
    fields: Vec<(&'a str, &'a str)>,
}

impl<'a> Row<'a> {
    fn text(&self, name: &str) -> &'a str {
        self.fields
            .iter()
            .find(|(field, _)| *field == name)
            .map(|(_, value)| *value)
            .unwrap_or_else(|| panic!("{} {} has no {name}", self.kind, self.id))
    }

    fn has(&self, name: &str) -> bool {
        self.fields.iter().any(|(field, _)| *field == name)
    }

    fn bytes(&self, name: &str) -> Vec<u8> {
        from_hex(self.text(name))
    }

    fn number(&self, name: &str) -> usize {
        self.text(name).parse().expect("number")
    }

    fn array<const N: usize>(&self, name: &str) -> [u8; N] {
        self.bytes(name).try_into().expect("field length")
    }
}

fn from_hex(hex: &str) -> Vec<u8> {
    if hex == "-" {
        return Vec::new();
    }
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).expect("hex"))
        .collect()
}

fn parse(text: &str) -> Vec<Row<'_>> {
    text.lines()
        .filter(|line| !line.is_empty() && !line.starts_with('#'))
        .map(|line| {
            let mut parts = line.split(' ');
            let kind = parts.next().expect("kind");
            let id = parts.next().expect("source");
            let fields = parts
                .map(|part| part.split_once('=').expect("field is name=value"))
                .collect();
            Row { kind, id, fields }
        })
        .collect()
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn sha256_row(row: &Row) -> bool {
    let message = if row.has("msg") {
        row.bytes("msg")
    } else {
        vec![row.array::<1>("byte")[0]; row.number("repeat")]
    };
    let mut pieces = Sha256::new();
    for piece in message.chunks(37) {
        pieces.update(piece);
    }
    let digest = hex(&hash(&message));
    digest == row.text("digest") && hex(&pieces.finish()) == digest
}

fn hmac_row(row: &Row) -> bool {
    let mac = hmac_sha256_of(&row.bytes("key"), &row.bytes("data"));
    let keep = if row.has("truncate") {
        row.number("truncate")
    } else {
        mac.len()
    };
    hex(&mac[..keep]) == row.text("mac")
}

fn hkdf_row(row: &Row) -> bool {
    let (ikm, salt, info) = (row.bytes("ikm"), row.bytes("salt"), row.bytes("info"));
    let mut okm = vec![0u8; row.number("len")];
    derive(&ikm, &salt, &info, &mut okm);
    hex(&hmac_sha256_of(&salt, &ikm)) == row.text("prk") && hex(&okm) == row.text("okm")
}

fn chacha_block_row(row: &Row) -> bool {
    let block = block_of(
        &row.array("key"),
        &row.array("nonce"),
        row.number("counter") as u32,
    );
    hex(&block) == row.text("block")
}

/// The cipher through the block, and through the crate's own `xor_with_nonce` (frame mode's cipher) when the
/// row starts at block counter 0, the only counter that call starts from.
fn chacha_xor_row(row: &Row) -> bool {
    let key: [u8; 32] = row.array("key");
    let nonce: [u8; 12] = row.array("nonce");
    let counter = row.number("counter") as u32;
    let mut data = row.bytes("plain");
    let mut by_xor = data.clone();
    for (i, chunk) in data.chunks_mut(64).enumerate() {
        let pad = block_of(&key, &nonce, counter + i as u32);
        for (byte, mask) in chunk.iter_mut().zip(pad) {
            *byte ^= mask;
        }
    }
    let expected = row.text("cipher");
    if counter == 0 {
        xor_with_nonce(&key, &nonce, &mut by_xor);
        if hex(&by_xor) != expected {
            return false;
        }
    }
    hex(&data) == expected
}

/// The `kind id` of every row of `kind` in `text` whose recomputation differs from the expected bytes.
fn failing(text: &str, kind: &str) -> Vec<String> {
    let rows: Vec<Row> = parse(text).into_iter().filter(|r| r.kind == kind).collect();
    assert!(!rows.is_empty(), "no {kind} rows");
    rows.iter()
        .filter(|row| !match kind {
            "sha256" => sha256_row(row),
            "hmac256" => hmac_row(row),
            "hkdf256" => hkdf_row(row),
            "chacha-block" => chacha_block_row(row),
            "chacha-xor" => chacha_xor_row(row),
            other => panic!("unknown primitive {other}"),
        })
        .map(|row| format!("{} {}", row.kind, row.id))
        .collect()
}

fn vectors() -> String {
    std::fs::read_to_string(VECTORS).expect("vectors file")
}

#[test]
fn every_sha256_row_matches() {
    // Arrange
    let text = vectors();

    // Act
    let bad = failing(&text, "sha256");

    // Assert
    assert!(bad.is_empty(), "mismatched rows: {bad:?}");
}

#[test]
fn every_hmac256_row_matches() {
    // Arrange
    let text = vectors();

    // Act
    let bad = failing(&text, "hmac256");

    // Assert
    assert!(bad.is_empty(), "mismatched rows: {bad:?}");
}

#[test]
fn every_hkdf256_row_matches() {
    // Arrange
    let text = vectors();

    // Act
    let bad = failing(&text, "hkdf256");

    // Assert
    assert!(bad.is_empty(), "mismatched rows: {bad:?}");
}

#[test]
fn every_chacha_row_matches() {
    // Arrange
    let text = vectors();

    // Act
    let mut bad = failing(&text, "chacha-block");
    bad.extend(failing(&text, "chacha-xor"));

    // Assert
    assert!(bad.is_empty(), "mismatched rows: {bad:?}");
}

/// A copy of `text` with the last hex digit of `field` changed in the first row of `kind`, and that row's id.
fn corrupt_first(text: &str, kind: &str, field: &str) -> (String, String) {
    let mut done: Option<String> = None;
    let lines: Vec<String> = text
        .lines()
        .map(|line| {
            let mut parts: Vec<String> = line.split(' ').map(str::to_string).collect();
            if done.is_none() && parts[0] == kind {
                if let Some(part) = parts
                    .iter_mut()
                    .find(|p| p.starts_with(&format!("{field}=")))
                {
                    let last = part.pop().expect("digit");
                    part.push(if last == '0' { '1' } else { '0' });
                    done = Some(format!("{kind} {}", parts[1]));
                }
            }
            parts.join(" ")
        })
        .collect();
    (lines.join("\n"), done.expect("a row to corrupt"))
}

#[test]
fn one_changed_expected_byte_in_each_primitive_names_its_row() {
    // Arrange
    let text = vectors();
    let cases = [
        ("sha256", "digest"),
        ("hmac256", "mac"),
        ("hkdf256", "okm"),
        ("hkdf256", "prk"),
        ("chacha-block", "block"),
        ("chacha-xor", "cipher"),
    ];

    for (kind, field) in cases {
        let (corrupted, id) = corrupt_first(&text, kind, field);

        // Act
        let bad = failing(&corrupted, kind);

        // Assert
        assert_eq!(bad, vec![id], "{kind} {field}");
    }
}
