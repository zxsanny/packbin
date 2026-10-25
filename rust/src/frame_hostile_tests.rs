//! Frame mode, refusals and random input (AZ-3203): refusal kinds with no partial output, hostile bodies,
//! the stream and frame calls kept apart, type sizes and a property test of round trips and the window.

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

#[cfg(feature = "session")]
#[test]
fn a_frame_call_on_a_stream_session_and_a_stream_call_on_a_frame_session_are_refused() {
    let stream = Session::load(&[1u8; 32]).unwrap();
    let ctx = MsgCtx {
        msg_id: [0; 8],
        kind: 0,
    };
    let mut out = [0u8; 16];
    assert_eq!(
        stream
            .seal_frame(Direction::Up, &ctx, &[], &[], b"x", &mut out)
            .unwrap_err()
            .error,
        Error::BadValue
    );
    assert_eq!(
        stream
            .open_frame(Direction::Up, &ctx, &[], &[0; 8], 0, None, &mut out)
            .unwrap_err()
            .error,
        Error::BadValue
    );
    let mut frame = session(&[1; 32], 1, 4);
    assert_eq!(frame.start(&[0u8; 16]).unwrap_err().error, Error::BadValue);
    assert!(!frame.is_open());
}

#[test]
fn the_frame_types_are_small() {
    assert_eq!(core::mem::size_of::<ReplayWindow>(), 16);
    #[cfg(not(feature = "session"))]
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
