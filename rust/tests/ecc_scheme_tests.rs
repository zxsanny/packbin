mod ecc_support;

use ecc_support::{corrupt, from_hex, position_row, position_scheme, PositionRow, Rng, FIXTURE};
use packbin::{
    bytes, insert, pack, to_hex, u8, unpack, unpack_repair, utf8, BinaryPacker, MapScheme,
    PackError, ShortPacket, UnpackError, Value, Values, MAX_PARITY,
};
use std::panic::catch_unwind;

// AZ-2684: the scheme parity setting, pack with parity and unpack with repair, against the position rows 1 to 14
// of _docs/02_task_plans/message-error-correction/input_data/expected_results/results_report.md.

fn pack_position(parity: usize) -> Vec<u8> {
    BinaryPacker::pack(&position_scheme(0x40, parity), &position_row()).expect("pack")
}

fn read_position(
    received: &[u8],
    parity: usize,
    limit: usize,
) -> Result<(PositionRow, usize), UnpackError> {
    let scheme = position_scheme(0x40, parity);
    let mut got = None;
    let repaired = BinaryPacker::unpack_with_repair(
        received,
        &mut [&mut scheme.on(|r| got = Some(r))],
        limit,
    )?;
    Ok((got.expect("handler ran"), repaired))
}

fn blob_scheme(len: usize, parity: usize) -> MapScheme {
    MapScheme::new(1, vec![bytes("b", len)]).with_parity(parity)
}

fn blob_values(len: usize) -> Values {
    let mut values = Values::new();
    insert(&mut values, "b", Some(Value::Bytes(vec![7; len])));
    values
}

#[test]
fn ec1_row1_n0_packs_to_the_golden_bytes_and_reads_back() {
    // Arrange
    let golden = from_hex(FIXTURE);

    // Act
    let packed = pack_position(0);
    let read = read_position(&golden, 0, 0);

    // Assert
    assert_eq!(packed, golden);
    assert_eq!(read, Ok((position_row(), 0)));
}

#[test]
fn ec2_rows_2_to_6_pack_to_the_protected_bytes() {
    // Arrange
    let rows = [
        (1, "4001000065cd1d00a3e1110100ab"),
        (2, "4001000065cd1d00a3e111010016bd"),
        (4, "4001000065cd1d00a3e1110100ca856682"),
        (8, "4001000065cd1d00a3e11101006d4f38479f3f2472"),
        (
            16,
            "4001000065cd1d00a3e11101004ace66ecd5e4a28ffa28098279f5f19d",
        ),
    ];

    for (n, hex) in rows {
        // Act
        let packed = pack_position(n);

        // Assert
        assert_eq!(to_hex(&packed), hex, "n {n}");
        assert_eq!(packed.len(), 13 + n);
        assert_eq!(
            read_position(&packed, n, 0),
            Ok((position_row(), 0)),
            "n {n}"
        );
    }
}

#[test]
fn ec3_row14_n33_fails_when_the_scheme_is_built_naming_n_and_32() {
    // Arrange and Act
    let typed = catch_unwind(|| position_scheme(0x40, 33));
    let map = catch_unwind(|| MapScheme::new(1, vec![u8("a")]).with_parity(33));

    // Assert
    for built in [typed.err(), map.err()] {
        let text = built
            .expect("refused")
            .downcast_ref::<String>()
            .cloned()
            .unwrap_or_default();
        assert!(
            text.contains("33") && text.contains(&MAX_PARITY.to_string()),
            "{text}"
        );
    }
    assert!(catch_unwind(|| position_scheme(0x40, 32)).is_ok());
}

#[test]
fn ec5_row7_one_wrong_bit_is_repaired_and_counted() {
    // Arrange
    let received = from_hex("4001000065cc1d00a3e111010016bd");

    // Act
    let read = read_position(&received, 2, 1);

    // Assert
    assert_eq!(read, Ok((position_row(), 1)));
}

#[test]
fn ec5_row8_two_wrong_bytes_are_repaired_with_limit_2() {
    // Arrange
    let received = from_hex("40015a0065cd1d00a322110100ca856682");

    // Act
    let read = read_position(&received, 4, 2);

    // Assert
    assert_eq!(read, Ok((position_row(), 2)));
}

#[test]
fn ec6_rows_9_and_10_two_wrong_bytes_beyond_the_limit_give_uncorrectable_and_no_row() {
    // Arrange
    let received = from_hex("40015a0065cd1d00a322110100ca856682");

    for limit in [1, 0] {
        // Act
        let read = read_position(&received, 4, limit);

        // Assert
        assert_eq!(read, Err(UnpackError::Uncorrectable), "limit {limit}");
    }
}

#[test]
fn ec8_row11_an_intact_message_reports_0_repaired() {
    // Arrange
    let received = from_hex("4001000065cd1d00a3e1110100ca856682");

    // Act
    let read = read_position(&received, 4, 2);

    // Assert
    assert_eq!(read, Ok((position_row(), 0)));
}

#[test]
fn ec8_row12_three_bytes_with_n4_name_the_parity_4_needed_3_present() {
    // Arrange
    let received = from_hex("400100");

    // Act
    let read = read_position(&received, 4, 2);

    // Assert
    let short = ShortPacket {
        field: "parity".into(),
        needed: 4,
        left: 3,
    };
    assert_eq!(read, Err(UnpackError::Short(short)));
}

#[test]
fn ec8_a_limit_above_half_n_is_refused_before_any_byte_is_read() {
    // Arrange: an empty buffer would otherwise be a short read

    // Act
    let read = read_position(&[], 4, 3);
    let off = read_position(&[], 0, 1);

    // Assert
    assert_eq!(read, Err(UnpackError::BadLimit { limit: 3, max: 2 }));
    assert_eq!(off, Err(UnpackError::BadLimit { limit: 1, max: 0 }));
}

#[test]
fn ec4_row13_a_251_byte_clear_message_with_n4_is_refused_naming_251_and_250() {
    // Arrange: the type byte and 250 bytes make 251 clear bytes
    let scheme = blob_scheme(250, 4);

    // Act
    let refused = pack(&scheme, &blob_values(250));

    // Assert
    match refused {
        Err(PackError::Type(text)) => {
            assert!(
                text.contains("251") && text.contains("limit of 250 bytes"),
                "{text}"
            )
        }
        other => panic!("expected the size refusal, got {other:?}"),
    }
    assert_eq!(
        pack(&blob_scheme(249, 4), &blob_values(249))
            .expect("250 bytes")
            .len(),
        254
    );
}

#[test]
fn ec4_with_n32_a_222_byte_clear_message_packs_and_a_223_byte_one_is_refused() {
    // Arrange
    let ok = blob_scheme(221, 32);
    let too_long = blob_scheme(222, 32);

    // Act
    let packed = pack(&ok, &blob_values(221));
    let refused = pack(&too_long, &blob_values(222));

    // Assert
    assert_eq!(packed.expect("222 bytes").len(), 254);
    match refused {
        Err(PackError::Type(text)) => {
            assert!(
                text.contains("223") && text.contains("limit of 222 bytes"),
                "{text}"
            )
        }
        other => panic!("expected the size refusal, got {other:?}"),
    }
}

#[test]
fn ec4_a_buffer_above_254_bytes_is_too_long_with_no_values() {
    // Arrange
    let scheme = blob_scheme(100, 4);

    // Act
    let read = unpack(&scheme, &vec![1u8; 255]);

    // Assert
    assert_eq!(
        read,
        Err(UnpackError::TooLong {
            len: 255,
            limit: 254
        })
    );
}

#[test]
fn ec1_a_scheme_without_parity_reads_a_protected_message_as_trailing_bytes() {
    // Arrange
    let protected = pack_position(4);

    // Act
    let read = read_position(&protected, 0, 0);

    // Assert
    assert_eq!(read, Err(UnpackError::Trailing { left: 4 }));
}

#[test]
fn ec14_the_unprotected_message_read_with_n4_is_refused() {
    // Arrange
    let unprotected = pack_position(0);

    // Act
    let read = read_position(&unprotected, 4, 0);

    // Assert
    assert_eq!(read, Err(UnpackError::Uncorrectable));
}

#[test]
fn ec5_the_map_level_calls_repair_and_report_the_count() {
    // Arrange
    let scheme = MapScheme::new(0x40, vec![u8("a"), u8("b")]).with_parity(4);
    let mut values = Values::new();
    insert(&mut values, "a", Some(Value::U8(7)));
    insert(&mut values, "b", Some(Value::U8(9)));
    let mut sent = pack(&scheme, &values).expect("pack");
    sent[2] ^= 0x55;

    // Act
    let detect = unpack(&scheme, &sent);
    let (repaired_values, count) = unpack_repair(&scheme, &sent, 2).expect("repair");

    // Assert
    assert_eq!(detect.err(), Some(UnpackError::Uncorrectable));
    assert_eq!(count, 1);
    assert_eq!(repaired_values["b"], Some(Value::U8(9)));
}

#[test]
fn ec11_a_compact_text_field_in_a_protected_message_survives_any_2_wrong_bytes() {
    // Arrange
    let scheme = MapScheme::new(1, vec![u8("lead"), utf8("s"), u8("tail")]).with_parity(4);
    let text = "Привіт, світе! Слава Україні";
    let mut values = Values::new();
    insert(&mut values, "lead", Some(Value::U8(3)));
    insert(&mut values, "s", Some(Value::Str(text.into())));
    insert(&mut values, "tail", Some(Value::U8(250)));
    let sent = pack(&scheme, &values).expect("pack");
    let mut rng = Rng(0xEC11);

    for case in 0..2000 {
        let mut word = sent.clone();
        corrupt(&mut word, 1 + case % 2, None, &mut rng);

        // Act
        let (got, repaired) = unpack_repair(&scheme, &word, 2).expect("repair");

        // Assert
        assert_eq!(got["s"], Some(Value::Str(text.into())), "case {case}");
        assert_eq!(
            (got["lead"].clone(), got["tail"].clone()),
            (Some(Value::U8(3)), Some(Value::U8(250)))
        );
        assert_eq!(repaired, 1 + case % 2);
    }
}

#[test]
fn ec11_a_text_with_a_flipped_bit_in_every_byte_is_never_a_different_string() {
    // Arrange
    let scheme = MapScheme::new(1, vec![utf8("s")]).with_parity(4);
    let mut values = Values::new();
    insert(&mut values, "s", Some(Value::Str("Київ".into())));
    let sent = pack(&scheme, &values).expect("pack");

    for p in 0..sent.len() {
        for bit in 0..8 {
            let mut word = sent.clone();
            word[p] ^= 1 << bit;

            // Act
            let read = unpack_repair(&scheme, &word, 2).map(|(v, _)| v["s"].clone());

            // Assert
            assert_eq!(
                read,
                Ok(Some(Value::Str("Київ".into()))),
                "byte {p} bit {bit}"
            );
        }
    }
}

#[test]
fn hostile_random_buffers_never_panic_at_any_n_and_limit() {
    // Arrange
    let mut rng = Rng(0xBAD6);
    let schemes: Vec<MapScheme> = [0usize, 1, 2, 4, 8, 16, 32]
        .iter()
        .map(|&n| MapScheme::new(0x40, vec![u8("a"), utf8("s"), u8("b")]).with_parity(n))
        .collect();

    for _ in 0..20_000 {
        let scheme = &schemes[rng.below(schemes.len())];
        let limit = rng.below(scheme.parity() / 2 + 1);
        let len = rng.below(260);
        let mut word: Vec<u8> = (0..len).map(|_| rng.byte()).collect();
        if !word.is_empty() && rng.below(2) == 0 {
            word[0] = 0x40;
        }

        // Act
        let read = unpack_repair(scheme, &word, limit);

        // Assert
        if let Ok((_, repaired)) = read {
            assert!(repaired <= limit);
        }
    }
}
