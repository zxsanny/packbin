//! Frame mode inside the crate (AZ-3203): the key rows of the shared fixture, tampering, replay before
//! crypto, the previous slot, the MAC-only call, the cost counters, hostile input, sizes and a property
//! test. The fixture rows that go through the public API are in `tests/frame_vectors_tests.rs`.

use crate::nostd::{
    Direction, Directions, Error, FrameConfig, Freshness, MacKey, MsgCtx, Opened, ReplayWindow,
    Session, Slot,
};
use crate::session_core::{counters, hmac::Pads};

const SENTINEL: u8 = 0xA5;

fn hex(text: &str) -> Vec<u8> {
    if text == "-" {
        return Vec::new();
    }
    (0..text.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&text[i..i + 2], 16).unwrap())
        .collect()
}

fn all() -> Directions {
    Directions::ALL
}

fn session(key: &[u8; 32], epoch: u32, tag_len: u8) -> Session {
    Session::load_frame(
        key,
        epoch,
        FrameConfig {
            tag_len,
            directions: all(),
        },
    )
    .unwrap()
}

struct Example {
    key: [u8; 32],
    epoch: u32,
    dir: Direction,
    ctx: MsgCtx,
    ad: Vec<u8>,
    clear: Vec<u8>,
    plain: Vec<u8>,
}

fn examples() -> Vec<Example> {
    let ctx = |id: &str, kind| MsgCtx {
        msg_id: hex(id).try_into().unwrap(),
        kind,
    };
    vec![
        Example {
            key: [0x11; 32],
            epoch: 1,
            dir: Direction::Up,
            ctx: ctx("00301005e8030000", 4),
            ad: hex("000100301005e803000004"),
            clear: vec![],
            plain: hex("0102030405060708090a0b0c"),
        },
        Example {
            key: [0x11; 32],
            epoch: 1,
            dir: Direction::Down,
            ctx: ctx("00022001e9030000", 5),
            ad: hex("003000022001e903000005"),
            clear: vec![],
            plain: (0x40u8..0x6a).collect(),
        },
        Example {
            key: [0x33; 32],
            epoch: 7,
            dir: Direction::Group,
            ctx: ctx("00013002ea030000", 6),
            ad: hex("ffff00013002ea03000006"),
            clear: hex("a1b2c3"),
            plain: (0x80u8..0x94).collect(),
        },
    ]
}

fn seal(e: &Example, tag_len: u8) -> Vec<u8> {
    let s = session(&e.key, e.epoch, tag_len);
    let mut out = vec![0u8; 300];
    let n = s
        .seal_frame(e.dir, &e.ctx, &e.ad, &e.clear, &e.plain, &mut out)
        .unwrap();
    out.truncate(n);
    out
}

fn open(
    s: &Session,
    dir: Direction,
    ctx: &MsgCtx,
    ad: &[u8],
    body: &[u8],
    clear_len: usize,
    replay: Option<(&mut ReplayWindow, u64)>,
) -> (Result<Opened, Error>, Vec<u8>) {
    let mut out = vec![SENTINEL; 300];
    let result = s
        .open_frame(dir, ctx, ad, body, clear_len, replay, &mut out)
        .map_err(|f| f.error);
    (result, out)
}

#[test]
fn the_key_rows_of_the_fixture_match() {
    let text = std::fs::read_to_string(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../fixtures/frame/vectors.txt"
    ))
    .unwrap();
    let mut seen = 0;
    for line in text.lines().filter(|l| l.starts_with("op=keys ")) {
        let row: std::collections::HashMap<&str, &str> =
            line.split(' ').filter_map(|t| t.split_once('=')).collect();
        let key: [u8; 32] = hex(row["key"]).try_into().unwrap();
        let epoch: u32 = row["epoch"].parse().unwrap();
        if let Some(label) = row.get("label") {
            let mac = MacKey::derive(&key, epoch, &hex(label)).unwrap();
            let mut got = [0u8; 32];
            mac.tag(&[b"probe"], &mut got).unwrap();
            assert_eq!(
                got,
                Pads::new(&hex(row["k_label"]).try_into().unwrap()).mac(&[b"probe"]),
                "{}",
                row["case"]
            );
        } else {
            let dir = match row["dir"] {
                "1" => Direction::Up,
                "2" => Direction::Down,
                _ => Direction::Group,
            };
            let (enc, probe) = session(&key, epoch, 4)
                .test_material(dir, b"probe")
                .unwrap();
            assert_eq!(enc.to_vec(), hex(row["k_enc"]), "{} k_enc", row["case"]);
            assert_eq!(
                probe,
                Pads::new(&hex(row["k_mac"]).try_into().unwrap()).mac(&[b"probe"]),
                "{} k_mac",
                row["case"]
            );
        }
        seen += 1;
    }
    assert_eq!(seen, 20);
}

#[test]
fn every_single_bit_flip_and_field_change_is_a_tag_mismatch_and_writes_nothing() {
    for e in examples() {
        let body = seal(&e, 4);
        let s = session(&e.key, e.epoch, 4);
        let mut window = ReplayWindow::from_parts(100, 1);
        let before = window;
        let mut cases: Vec<(Vec<u8>, Vec<u8>, usize)> = Vec::new();
        for i in 0..e.ad.len() * 8 {
            let mut ad = e.ad.clone();
            ad[i / 8] ^= 1 << (i % 8);
            cases.push((ad, body.clone(), e.clear.len()));
        }
        for i in 0..body.len() * 8 {
            let mut b = body.clone();
            b[i / 8] ^= 1 << (i % 8);
            cases.push((e.ad.clone(), b, e.clear.len()));
        }
        for (ad, b, clear_len) in cases {
            let (r, out) = open(
                &s,
                e.dir,
                &e.ctx,
                &ad,
                &b,
                clear_len,
                Some((&mut window, 101)),
            );
            assert_eq!(r, Err(Error::TagMismatch));
            assert!(out.iter().all(|x| *x == SENTINEL));
            assert_eq!(window, before);
        }
        let mut other_id = e.ctx;
        other_id.msg_id[0] ^= 1;
        let other_kind = MsgCtx {
            kind: e.ctx.kind ^ 1,
            ..e.ctx
        };
        let other_dir = if e.dir == Direction::Up {
            Direction::Down
        } else {
            Direction::Up
        };
        for (s2, dir, ctx) in [
            (session(&e.key, e.epoch + 1, 4), e.dir, e.ctx),
            (session(&[0x99; 32], e.epoch, 4), e.dir, e.ctx),
            (session(&e.key, e.epoch, 4), e.dir, other_id),
            (session(&e.key, e.epoch, 4), e.dir, other_kind),
            (session(&e.key, e.epoch, 4), other_dir, e.ctx),
        ] {
            let (r, out) = open(
                &s2,
                dir,
                &ctx,
                &e.ad,
                &body,
                e.clear.len(),
                Some((&mut window, 101)),
            );
            assert_eq!(r, Err(Error::TagMismatch));
            assert!(out.iter().all(|x| *x == SENTINEL));
            assert_eq!(window, before);
        }
        let (r, _) = open(
            &s,
            e.dir,
            &e.ctx,
            &e.ad,
            &body,
            e.clear.len().wrapping_add(1),
            None,
        );
        assert_eq!(r, Err(Error::TagMismatch));
    }
}

#[test]
fn a_duplicate_or_old_counter_runs_no_sha_and_a_fresh_valid_one_commits() {
    let e = &examples()[0];
    let body = seal(e, 4);
    let s = session(&e.key, e.epoch, 4);
    let mut window = ReplayWindow::new();
    window.commit(100);
    counters::take();
    let (dup, _) = open(&s, e.dir, &e.ctx, &e.ad, &body, 0, Some((&mut window, 100)));
    assert_eq!(dup, Err(Error::Duplicate));
    let (old, _) = open(&s, e.dir, &e.ctx, &e.ad, &body, 0, Some((&mut window, 36)));
    assert_eq!(old, Err(Error::TooOld));
    assert_eq!(counters::take(), (0, 0));
    let mut tampered = body.clone();
    tampered[0] ^= 1;
    let (bad, _) = open(
        &s,
        e.dir,
        &e.ctx,
        &e.ad,
        &tampered,
        0,
        Some((&mut window, 101)),
    );
    assert_eq!(bad, Err(Error::TagMismatch));
    assert_eq!(window.check(101), Freshness::Fresh);
    let (ok, out) = open(&s, e.dir, &e.ctx, &e.ad, &body, 0, Some((&mut window, 101)));
    assert_eq!(ok.unwrap().plain_len, 12);
    assert_eq!(&out[..12], e.plain.as_slice());
    assert_eq!(window.check(101), Freshness::Duplicate);
}

#[test]
fn a_session_at_b7_with_previous_a6_opens_both_and_one_slot_refuses_the_old() {
    let (a, b) = ([0xAAu8; 32], [0xBBu8; 32]);
    let ctx = MsgCtx {
        msg_id: [7; 8],
        kind: 5,
    };
    let ad = [1u8, 2, 3];
    let seal_with = |key: &[u8; 32], epoch: u32| {
        let mut out = [0u8; 64];
        let n = session(key, epoch, 4)
            .seal_frame(Direction::Down, &ctx, &ad, &[], b"hello frame", &mut out)
            .unwrap();
        out[..n].to_vec()
    };
    let (old, new) = (seal_with(&a, 6), seal_with(&b, 7));
    let mut two = session(&b, 7, 4);
    two.set_previous(&a, 6).unwrap();
    let (r_old, _) = open(&two, Direction::Down, &ctx, &ad, &old, 0, None);
    assert_eq!(r_old.unwrap().slot, Slot::Previous);
    let (r_new, _) = open(&two, Direction::Down, &ctx, &ad, &new, 0, None);
    assert_eq!(r_new.unwrap().slot, Slot::Current);
    let one = session(&b, 7, 4);
    assert_eq!(
        open(&one, Direction::Down, &ctx, &ad, &old, 0, None).0,
        Err(Error::TagMismatch)
    );
    two.clear_previous();
    assert_eq!(
        open(&two, Direction::Down, &ctx, &ad, &old, 0, None).0,
        Err(Error::TagMismatch)
    );
}

#[test]
fn mac_only_tags_do_not_depend_on_the_split_and_the_key_is_small() {
    let key = MacKey::derive(&[0x22; 32], 7, b"net").unwrap();
    let message: Vec<u8> = hex("e8030000").into_iter().chain(0xc0u8..0xd4).collect();
    let mut whole = [0u8; 4];
    key.tag(&[&message], &mut whole).unwrap();
    assert_eq!(whole.to_vec(), hex("56db9bec"));
    let (a, rest) = message.split_at(3);
    let (b, c) = rest.split_at(5);
    let mut split = [0u8; 4];
    key.tag(&[a, b, c], &mut split).unwrap();
    assert_eq!(split, whole);
    assert!(key.verify(&[a, b, c], &whole));
    for bit in 0..32 {
        let mut flipped = whole;
        flipped[bit / 8] ^= 1 << (bit % 8);
        assert!(!key.verify(&[&message], &flipped));
    }
    assert_eq!(
        key.tag(&[&message], &mut [0u8; 5]).unwrap_err().error,
        Error::BadValue
    );
    assert!(!key.verify(&[&message], &[0u8; 3]));
    assert!(
        core::mem::size_of::<MacKey>() <= 72,
        "{}",
        core::mem::size_of::<MacKey>()
    );
    assert_eq!(format!("{key:?}"), "MacKey { epoch: 7, .. }");
}

#[test]
fn seal_open_and_tag_stay_within_four_blocks_and_six_compressions() {
    let key = [0x42u8; 32];
    let s = session(&key, 3, 4);
    let ctx = MsgCtx {
        msg_id: [1; 8],
        kind: 2,
    };
    let (ad, plain) = ([9u8; 11], [7u8; 236]);
    let mut out = [0u8; 255];
    counters::take();
    let n = s
        .seal_frame(Direction::Up, &ctx, &ad, &[], &plain, &mut out)
        .unwrap();
    let (sha, blocks) = counters::take();
    assert!(
        sha <= 6 && blocks <= 4,
        "seal {sha} compressions {blocks} blocks"
    );
    let mut back = [0u8; 255];
    let opened = s
        .open_frame(Direction::Up, &ctx, &ad, &out[..n], 0, None, &mut back)
        .unwrap();
    let (sha, blocks) = counters::take();
    assert!(
        sha <= 6 && blocks <= 4,
        "open {sha} compressions {blocks} blocks"
    );
    assert_eq!(opened.plain_len, 236);
    let mac = MacKey::derive(&key, 3, b"net").unwrap();
    counters::take();
    mac.tag(&[&[0u8; 4], &[0u8; 251]], &mut [0u8; 4]).unwrap();
    assert!(counters::take().0 <= 6);
}
