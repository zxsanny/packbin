#![cfg(feature = "std")]
use packbin::{times, u32, u8, unpack, MapScheme, ShortPacket, UnpackError, Value};

// AZ-2435 (assessment22 gap G1, AZ-2415 AC-3): the default `maxSlots` fell from 4 194 304 to
// 1 048 576; a scheme whose limits are raised back to 4 194 304 slots still unpacks the old worst
// packet (`u32 n; times(n) { 64 u8 }`, 65 535 rounds, 4 194 240 slots), and the default limits
// refuse it. The crate has no slow-test marker; the raised-limit test allocates a few hundred MB
// (loop 22 timing flakes came only under host load).

/// `u32 n; times(n) { u8 k0 .. u8 k63 }`
fn sixty_four_wide() -> MapScheme {
    let body = (0..64).map(|i| u8(format!("k{i}"))).collect();
    MapScheme::new(1, vec![u32("n"), times(1, "n", body)])
}

/// Type byte, `n` = 65 535, then 65 535 rounds of 64 bytes, all `01`.
fn old_worst_packet() -> Vec<u8> {
    let mut raw = vec![1u8; 1 + 4 + 65_535 * 64];
    raw[1..5].copy_from_slice(&65_535u32.to_le_bytes());
    raw
}

#[test]
fn ac1_with_max_slots_raised_to_4_194_304_the_old_worst_packet_unpacks() {
    // Arrange
    let scheme = sixty_four_wide().with_limits(65_535, 4_194_304);
    let raw = old_worst_packet();

    // Act
    let values = unpack(&scheme, &raw).expect("unpack under the raised limits");

    // Assert: `n`, 65 535 rounds of 64 ones, and a list of 65 535 ones per name
    assert_eq!(values.get("n"), Some(&Some(Value::U32(65_535))));
    let Some(Some(Value::Groups(rounds))) = values.get("__times_1") else {
        panic!("no rounds under __times_1");
    };
    assert_eq!(rounds.len(), 65_535);
    assert!(rounds
        .iter()
        .all(|round| round.len() == 64 && round.values().all(|x| x == &Some(Value::U8(1)))));
    for i in 0..64 {
        let Some(Some(Value::List(items))) = values.get(format!("k{i}").as_str()) else {
            panic!("no list for k{i}");
        };
        assert_eq!(items.len(), 65_535, "k{i}");
        assert!(items.iter().all(|x| x == &Value::U8(1)), "k{i}");
    }
    assert_eq!(values.len(), 66);
}

#[test]
fn ac2_the_default_limits_refuse_the_same_packet_at_the_slot_limit() {
    // Arrange
    let raw = old_worst_packet();

    // Act
    let result = unpack(&sixty_four_wide(), &raw);

    // Assert: round 16 385 crosses 1 048 576 slots; 49 151 rounds (3 145 664 bytes) stay unread
    assert_eq!(
        result,
        Err(UnpackError::Short(ShortPacket {
            field: "times".to_string(),
            needed: 0,
            left: 3_145_664
        }))
    );
}
