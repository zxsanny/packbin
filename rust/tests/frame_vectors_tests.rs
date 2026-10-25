//! Frame mode against the shared fixture `fixtures/frame/vectors.txt` (AZ-3203): every seal, open, mac and
//! replay row through the public API. The `keys` rows need the derived keys and run in the crate's own
//! tests (`src/frame_core_tests.rs`). A row whose direction is 0 or 4 cannot be built in Rust (the
//! `Direction` type has three values); the refusal is the type, so those rows are checked to expect
//! `BadValue` and nothing else.
//! Run with `--features frame` and with `--no-default-features --features frame`.
#![cfg(feature = "frame")]

use packbin::nostd::{
    Direction, Directions, Error, Fault, FrameConfig, Freshness, MacKey, MsgCtx, ReplayWindow,
    Session, Slot,
};
use std::collections::HashMap;

type Row = HashMap<String, String>;

const VECTORS: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../fixtures/frame/vectors.txt");
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

fn unhex(bytes: &[u8]) -> String {
    if bytes.is_empty() {
        "-".to_string()
    } else {
        bytes.iter().map(|b| format!("{b:02x}")).collect()
    }
}

fn rows() -> Vec<Row> {
    let text = std::fs::read_to_string(VECTORS).expect("fixtures/frame/vectors.txt");
    text.lines()
        .filter(|l| !l.trim().is_empty() && !l.starts_with('#'))
        .map(|l| {
            l.split(' ')
                .map(|t| {
                    let (k, v) = t.split_once('=').unwrap();
                    (k.to_string(), v.to_string())
                })
                .collect()
        })
        .collect()
}

fn kind_name(fault: &Fault) -> &'static str {
    match fault.error {
        Error::BadValue => "BadValue",
        Error::TooLong => "TooLong",
        Error::BufferFull => "BufferFull",
        Error::ShortPacket => "ShortPacket",
        Error::TagMismatch => "TagMismatch",
        Error::Duplicate => "Duplicate",
        Error::TooOld => "TooOld",
        _ => "other",
    }
}

fn key32(text: &str) -> [u8; 32] {
    hex(text).try_into().unwrap()
}

fn int(row: &Row, name: &str) -> u64 {
    row[name].parse().unwrap()
}

fn direction(n: u64) -> Option<Direction> {
    match n {
        1 => Some(Direction::Up),
        2 => Some(Direction::Down),
        3 => Some(Direction::Group),
        _ => None,
    }
}

fn dirs(row: &Row) -> Directions {
    let mut set = Directions::NONE;
    for c in row.get("dirs").map(String::as_str).unwrap_or("123").chars() {
        set = set.with(direction(u64::from(c.to_digit(10).unwrap())).unwrap());
    }
    set
}

fn load(row: &Row) -> Result<Session, Fault> {
    let epoch = u32::try_from(int(row, "epoch")).unwrap();
    let config = FrameConfig {
        tag_len: u8::try_from(int(row, "tag_len")).unwrap(),
        directions: dirs(row),
    };
    Session::load_frame(&key32(&row["key"]), epoch, config)
}

fn ctx(row: &Row) -> MsgCtx {
    MsgCtx {
        msg_id: hex(&row["msg_id"]).try_into().unwrap(),
        kind: u8::try_from(int(row, "kind")).unwrap(),
    }
}

fn window_text(w: &ReplayWindow) -> String {
    let (top, bits) = w.parts();
    format!("{top:x}:{bits:x}")
}

fn run_seal(row: &Row) -> Row {
    let mut out = Row::new();
    let Some(dir) = direction(int(row, "dir")) else {
        out.insert("result".into(), "BadValue".into());
        return out;
    };
    let result = load(row).and_then(|session| {
        let (ad, clear, plain) = (hex(&row["ad"]), hex(&row["clear"]), hex(&row["plain"]));
        let len = row.get("out_len").map_or(300, |v| v.parse().unwrap());
        let mut buf = vec![SENTINEL; len];
        let outcome = session.seal_frame(dir, &ctx(row), &ad, &clear, &plain, &mut buf);
        match outcome {
            Ok(n) => Ok(buf[..n].to_vec()),
            Err(fault) => {
                assert!(
                    buf.iter().all(|b| *b == SENTINEL),
                    "{}: a refused seal wrote bytes",
                    row["case"]
                );
                Err(fault)
            }
        }
    });
    match result {
        Ok(body) => out.insert("body".into(), unhex(&body)),
        Err(fault) => out.insert("result".into(), kind_name(&fault).into()),
    };
    out
}

fn run_open(row: &Row) -> Row {
    let mut out = Row::new();
    let mut window = row.get("window").map(|w| {
        let (top, bits) = w.split_once(':').unwrap();
        ReplayWindow::from_parts(
            u64::from_str_radix(top, 16).unwrap(),
            u64::from_str_radix(bits, 16).unwrap(),
        )
    });
    let before = window;
    let result = load(row).and_then(|mut session| {
        if let Some(prev) = row.get("prev_key") {
            session.set_previous(&key32(prev), u32::try_from(int(row, "prev_epoch")).unwrap())?;
        }
        let Some(dir) = direction(int(row, "dir")) else {
            return Err(Fault {
                error: Error::BadValue,
                offset: 0,
                field: -1,
                needed: 0,
            });
        };
        let (ad, body) = (hex(&row["ad"]), hex(&row["body"]));
        let len = row.get("out_len").map_or(300, |v| v.parse().unwrap());
        let mut buf = vec![SENTINEL; len];
        let counter = row.get("counter").map(|c| c.parse::<u64>().unwrap());
        let replay = match (window.as_mut(), counter) {
            (Some(w), Some(c)) => Some((w, c)),
            _ => None,
        };
        let opened = session.open_frame(
            dir,
            &ctx(row),
            &ad,
            &body,
            int(row, "clear_len") as usize,
            replay,
            &mut buf,
        );
        match opened {
            Ok(o) => Ok((o, buf[..o.plain_len].to_vec())),
            Err(fault) => {
                assert!(
                    buf.iter().all(|b| *b == SENTINEL),
                    "{}: a refused open wrote bytes",
                    row["case"]
                );
                Err(fault)
            }
        }
    });
    match result {
        Ok((opened, plain)) => {
            out.insert("result".into(), "Ok".into());
            out.insert(
                "slot".into(),
                (if opened.slot == Slot::Current {
                    "current"
                } else {
                    "previous"
                })
                .into(),
            );
            out.insert("plain".into(), unhex(&plain));
        }
        Err(fault) => {
            out.insert("result".into(), kind_name(&fault).into());
            assert_eq!(
                window, before,
                "{}: a failed open changed the window",
                row["case"]
            );
        }
    }
    if let Some(w) = window.as_ref() {
        out.insert("window_after".into(), window_text(w));
    }
    out
}

fn run_mac(row: &Row) -> Row {
    let mut out = Row::new();
    let derived = MacKey::derive(
        &key32(&row["key"]),
        u32::try_from(int(row, "epoch")).unwrap(),
        &hex(&row["label"]),
    );
    let parts: Vec<Vec<u8>> = match row.get("parts") {
        Some(p) => p.split('|').map(hex).collect(),
        None => vec![hex(&row["message"])],
    };
    let refs: Vec<&[u8]> = parts.iter().map(Vec::as_slice).collect();
    match derived {
        Err(fault) => {
            out.insert("result".into(), kind_name(&fault).into());
        }
        Ok(key) => {
            if let Some(tag) = row.get("verify") {
                out.insert("valid".into(), key.verify(&refs, &hex(tag)).to_string());
            } else {
                let mut tag = vec![0u8; int(row, "n") as usize];
                match key.tag(&refs, &mut tag) {
                    Ok(()) => out.insert("tag".into(), unhex(&tag)),
                    Err(fault) => out.insert("result".into(), kind_name(&fault).into()),
                };
            }
        }
    }
    out
}

fn run_replay(row: &Row) -> Row {
    let mut window = ReplayWindow::new();
    let (mut results, mut states) = (Vec::new(), Vec::new());
    for step in row["steps"].split(',') {
        let (action, number) = step.split_once(':').unwrap();
        let n: u64 = number.parse().unwrap();
        if action == "check" {
            results.push(match window.check(n) {
                Freshness::Fresh => "Fresh",
                Freshness::Duplicate => "Duplicate",
                Freshness::TooOld => "TooOld",
            });
        } else {
            window.commit(n);
            states.push(window_text(&window));
        }
    }
    let mut out = Row::new();
    out.insert("results".into(), results.join(","));
    out.insert(
        "states".into(),
        if states.is_empty() {
            "-".into()
        } else {
            states.join(",")
        },
    );
    out
}

#[test]
fn every_seal_open_mac_and_replay_row_matches() {
    let mut checked = 0;
    let all = rows();
    let others = all.iter().filter(|r| r["op"] != "keys").count();
    for row in all {
        let derived = match row["op"].as_str() {
            "seal" => run_seal(&row),
            "open" => run_open(&row),
            "mac" => run_mac(&row),
            "replay" => run_replay(&row),
            _ => continue,
        };
        for (name, value) in &derived {
            assert_eq!(row.get(name), Some(value), "{} {}", row["case"], name);
        }
        let outputs: &[&str] = match row["op"].as_str() {
            "seal" => &["body", "result"],
            "open" => &["result", "slot", "plain", "window_after"],
            "mac" => &["tag", "valid", "result"],
            _ => &["results", "states"],
        };
        for name in outputs {
            if row.contains_key(*name) {
                assert!(
                    derived.contains_key(*name),
                    "{}: the row has {} and the call gave none",
                    row["case"],
                    name
                );
            }
        }
        checked += 1;
    }
    assert_eq!(checked, others, "every row that is not a keys row ran");
    assert!(checked >= 130, "only {checked} rows ran");
}

#[test]
fn the_worked_examples_are_in_the_file() {
    let all = rows();
    for case in [
        "E1.seal",
        "E2.seal",
        "E3.seal",
        "E3.seal16",
        "E4.mac",
        "E5.mac",
    ] {
        assert!(all.iter().any(|r| r["case"] == case), "{case} missing");
    }
}
