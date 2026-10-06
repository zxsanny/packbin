use crate::hostile_tests::within_one_second;
use crate::{
    bytes, dict, list, repeat, u8, BinaryPacker, BoundField, PackSession, Scheme, SchemeItem,
    UnpackError, NONCE_SIZE, SEED_SIZE,
};

// AZ-2114: a session waiter that unpacks a hostile payload returns the error clear unpack
// returns, and its receive counter still advances by one, so the next message unpacks.

#[derive(Default)]
struct Raw(Vec<u8>);

/// A scheme whose clear packet is the type byte `01` and `len` raw bytes: the sender's side,
/// to put chosen clear bytes through a real session pad.
fn raw_scheme(len: usize) -> Scheme<Raw> {
    Scheme::new(
        1,
        [BoundField::bytes(0, len, |r: &Raw| r.0.clone(), |r: &mut Raw, v| r.0 = v).into()],
    )
}

/// The mode byte, then a `repeat` whose round reads nothing. The packet `01 00 ff` leaves the
/// `ff` byte to a round that never progresses. The scheme of fixtures/hostile/README.md
/// (`when` naming the mode inside the repeat) is refused at construction in Rust, so the
/// zero-progress round here is a zero-width `bytes`.
fn zero_progress() -> Scheme<()> {
    Scheme::new(
        1,
        [
            SchemeItem::Field(u8("0")),
            SchemeItem::Field(repeat(1, vec![bytes("1", 0)])),
        ],
    )
}

fn list_of_lists() -> Scheme<()> {
    Scheme::new(1, [SchemeItem::Field(list("0", list("0", bytes("0", 0))))])
}

fn dict_of_zero_width() -> Scheme<()> {
    Scheme::new(1, [SchemeItem::Field(dict("0", bytes("0", 0)))])
}

struct Outcome {
    clear: Result<(), UnpackError>,
    session: Result<(), UnpackError>,
    next: Result<(), UnpackError>,
    rows: usize,
}

/// Sends `hostile` and then `valid` (clear packets, type byte first) through an opened session
/// pair and unpacks both with the waiter, which holds `build()`; also unpacks `hostile` clear.
/// The whole run must finish within one second. `rows` counts the handler calls.
fn through_session(build: fn() -> Scheme<()>, hostile: &[u8], valid: &[u8]) -> Outcome {
    let (hostile, valid) = (hostile.to_vec(), valid.to_vec());
    within_one_second("session unpack of a hostile payload", move || {
        let mut opener = PackSession::load(&[7; SEED_SIZE]).expect("load");
        let mut waiter = PackSession::load(&[7; SEED_SIZE]).expect("load");
        let nonce = opener.start_with(&[1; NONCE_SIZE]).expect("start");
        assert!(waiter.join(&nonce));
        let send = |opener: &mut PackSession, clear: &[u8]| {
            let row = Raw(clear[1..].to_vec());
            let wire = opener
                .pack(&raw_scheme(clear.len() - 1), &row)
                .expect("pack");
            assert_ne!(wire, clear, "the packet must be padded");
            wire
        };
        let hostile_wire = send(&mut opener, &hostile);
        let valid_wire = send(&mut opener, &valid);

        let scheme = build();
        let mut rows = 0;
        let mut on_row = scheme.on(|_: ()| rows += 1);
        let clear = BinaryPacker::unpack_with(&hostile, &mut [&mut on_row]);
        let session = waiter.unpack(&hostile_wire, &mut [&mut on_row]);
        let next = waiter.unpack(&valid_wire, &mut [&mut on_row]);
        // The clear unpack above also failed, so no call came from it.
        Outcome {
            clear,
            session,
            next,
            rows,
        }
    })
}

fn assert_waiter_answers_like_clear_unpack(outcome: &Outcome) {
    assert!(
        outcome.clear.is_err(),
        "clear unpack must refuse the packet"
    );
    assert_eq!(outcome.session, outcome.clear);
}

fn assert_next_message_unpacks(outcome: &Outcome) {
    assert_eq!(outcome.next, Ok(()));
    assert_eq!(outcome.rows, 1);
}

#[test]
fn ac1_waiter_unpacking_a_zero_progress_packet_returns_the_clear_error() {
    let outcome = through_session(zero_progress, &[1, 0, 0xff], &[1, 0]);

    assert_waiter_answers_like_clear_unpack(&outcome);
}

#[test]
fn ac2_a_valid_message_after_a_zero_progress_packet_unpacks() {
    let outcome = through_session(zero_progress, &[1, 0, 0xff], &[1, 0]);

    assert_next_message_unpacks(&outcome);
}

#[test]
fn r2_g1_waiter_unpacking_a_list_of_zero_width_lists_returns_the_clear_error() {
    let outcome = through_session(list_of_lists, &[1, 0xff, 0xff, 0xff, 0xff], &[1, 0, 0]);

    assert_waiter_answers_like_clear_unpack(&outcome);
}

#[test]
fn r2_g1_a_valid_message_after_a_list_of_zero_width_lists_unpacks() {
    let outcome = through_session(list_of_lists, &[1, 0xff, 0xff, 0xff, 0xff], &[1, 0, 0]);

    assert_next_message_unpacks(&outcome);
}

#[test]
fn r2_g1_waiter_unpacking_a_dict_with_a_zero_width_value_returns_the_clear_error() {
    let outcome = through_session(dict_of_zero_width, &[1, 0xff, 0xff, 1, 0, 0x61], &[1, 0, 0]);

    assert_waiter_answers_like_clear_unpack(&outcome);
}

#[test]
fn r2_g1_a_valid_message_after_a_dict_with_a_zero_width_value_unpacks() {
    let outcome = through_session(dict_of_zero_width, &[1, 0xff, 0xff, 1, 0, 0x61], &[1, 0, 0]);

    assert_next_message_unpacks(&outcome);
}
