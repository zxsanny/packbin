use crate::ecc::{append, unprotect};
use crate::UnpackError;

// Review cleanup of loop 38 (AZ-2695): the post-repair re-verify has its own tests. These buffers are not within
// t wrong bytes of a code word, yet the locator has as many roots among the sent positions as its degree and the
// evaluator gives a value for each, so fixing those bytes does not make a code word. Found by a seeded search of
// random buffers with the re-verify taken out; only the re-verify refuses them.

const CASES: [(&str, usize, usize); 5] = [
    ("a0d9a39d753edd405b01e23923", 4, 1),
    ("74fee0ce9393f2efc4ba", 4, 2),
    ("9f079ddc735948b71b6b82f2", 4, 2),
    ("3064be1b784579317feab3b6", 6, 2),
    ("8fc70a7d13312fe2e8ceb62ee33ec711f3e8", 6, 3),
];

fn from_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).expect("hex"))
        .collect()
}

/// splitmix64: a seeded stream, the same on every run.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
}

#[test]
fn a_fixed_word_that_is_not_a_code_word_is_refused_not_returned() {
    for (hex, n, t) in CASES {
        // Arrange
        let received = from_hex(hex);

        // Act
        let result = unprotect(&received, n, t);

        // Assert
        assert_eq!(
            result.map(|(b, c)| (b.into_owned(), c)),
            Err(UnpackError::Uncorrectable),
            "{hex} n {n} t {t}"
        );
    }
}

#[test]
fn a_word_it_returns_is_one_the_packer_could_have_sent() {
    // Arrange: random buffers at n 4, t 2; the ones the decoder accepts must repack to a word that differs from
    // the received one in exactly the bytes it reports.
    let mut rng = Rng(20_261_018);
    let mut accepted = 0;

    for _ in 0..300_000 {
        let len = 5 + (rng.next() % 15) as usize;
        let received: Vec<u8> = (0..len).map(|_| rng.next() as u8).collect();

        // Act
        let Ok((clear, repaired)) = unprotect(&received, 4, 2) else {
            continue;
        };
        if repaired == 0 {
            continue;
        }
        accepted += 1;
        let mut word = clear.into_owned();
        append(&mut word, 4).expect("room");

        // Assert
        let wrong = word.iter().zip(&received).filter(|(a, b)| a != b).count();
        assert_eq!(wrong, repaired, "received {received:02x?}");
    }
    assert!(accepted > 0, "no buffer was repaired: the sweep proved nothing");
}
