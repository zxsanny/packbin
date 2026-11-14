//! AZ-4308: a `times` or `repeat` whose body is nested more than 256 levels is refused when the
//! field is built, before the width of the round is counted (that walk recurses over the body).
//! Measured before the change (release and debug, 2 MiB test thread): a body of 1,000 and 5,000
//! `when`s built; one of 50,000 overflowed the stack (SIGABRT) in `times` and in `repeat`.
#![cfg(feature = "std")]

use packbin::{eq, repeat, times, u8, when, Field, MapScheme, Value};
use std::panic::catch_unwind;
use std::time::{Duration, Instant};

const TEXT: &str = "scheme nested too deep: more than 256 levels; the limit is 256";

/// (the ids of a round body start at its `times` anchor, so its first `when` is 2) `u8 "a"`, then `depth` nested `when`s over `u8 "b"`, built by a loop: a round body of that depth.
fn when_chain(depth: usize) -> Vec<Field> {
    let mut chain = vec![u8("b")];
    for _ in 0..depth {
        chain = vec![when(2, eq("a", Value::U8(1)), chain)];
    }
    let mut body = vec![u8("a")];
    body.extend(chain);
    body
}

fn panic_text(panic: Box<dyn std::any::Any + Send>) -> String {
    match panic.downcast::<String>() {
        Ok(text) => *text,
        Err(other) => other
            .downcast_ref::<&str>()
            .map_or_else(String::new, |text| (*text).to_string()),
    }
}

fn refused(build: impl FnOnce() + std::panic::UnwindSafe) -> String {
    let started = Instant::now();
    let panic = catch_unwind(build).expect_err("the build must be refused");
    assert!(started.elapsed() < Duration::from_secs(5), "refused slowly");
    panic_text(panic)
}

#[test]
fn a_deep_times_body_is_refused_at_construction() {
    // AC-1: 1,000, 5,000 and 50,000 levels in one `times`
    for depth in [1_000, 5_000, 50_000] {
        // Arrange
        let body = when_chain(depth);

        // Act
        let text = refused(move || {
            times(1, "n", body);
        });

        // Assert
        assert_eq!(text, TEXT, "{depth}");
    }
}

#[test]
fn a_deep_repeat_body_is_refused_at_construction() {
    // AC-1: 1,000, 5,000 and 50,000 levels in one `repeat`
    for depth in [1_000, 5_000, 50_000] {
        // Arrange
        let body = when_chain(depth);

        // Act
        let text = refused(move || {
            repeat(1, body);
        });

        // Assert
        assert_eq!(text, TEXT, "{depth}");
    }
}

#[test]
fn a_chain_of_times_in_times_is_refused_while_it_is_built() {
    // AC-1: each constructor measures its body first, so the 257th level stops the loop
    // Arrange / Act
    let text = refused(|| {
        let mut body = vec![u8("b")];
        for _ in 0..50_000 {
            body = vec![times(1, "n", body)];
        }
    });

    // Assert
    assert_eq!(text, TEXT);
}

#[test]
fn a_body_of_256_levels_builds() {
    // AC-1 boundary: 256 levels in the body are allowed; the `times` around them is the 257th
    // level, which `MapScheme::new` refuses (the same text) as it does for every other kind
    // Arrange
    let body = when_chain(256);

    // Act
    let field = times(1, "n", body);
    let text = refused(move || {
        MapScheme::new(1, vec![u8("n"), field]);
    });

    // Assert
    assert_eq!(text, TEXT);
}

#[test]
fn a_body_of_255_levels_builds_and_the_scheme_is_accepted() {
    // AC-1 boundary: 255 levels in the body and the `times` make 256
    // Arrange
    let body = when_chain(255);

    // Act
    let built = catch_unwind(|| MapScheme::new(1, vec![u8("n"), times(1, "n", body)]));

    // Assert
    assert!(built.is_ok());
}
