//! The one wipe of key material in the crate (AZ-3275): a volatile write per element, which the compiler
//! may not remove as a dead store, then a compiler fence, so the writes are not moved after the code that
//! follows. It does not reach copies the compiler made by moving a value or returning it by value (L73-1),
//! nor values the compiler keeps in registers or spills (the SHA-256 working words).
use core::sync::atomic::{compiler_fence, Ordering};

/// Overwrites every element of `items` with zero (`T::default()`).
pub(crate) fn wipe<T: Copy + Default>(items: &mut [T]) {
    for item in items.iter_mut() {
        // SAFETY: `item` is a unique reference to an initialised, aligned `T`, so the pointer made from
        // it is valid for one write; `T: Copy` has no drop glue, so overwriting the old value is sound.
        unsafe { core::ptr::write_volatile(item, T::default()) };
    }
    compiler_fence(Ordering::SeqCst);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wipe_zeroes_bytes_and_words() {
        // Arrange
        let mut bytes = [0xA5u8; 64];
        let mut words = [0xA5A5_A5A5u32; 16];

        // Act
        wipe(&mut bytes);
        wipe(&mut words);

        // Assert
        assert_eq!(bytes, [0u8; 64]);
        assert_eq!(words, [0u32; 16]);
    }
}
