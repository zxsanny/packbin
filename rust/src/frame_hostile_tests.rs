//! Frame mode, refusals and random input (AZ-3203): refusal kinds with no partial output, hostile bodies,
//! type sizes and a property test of round trips and the window.

use crate::nostd::{
    Direction, Directions, Error, FrameConfig, Freshness, MsgCtx, ReplayWindow, Session,
};

const SENTINEL: u8 = 0xA5;

fn session(key: &[u8; 32], epoch: u32, tag_len: u8) -> Session {
    Session::load_frame(
        key,
        epoch,
        FrameConfig {
            tag_len,
            directions: Directions::ALL,
        },
    )
    .unwrap()
}

fn all() -> Directions {
    Directions::ALL
}

#[test]
fn refusals_leave_no_partial_output_and_hostile_input_never_panics() {
    let s = Session::load_frame(
        &[1; 32],
        2,
        FrameConfig {
            tag_len: 4,
            directions: Directions::NONE.with(Direction::Up),
        },
    )
    .unwrap();
    let ctx = MsgCtx {
        msg_id: [3; 8],
        kind: 1,
    };
    let mut out = [SENTINEL; 300];
    let e = |r: Result<usize, crate::nostd::Fault>| r.unwrap_err().error;
    assert_eq!(
        e(s.seal_frame(Direction::Down, &ctx, &[], &[], b"x", &mut out)),
        Error::BadValue
    );
    assert_eq!(
        e(s.seal_frame(
            Direction::Up,
            &MsgCtx { kind: 16, ..ctx },
            &[],
            &[],
            b"x",
            &mut out
        )),
        Error::BadValue
    );
    assert_eq!(
        e(s.seal_frame(Direction::Up, &ctx, &[0; 256], &[], b"x", &mut out)),
        Error::TooLong
    );
    assert_eq!(
        e(s.seal_frame(Direction::Up, &ctx, &[], &[], &[0; 252], &mut out)),
        Error::TooLong
    );
    assert_eq!(
        e(s.seal_frame(Direction::Up, &ctx, &[], &[], b"abcd", &mut out[..7])),
        Error::BufferFull
    );
    assert!(out.iter().all(|b| *b == SENTINEL));
    let long_ad = [0u8; 256];
    let opened = s.open_frame(Direction::Up, &ctx, &long_ad, &[0u8; 8], 0, None, &mut out);
    assert_eq!(opened.unwrap_err().error, Error::TooLong);
    assert!(out.iter().all(|b| *b == SENTINEL));
    assert!(Session::load_frame(
        &[1; 32],
        0x1000000,
        FrameConfig {
            tag_len: 4,
            directions: all()
        }
    )
    .is_err());
    for tag_len in [0u8, 5, 32] {
        assert!(Session::load_frame(
            &[1; 32],
            1,
            FrameConfig {
                tag_len,
                directions: all()
            }
        )
        .is_err());
    }
    let mut state = 0x9E3779B97F4A7C15u64;
    let mut next = move || {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        state
    };
    let full = session(&[5; 32], 9, 8);
    for _ in 0..2000 {
        let len = (next() % 300) as usize;
        let body: Vec<u8> = (0..len).map(|_| next() as u8).collect();
        let ad: Vec<u8> = (0..(next() % 260) as usize).map(|_| next() as u8).collect();
        let clear_len = (next() % 300) as usize;
        let mut window = ReplayWindow::from_parts(next(), next());
        let mut out = vec![SENTINEL; (next() % 300) as usize];
        let ctx = MsgCtx {
            msg_id: next().to_le_bytes(),
            kind: (next() % 20) as u8,
        };
        let counter = next();
        let r = full.open_frame(
            Direction::Group,
            &ctx,
            &ad,
            &body,
            clear_len,
            Some((&mut window, counter)),
            &mut out,
        );
        if r.is_err() {
            assert!(out.iter().all(|b| *b == SENTINEL));
        }
    }
}

#[test]
fn the_frame_types_are_small() {
    assert_eq!(core::mem::size_of::<ReplayWindow>(), 16);
    assert!(
        core::mem::size_of::<Session>() <= 640,
        "{}",
        core::mem::size_of::<Session>()
    );
}

#[test]
fn random_frames_round_trip_and_the_window_follows_the_model() {
    let mut state = 0x243F6A8885A308D3u64;
    let mut next = move || {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        state
    };
    for round in 0..300 {
        let key: [u8; 32] = core::array::from_fn(|_| next() as u8);
        let tag_len = [4u8, 8, 16][(next() % 3) as usize];
        let epoch = (next() % 0x1000000) as u32;
        let dir = [Direction::Up, Direction::Down, Direction::Group][(next() % 3) as usize];
        let ctx = MsgCtx {
            msg_id: next().to_le_bytes(),
            kind: (next() % 16) as u8,
        };
        let ad: Vec<u8> = (0..next() % 256).map(|_| next() as u8).collect();
        let room = 255 - usize::from(tag_len);
        let clear: Vec<u8> = (0..(next() as usize % (room + 1)).min(80))
            .map(|_| next() as u8)
            .collect();
        let plain: Vec<u8> = (0..(next() as usize % (room - clear.len() + 1)))
            .map(|_| next() as u8)
            .collect();
        let s = session(&key, epoch, tag_len);
        let mut sealed = vec![0u8; 255];
        let n = s
            .seal_frame(dir, &ctx, &ad, &clear, &plain, &mut sealed)
            .unwrap();
        assert_eq!(
            n,
            clear.len() + plain.len() + usize::from(tag_len),
            "round {round}"
        );
        let mut out = vec![0u8; 255];
        let o = s
            .open_frame(dir, &ctx, &ad, &sealed[..n], clear.len(), None, &mut out)
            .unwrap();
        assert_eq!(&out[..o.plain_len], plain.as_slice());
        assert_eq!(&sealed[..clear.len()], clear.as_slice());
    }
    let mut window = ReplayWindow::new();
    let mut seen: Vec<u64> = Vec::new();
    for _ in 0..5000 {
        let n = if next() % 4 == 0 {
            next() % 200
        } else {
            seen.last().copied().unwrap_or(100) + next() % 90
        };
        let top = seen.iter().copied().max();
        let expected = match top {
            None => Freshness::Fresh,
            Some(t) if n > t => Freshness::Fresh,
            Some(t) if t - n >= 64 => Freshness::TooOld,
            Some(_) if seen.contains(&n) => Freshness::Duplicate,
            Some(_) => Freshness::Fresh,
        };
        assert_eq!(window.check(n), expected, "counter {n}");
        if expected == Freshness::Fresh {
            window.commit(n);
            seen.push(n);
        }
    }
}

#[test]
fn loading_in_place_gives_the_same_frames_as_load_frame_and_replaces_the_keys() {
    // Arrange
    let config = FrameConfig {
        tag_len: 4,
        directions: all(),
    };
    let ctx = MsgCtx {
        msg_id: [4; 8],
        kind: 3,
    };
    let seal = |s: &Session| {
        let mut out = [0u8; 32];
        let n = s
            .seal_frame(Direction::Down, &ctx, &[1, 2], &[], b"in place", &mut out)
            .unwrap();
        out[..n].to_vec()
    };
    let by_value = Session::load_frame(&[8; 32], 5, config).unwrap();
    let mut in_place = Session::frame_unloaded();
    assert!(seal_refused(&in_place, &ctx));
    // Act
    in_place.load_frame_in_place(&[8; 32], 5, config).unwrap();
    // Assert
    assert_eq!(seal(&in_place), seal(&by_value));
    in_place.set_previous(&[9; 32], 4).unwrap();
    in_place.load_frame_in_place(&[7; 32], 6, config).unwrap();
    let old = seal(&session(&[9; 32], 4, 4));
    let mut out = [0u8; 32];
    let refused = in_place.open_frame(Direction::Down, &ctx, &[1, 2], &old, 0, None, &mut out);
    assert_eq!(refused.unwrap_err().error, Error::TagMismatch);
    let bad_tag = FrameConfig {
        tag_len: 5,
        directions: all(),
    };
    assert_eq!(
        in_place
            .load_frame_in_place(&[7; 32], 6, bad_tag)
            .unwrap_err()
            .error,
        Error::BadValue
    );
    assert_eq!(
        in_place
            .load_frame_in_place(&[7; 32], 0x1000000, config)
            .unwrap_err()
            .error,
        Error::BadValue
    );
}

fn seal_refused(s: &Session, ctx: &MsgCtx) -> bool {
    let mut out = [0u8; 32];
    s.seal_frame(Direction::Up, ctx, &[], &[], b"x", &mut out)
        .is_err()
}

#[test]
fn reloading_or_clearing_overwrites_the_previous_slot() {
    // Arrange
    let config = FrameConfig {
        tag_len: 4,
        directions: all(),
    };
    let mut s = Session::load_frame(&[1; 32], 1, config).unwrap();
    s.set_previous(&[2; 32], 0).unwrap();
    assert!(!s.test_previous_is_zero());
    // Act
    s.clear_previous();
    // Assert
    assert!(s.test_previous_is_zero());
    s.set_previous(&[3; 32], 0).unwrap();
    s.load_frame_in_place(&[4; 32], 2, config).unwrap();
    assert!(s.test_previous_is_zero());
}

#[test]
fn a_body_or_clear_part_above_255_bytes_is_refused_before_any_hashing() {
    // Arrange
    let s = session(&[5; 32], 3, 4);
    let ctx = MsgCtx {
        msg_id: [6; 8],
        kind: 1,
    };
    let mut out = [SENTINEL; 300];
    crate::session_core::counters::take();
    // Act
    let long_body = s.open_frame(Direction::Up, &ctx, &[], &[0u8; 10_000], 0, None, &mut out);
    let long_clear = s.open_frame(Direction::Up, &ctx, &[], &[0u8; 20], 256, None, &mut out);
    // Assert
    assert_eq!(long_body.unwrap_err().error, Error::TooLong);
    assert_eq!(long_clear.unwrap_err().error, Error::TooLong);
    assert_eq!(crate::session_core::counters::take(), (0, 0));
    assert!(out.iter().all(|b| *b == SENTINEL));
}
