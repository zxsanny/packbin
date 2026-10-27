#![cfg(feature = "std")]
use packbin::{
    eq, to_hex, BinaryPacker, BoundField, PackError, Scheme, SchemeItem, UnpackError, Value,
};

// AZ-2120 AC-3 / AC-4 / AC-5 for a typed `Scheme<T>`: a `when` or `times` that is a member of a
// `flags` is written like any other value. Hex strings come from the C# reference table. A typed
// scheme cannot hold a `repeat`, a group with members or a split flag byte, so those rows live in
// the map-API tests (`src/flags_when_member_tests.rs`, `src/flags_round_member_tests.rs`).

fn unpack_row<T: Default + 'static>(scheme: &Scheme<T>, bytes: &[u8]) -> Result<T, UnpackError> {
    let mut got = None;
    BinaryPacker::unpack_with(bytes, &mut [&mut scheme.on(|row| got = Some(row))])?;
    Ok(got.expect("handler ran"))
}

fn bytes(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).expect("hex"))
        .collect()
}

#[derive(Default, Debug, PartialEq, Clone)]
struct Motion {
    mode: u8,
    speed: Option<u8>,
    extra: Option<u8>,
    heading: Option<u16>,
}

fn motion(mode: u8, speed: Option<u8>, extra: Option<u8>, heading: Option<u16>) -> Motion {
    Motion {
        mode,
        speed,
        extra,
        heading,
    }
}

/// WA: `u8 mode; flags { when(mode == 1) { u8 speed }, u16 heading }`
fn wa() -> Scheme<Motion> {
    Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Motion| r.mode, |r, v| r.mode = v).into(),
            SchemeItem::flags(
                1,
                [
                    SchemeItem::when(
                        1,
                        eq(0u32, Value::U8(1)),
                        [BoundField::opt_u8(1, |r: &Motion| r.speed, |r, v| r.speed = v).into()],
                    ),
                    BoundField::opt_u16(2, |r: &Motion| r.heading, |r, v| r.heading = v).into(),
                ],
            ),
        ],
    )
}

/// W2: a `when` with two body values.
fn w2() -> Scheme<Motion> {
    Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Motion| r.mode, |r, v| r.mode = v).into(),
            SchemeItem::flags(
                1,
                [
                    SchemeItem::when(
                        1,
                        eq(0u32, Value::U8(1)),
                        [
                            BoundField::opt_u8(1, |r: &Motion| r.speed, |r, v| r.speed = v).into(),
                            BoundField::opt_u8(2, |r: &Motion| r.extra, |r, v| r.extra = v).into(),
                        ],
                    ),
                    BoundField::opt_u16(3, |r: &Motion| r.heading, |r, v| r.heading = v).into(),
                ],
            ),
        ],
    )
}

#[derive(Default, Debug, PartialEq, Clone)]
struct Pair {
    mode: Option<u8>,
    speed: Option<u8>,
}

fn pair(mode: Option<u8>, speed: Option<u8>) -> Pair {
    Pair { mode, speed }
}

/// WE: the `when` names an earlier member of the same `flags`.
fn we() -> Scheme<Pair> {
    Scheme::new(
        1,
        [SchemeItem::flags(
            0,
            [
                BoundField::opt_u8(0, |r: &Pair| r.mode, |r, v| r.mode = v).into(),
                SchemeItem::when(
                    1,
                    eq(0u32, Value::U8(1)),
                    [BoundField::opt_u8(1, |r: &Pair| r.speed, |r, v| r.speed = v).into()],
                ),
            ],
        )],
    )
}

fn round_trip<T: Default + PartialEq + std::fmt::Debug + 'static>(
    scheme: &Scheme<T>,
    row: &T,
    expected_hex: &str,
) -> T {
    let raw = BinaryPacker::pack(scheme, row).expect("pack");
    assert_eq!(to_hex(&raw), expected_hex);
    unpack_row(scheme, &raw).expect("unpack")
}

#[test]
fn ac3_typed_when_member_true_writes_its_body() {
    let row = motion(1, Some(7), None, Some(90));
    assert_eq!(round_trip(&wa(), &row, "010103075a00"), row);
}

#[test]
fn ac3_typed_when_member_false_leaves_its_bit_clear() {
    let row = motion(0, None, None, Some(90));
    assert_eq!(round_trip(&wa(), &row, "0100025a00"), row);
}

#[test]
fn ac3_typed_when_member_true_with_no_body_value_leaves_its_bit_clear() {
    let row = motion(1, None, None, Some(90));
    assert_eq!(round_trip(&wa(), &row, "0101025a00"), row);
}

#[test]
fn ac3_typed_when_member_false_drops_a_body_value_given_without_error() {
    let raw = BinaryPacker::pack(&wa(), &motion(0, Some(7), None, Some(90))).expect("pack");
    assert_eq!(to_hex(&raw), "0100025a00");
    assert_eq!(
        unpack_row(&wa(), &raw).expect("unpack"),
        motion(0, None, None, Some(90))
    );
}

#[test]
fn ac3_typed_when_member_alone_and_mode_alone() {
    let only_when = motion(1, Some(7), None, None);
    assert_eq!(round_trip(&wa(), &only_when, "01010107"), only_when);
    let only_mode = motion(0, None, None, None);
    assert_eq!(round_trip(&wa(), &only_mode, "010000"), only_mode);
}

#[test]
fn ac5_typed_old_and_new_packets_unpack() {
    assert_eq!(
        unpack_row(&wa(), &bytes("0101025a00")).expect("old"),
        motion(1, None, None, Some(90))
    );
    assert_eq!(
        unpack_row(&wa(), &bytes("010103075a00")).expect("new"),
        motion(1, Some(7), None, Some(90))
    );
}

#[test]
fn ac3_typed_when_with_two_values() {
    let row = motion(1, Some(7), Some(8), Some(90));
    assert_eq!(round_trip(&w2(), &row, "01010307085a00"), row);
}

#[test]
fn ac3_typed_when_set_bit_with_a_body_value_missing_fails_pack() {
    let err = BinaryPacker::pack(&w2(), &motion(1, Some(7), None, Some(90))).expect_err("pack");
    assert_eq!(err, PackError::Missing("2".to_string()));
}

#[test]
fn ac3_typed_when_names_an_earlier_member_of_the_same_flags() {
    let row = pair(Some(1), Some(7));
    assert_eq!(round_trip(&we(), &row, "01030107"), row);
    assert_eq!(unpack_row(&we(), &bytes("01030107")).expect("unpack"), row);
}

#[test]
fn ac3_typed_same_flags_false_and_no_body() {
    let raw = BinaryPacker::pack(&we(), &pair(Some(0), Some(7))).expect("pack");
    assert_eq!(to_hex(&raw), "010100");
    assert_eq!(
        unpack_row(&we(), &raw).expect("unpack"),
        pair(Some(0), None)
    );
    let row = pair(Some(1), None);
    assert_eq!(round_trip(&we(), &row, "010101"), row);
}

#[test]
fn ac3_typed_same_flags_without_mode_clears_both_bits() {
    let raw = BinaryPacker::pack(&we(), &pair(None, Some(7))).expect("pack");
    assert_eq!(to_hex(&raw), "0100");
    assert_eq!(unpack_row(&we(), &raw).expect("unpack"), pair(None, None));
}

#[test]
fn ac3_typed_body_value_at_the_top_of_its_range_round_trips() {
    let row = motion(1, Some(255), None, Some(90));
    assert_eq!(round_trip(&wa(), &row, "010103ff5a00"), row);
}

#[derive(Default, Debug, PartialEq, Clone)]
struct Pt {
    pt: u8,
    pu: Option<u8>,
}

#[derive(Default, Debug, PartialEq, Clone)]
struct Track {
    n: u8,
    pts: Vec<Pt>,
    heading: Option<u16>,
}

fn pt(pt: u8) -> Pt {
    Pt { pt, pu: None }
}

fn pt2(pt: u8, pu: Option<u8>) -> Pt {
    Pt { pt, pu }
}

fn track(n: u8, pts: Vec<Pt>, heading: Option<u16>) -> Track {
    Track { n, pts, heading }
}

fn heading_item(id: u32) -> SchemeItem<Track> {
    BoundField::opt_u16(id, |r: &Track| r.heading, |r, v| r.heading = v).into()
}

fn count_item() -> SchemeItem<Track> {
    BoundField::u8(0, |r: &Track| r.n, |r, v| r.n = v).into()
}

/// TA: `u8 n; flags { times(n) { u8 pt }, u16 heading }`
fn ta() -> Scheme<Track> {
    Scheme::new(
        1,
        [
            count_item(),
            SchemeItem::flags(
                1,
                [
                    SchemeItem::times(
                        1,
                        0,
                        |r: &Track| &r.pts[..],
                        |r, v| r.pts = v,
                        [BoundField::u8(1, |p: &Pt| p.pt, |p, v| p.pt = v).into()],
                    ),
                    heading_item(2),
                ],
            ),
        ],
    )
}

/// T2: a `times` with two values per round, the second optional.
fn t2() -> Scheme<Track> {
    Scheme::new(
        1,
        [
            count_item(),
            SchemeItem::flags(
                1,
                [
                    SchemeItem::times(
                        1,
                        0,
                        |r: &Track| &r.pts[..],
                        |r, v| r.pts = v,
                        [
                            BoundField::u8(1, |p: &Pt| p.pt, |p, v| p.pt = v).into(),
                            BoundField::opt_u8(2, |p: &Pt| p.pu, |p, v| p.pu = v).into(),
                        ],
                    ),
                    heading_item(3),
                ],
            ),
        ],
    )
}

#[test]
fn ac4_typed_times_with_no_round_leaves_its_bit_clear() {
    let row = track(0, vec![], Some(90));
    assert_eq!(round_trip(&ta(), &row, "0100025a00"), row);
}

#[test]
fn ac4_typed_times_with_one_and_two_rounds() {
    let one = track(1, vec![pt(5)], Some(90));
    assert_eq!(round_trip(&ta(), &one, "010103055a00"), one);
    let two = track(2, vec![pt(5), pt(6)], Some(90));
    assert_eq!(round_trip(&ta(), &two, "01020305065a00"), two);
}

#[test]
fn ac4_typed_times_alone_and_count_alone() {
    let only_times = track(2, vec![pt(5), pt(6)], None);
    assert_eq!(round_trip(&ta(), &only_times, "0102010506"), only_times);
    let only_count = track(0, vec![], None);
    assert_eq!(round_trip(&ta(), &only_count, "010000"), only_count);
}

#[test]
fn ac5_typed_times_old_and_new_packets_unpack() {
    assert_eq!(
        unpack_row(&ta(), &bytes("0100025a00")).expect("old"),
        track(0, vec![], Some(90))
    );
    assert_eq!(
        unpack_row(&ta(), &bytes("01020305065a00")).expect("new"),
        track(2, vec![pt(5), pt(6)], Some(90))
    );
}

#[test]
fn ac4_typed_times_rounds_that_differ_from_the_count_fail_pack() {
    for row in [
        track(2, vec![pt(5)], Some(90)),
        track(1, vec![], Some(90)),
        track(0, vec![pt(5)], Some(90)),
        track(1, vec![pt(5), pt(6)], Some(90)),
    ] {
        let err = BinaryPacker::pack(&ta(), &row).expect_err("pack");
        assert!(matches!(err, PackError::Type(_)), "{err:?}");
    }
}

#[test]
fn ac4_typed_times_with_two_values() {
    let one = track(1, vec![pt2(5, Some(6))], Some(90));
    assert_eq!(round_trip(&t2(), &one, "01010305065a00"), one);
    let two = track(2, vec![pt2(5, Some(7)), pt2(6, Some(8))], Some(90));
    assert_eq!(round_trip(&t2(), &two, "010203050706085a00"), two);
}

#[test]
fn ac4_typed_times_with_two_values_missing_one_fails_pack_naming_it() {
    let err = BinaryPacker::pack(&t2(), &track(1, vec![pt2(5, None)], Some(90))).expect_err("pack");
    assert_eq!(err, PackError::Missing("2".to_string()));
}
