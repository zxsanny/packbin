// (d) the AC-1 / AC-2 edge cases (included by main.rs).

// ---------------------------------------------------------------- (d) edges

struct Edges {
    fails: usize,
    rows: usize,
}

impl Edges {
    /// One call: must finish within 1 s.
    fn check(&mut self, name: &str, expect_ok: Option<bool>, f: impl FnOnce() -> Result<String, String>) {
        self.check_within(name, expect_ok, Duration::from_secs(1), f)
    }

    /// A batch of many calls: the time shown is the whole batch.
    fn check_within(&mut self, name: &str, expect_ok: Option<bool>, limit: Duration, f: impl FnOnce() -> Result<String, String>) {
        self.rows += 1;
        let (r, dt) = guarded(f);
        let (got, pass) = match &r {
            None => ("PANIC".to_string(), false),
            Some(Ok(s)) => (format!("ok {s}"), expect_ok != Some(false)),
            Some(Err(e)) => (format!("refused {e}"), expect_ok != Some(true)),
        };
        let pass = pass && dt < limit;
        if !pass {
            self.fails += 1;
        }
        let shown: String = got.chars().take(110).collect();
        println!("{} {name:<58} {:>9.1} us  {shown}", if pass { "PASS" } else { "FAIL" }, dt.as_secs_f64() * 1e6);
    }
}

fn text_case(e: &mut Edges, name: &str, expect: bool, payload: Vec<u8>) {
    let f = field(&payload);
    e.check(name, Some(expect), || read_text(&f).map(|s| format!("{} bytes", s.len())));
}

fn edges(checkout: &str) -> bool {
    let codes = Codes::load(checkout);
    let mut e = Edges { fails: 0, rows: 0 };
    println!("edges: debug_assertions {}", cfg!(debug_assertions));

    // ---- AC-1 text
    let mut raw = vec![0x10u8];
    raw.extend(std::iter::repeat(b'a').take(65535));
    text_case(&mut e, "raw 65,535 bytes", true, raw.clone());
    raw.push(b'a');
    text_case(&mut e, "raw 65,536 bytes (length)", false, raw.clone());
    let last = raw.len() - 1;
    raw[last] = 0xff;
    text_case(&mut e, "raw 65,536 bytes, last invalid (length/utf8)", false, raw);
    for (name, bad) in [
        ("raw bad continuation c3 28", vec![0xc3, 0x28]),
        ("raw overlong c0 80", vec![0xc0, 0x80]),
        ("raw surrogate ed a0 80", vec![0xed, 0xa0, 0x80]),
        ("raw above U+10FFFF f4 90 80 80", vec![0xf4, 0x90, 0x80, 0x80]),
        ("raw cut lead e2 82", vec![0xe2, 0x82]),
    ] {
        let mut p = vec![0x10u8];
        p.extend(bad);
        text_case(&mut e, name, false, p);
    }
    text_case(&mut e, "raw prefix alone (empty raw text)", true, vec![0x10]);
    for first in [0x11u8, 0x12, 0x13, 0x30, 0xf0] {
        text_case(&mut e, &format!("mode 4 with first byte {first:02x} (raw)"), false, vec![first, 0x61]);
    }
    for mode in 5u8..8 {
        text_case(&mut e, &format!("start mode {mode} (mode)"), false, vec![mode << 2, 0]);
    }
    text_case(&mut e, "1-byte payload pad 2 (empty text)", true, vec![0x40]);
    text_case(&mut e, "1-byte payload pad 3 (pad: total 5)", false, vec![0x60]);
    text_case(&mut e, "1-byte payload pad 7 (pad)", false, vec![0xe0]);
    text_case(&mut e, "pad bit set (pad)", false, vec![0x41]);
    text_case(&mut e, "2-byte payload pad 0, 10 symbol bits, cut code", false, {
        let mut b = Bits::new(&codes, UA);
        b.raw(0x3ff, 10);
        b.finish()
    });
    // Compact length limit.
    let max = max_text_payload(&codes);
    text_case(&mut e, &format!("compact 65,535 bytes ({}-byte payload)", max.len()), true, max.clone());
    text_case(&mut e, "compact 65,536 bytes (length)", false, {
        let mut b = Bits::new(&codes, RU);
        for _ in 0..32768 {
            b.sym(RU, 15);
        }
        b.finish()
    });
    text_case(&mut e, "compact 65,534 + ESC 4-byte char (length)", false, {
        let mut b = Bits::new(&codes, RU);
        for _ in 0..32767 {
            b.sym(RU, 15);
        }
        b.sym(RU, esc(RU));
        for x in [0xf0u8, 0x9f, 0x98, 0x80] {
            b.byte(x);
        }
        b.finish()
    });
    // Expansion bound 6N + 8 over every count of `о` up to 4,000 and with the lock on capitals.
    e.check_within("expansion: о x 1..4000, О under LOCK, <= 6N+8 (batch)", Some(true), Duration::from_secs(120), || {
        let mut worst = 0f64;
        for k in 1..4000 {
            for locked in [false, true] {
                let mut b = Bits::new(&codes, RU);
                if locked {
                    b.sym(RU, lock(RU));
                }
                for _ in 0..k {
                    b.sym(RU, 15);
                }
                let p = b.finish();
                let s = read_text(&field(&p))?;
                if s.len() > 6 * p.len() + 8 {
                    return Err(format!("{} bytes from {}", s.len(), p.len()));
                }
                worst = worst.max(s.len() as f64 / p.len() as f64);
            }
        }
        Ok(format!("worst {worst:.3} bytes per payload byte"))
    });
    // ESC at every bit offset, cut at every byte, and invalid scalars.
    e.check("ESC 4-byte char cut at 0..3 bytes, 8 bit offsets (esc)", Some(false), || {
        let mut refused = 0;
        for shift in 0..8 {
            for keep in 0..4 {
                let mut b = Bits::new(&codes, UA);
                b.raw(0, 0);
                for _ in 0..shift {
                    // A shared space in UA is 3 bits; a 0-bit shift step comes from the varying count.
                    b.sym(UA, shared(UA, 0));
                }
                b.sym(UA, esc(UA));
                for x in &[0xf0u8, 0x9f, 0x98, 0x80][..keep] {
                    b.byte(*x);
                }
                if read_text(&field(&b.finish())).is_err() {
                    refused += 1;
                }
            }
        }
        if refused == 32 {
            Err("32 of 32 refused".into())
        } else {
            Ok(format!("{refused} of 32 refused"))
        }
    });
    let invalid: [&[u8]; 14] = [
        &[0x80], &[0xbf], &[0xc0, 0x80], &[0xc1, 0xbf], &[0xc3, 0x28], &[0xe0, 0x80, 0x80], &[0xe0, 0x9f, 0xbf],
        &[0xed, 0xa0, 0x80], &[0xed, 0xbf, 0xbf], &[0xf0, 0x80, 0x80, 0x80], &[0xf4, 0x90, 0x80, 0x80],
        &[0xf5, 0x80, 0x80, 0x80], &[0xf8, 0x80, 0x80, 0x80], &[0xff, 0x80, 0x80, 0x80],
    ];
    for bad in invalid {
        for shift in [0usize, 3] {
            let mut b = Bits::new(&codes, EN);
            for _ in 0..shift {
                b.sym(EN, shared(EN, 0));
            }
            b.sym(EN, esc(EN));
            for x in bad {
                b.byte(*x);
            }
            text_case(&mut e, &format!("ESC {} shift {shift} (utf8)", to_hex(bad)), false, b.finish());
        }
    }
    for (name, good) in [
        ("ESC U+0000", vec![0x00u8]),
        ("ESC U+FFFD ef bf bd", vec![0xef, 0xbf, 0xbd]),
        ("ESC U+10FFFF f4 8f bf bf", vec![0xf4, 0x8f, 0xbf, 0xbf]),
        ("ESC U+D7FF ed 9f bf", vec![0xed, 0x9f, 0xbf]),
    ] {
        let mut b = Bits::new(&codes, NUM);
        b.sym(NUM, esc(NUM));
        for x in &good {
            b.byte(*x);
        }
        text_case(&mut e, name, true, b.finish());
    }
    // CAP rules.
    let cap_cases: Vec<(&str, Vec<(usize, usize)>)> = vec![
        ("CAP at the end (cap)", vec![(UA, cap(UA))]),
        ("CAP then apostrophe (cap)", vec![(UA, cap(UA)), (UA, 33)]),
        ("CAP CAP (cap)", vec![(UA, cap(UA)), (UA, cap(UA))]),
        ("LOCK then CAP (cap)", vec![(UA, lock(UA)), (UA, cap(UA))]),
        ("CAP then LOCK (cap)", vec![(UA, cap(UA)), (UA, lock(UA))]),
        ("CAP then SW (cap)", vec![(UA, cap(UA)), (UA, sw(UA, EN))]),
        ("CAP then shared (cap)", vec![(UA, cap(UA)), (UA, shared(UA, 0))]),
        ("CAP then ESC (cap)", vec![(UA, cap(UA)), (UA, esc(UA))]),
        ("CAP at the end in EN (cap)", vec![(EN, cap(EN))]),
    ];
    for (name, syms) in cap_cases {
        let start = syms[0].0;
        let mut b = Bits::new(&codes, start);
        for (m, s) in &syms {
            b.sym(*m, *s);
        }
        if name.starts_with("CAP then ESC") {
            b.byte(b'a');
        }
        text_case(&mut e, name, false, b.finish());
    }
    text_case(&mut e, "LOCK survives num mode: LOCK, SW num, SW en, a = A", true, {
        let mut b = Bits::new(&codes, EN);
        b.sym(EN, lock(EN));
        b.sym(EN, sw(EN, NUM));
        b.sym(NUM, sw(NUM, EN));
        b.sym(EN, 0);
        b.finish()
    });
    // Varint and short counts.
    for (name, f, ok) in [
        ("varint 4 bytes (varint)", vec![0x80u8, 0x80, 0x80, 0x01, 0x10], false),
        ("varint non-minimal 80 00 (varint)", vec![0x80, 0x00], false),
        ("varint non-minimal ff 80 00 (varint)", vec![0xff, 0x80, 0x00], false),
        ("varint cut 80 (short)", vec![0x80], false),
        ("count 2,097,151 with 10 bytes (short)", vec![0xff, 0xff, 0x7f, 0x10, 1, 2, 3, 4, 5, 6, 7, 8, 9], false),
        ("count 0 (empty)", vec![0x00], true),
    ] {
        e.check(name, Some(ok), || read_text(&f).map(|s| format!("{} bytes", s.len())));
    }
    // 2,097,151-byte payload of switches: accepted, empty, linear time.
    let controls = controls_payload(&codes, 2_097_151);
    text_case(&mut e, "2,097,151-byte payload of mode switches (empty)", true, controls);
    // Dictionary keys: one decoded key twice in different encodings.
    let key_raw_a = field(&[0x10, b'a']);
    let key_en_a = {
        let mut b = Bits::new(&codes, EN);
        b.sym(EN, 0);
        field(&b.finish())
    };
    let key_ua_a = {
        let mut b = Bits::new(&codes, UA);
        b.sym(UA, 0);
        field(&b.finish())
    };
    let key_ru_a = {
        let mut b = Bits::new(&codes, RU);
        b.sym(RU, 0);
        field(&b.finish())
    };
    let key_esc_a = {
        let mut b = Bits::new(&codes, NUM);
        b.sym(NUM, esc(NUM));
        b.byte(b'a');
        field(&b.finish())
    };
    let dict_packet = |keys: &[&Vec<u8>]| {
        let mut p = vec![1u8, keys.len() as u8, 0];
        for (i, k) in keys.iter().enumerate() {
            p.extend_from_slice(k);
            p.push(i as u8);
        }
        p
    };
    for (name, keys, ok) in [
        ("dict keys 'a' raw + 'a' EN code (duplicate)", vec![&key_raw_a, &key_en_a], false),
        ("dict keys 'a' EN code + 'a' ESC in num (duplicate)", vec![&key_en_a, &key_esc_a], false),
        ("dict keys 'а' UA + 'а' RU (duplicate)", vec![&key_ua_a, &key_ru_a], false),
        ("dict keys 'a' + 'а' (distinct)", vec![&key_en_a, &key_ua_a], true),
    ] {
        let p = dict_packet(&keys);
        e.check(name, Some(ok), || unpack(&d_scheme(), &p).map(|_| String::new()).map_err(|e| format!("{e:?}")));
    }

    // ---- AC-2 ECC
    // Every n = 1..32 and N = 0..256, several fills, t = 0 and n/2: no panic; short, too_long as documented.
    e.check_within("all n 1..32 x N 0..256 x 7 fills x t {0, n/2} (batch)", None, Duration::from_secs(120), || {
        let mut rng = Rng(0xA11);
        let (mut calls, mut repaired, mut wrong) = (0, 0, 0);
        for n in 1..=32usize {
            for len in 0..=256usize {
                let mut fills: Vec<Vec<u8>> = vec![vec![0; len], vec![0xff; len], rng.fill(len), rng.fill(len)];
                if len > n && len <= 254 {
                    let mut clear = rng.fill(len - n);
                    clear[0] = 1;
                    let w = protect(&clear, n);
                    for k in [n / 2, n / 2 + 1, n] {
                        let mut c = w.clone();
                        corrupt(&mut c, k, &mut rng);
                        fills.push(c);
                    }
                }
                for (i, buf) in fills.iter().enumerate() {
                    for t in [0, n / 2] {
                        calls += 1;
                        let r = if i >= 4 { repair_typed(buf, n, t, 1) } else { repair_bytes(buf, n, t) };
                        match r {
                            Ok((c, rep)) => {
                                if rep > 0 {
                                    repaired += 1;
                                }
                                if len > 254 || len < n || protect(&c, n).len() != len || hamming(&protect(&c, n), buf) != rep {
                                    wrong += 1;
                                }
                            }
                            Err(UnpackError::Short(s)) => {
                                if len < n && !(s.field == "parity" && s.needed == n && s.left == len) {
                                    wrong += 1;
                                }
                            }
                            Err(UnpackError::TooLong { len: l, limit }) => {
                                if l != len || limit != 254 || len <= 254 {
                                    wrong += 1;
                                }
                            }
                            Err(_) => {}
                        }
                    }
                }
            }
        }
        if wrong > 0 {
            Err(format!("{wrong} wrong of {calls}"))
        } else {
            Ok(format!("{calls} calls, {repaired} repairs, 0 wrong"))
        }
    });
    e.check("16 MiB buffer at n 32 (too_long, no arithmetic)", Some(false), || {
        let big = vec![0u8; 16 << 20];
        repair_bytes(&big, 32, 16).map(|_| String::new()).map_err(|e| format!("{e:?}"))
    });
    e.check("empty buffer at n 4 (short naming parity)", Some(false), || {
        repair_bytes(&[], 4, 2).map(|_| String::new()).map_err(|e| format!("{e:?}"))
    });
    {
        let mut rng = Rng(0xB0B);
        let mut clear = rng.fill(254 - 32);
        clear[0] = 1;
        let w = protect(&clear, 32);
        for (name, positions) in [
            ("16 wrong in the parity only, t 16", (238..254).collect::<Vec<_>>()),
            ("wrong first and last byte, t 16", vec![0, 253]),
            ("16-byte burst in the middle, t 16", (100..116).collect()),
            ("type byte wrong, t 1", vec![0]),
        ] {
            let mut c = w.clone();
            for p in &positions {
                c[*p] ^= 0x5a;
            }
            let expect = clear.clone();
            let k = positions.len();
            e.check(name, Some(true), || match repair_typed(&c, 32, 16, 1) {
                Ok((got, rep)) if got == expect && rep == k => Ok(format!("repaired {rep}")),
                Ok((_, rep)) => Err(format!("wrong repair ({rep})")),
                Err(err) => Err(format!("{err:?}")),
            });
        }
    }
    // A dispatch handler that declares more than 32 parity bytes (contract: refused before a byte is read).
    for (declared, len) in [(33usize, 40usize), (33, 254), (64, 64), (254, 254), (255, 254), (usize::MAX, 254)] {
        let buf = vec![1u8; len];
        e.check(&format!("unpack_with_repair, handler parity() = {declared}, {len}-byte buffer"), Some(false), || {
            let mut h = Rec::new(1, declared);
            BinaryPacker::unpack_with_repair(&buf, &mut [&mut h], 0).map(|r| format!("repaired {r}")).map_err(|e| format!("{e:?}"))
        });
    }
    // Dispatch check order, plain call.
    e.check("dispatch: no handlers", Some(false), || {
        BinaryPacker::unpack_with_repair(&[1, 2, 3], &mut [], 99).map(|_| String::new()).map_err(|e| format!("{e:?}"))
    });
    e.check("dispatch: duplicate type before mix and limit", Some(false), || {
        let (mut a, mut b) = (Rec::new(1, 2), Rec::new(1, 4));
        BinaryPacker::unpack_with_repair(&[1, 2, 3], &mut [&mut a, &mut b], 99).map(|_| String::new()).map_err(|e| format!("{e:?}"))
    });
    e.check("dispatch: mixed parity before limit", Some(false), || {
        let (mut a, mut b) = (Rec::new(1, 2), Rec::new(2, 4));
        BinaryPacker::unpack_with_repair(&[1, 2, 3], &mut [&mut a, &mut b], 99).map(|_| String::new()).map_err(|e| format!("{e:?}"))
    });
    e.check("dispatch: limit above n/2", Some(false), || {
        let mut a = Rec::new(1, 4);
        BinaryPacker::unpack_with_repair(&[1, 2, 3], &mut [&mut a], 3).map(|_| String::new()).map_err(|e| format!("{e:?}"))
    });
    e.check("dispatch: unknown type after repair", Some(false), || {
        let w = protect(&[7, 1, 2, 3], 4);
        let mut a = Rec::new(1, 4);
        BinaryPacker::unpack_with_repair(&w, &mut [&mut a], 2).map(|_| String::new()).map_err(|e| format!("{e:?}"))
    });
    report_usage("edges");
    println!("edges: {} rows, {} FAIL", e.rows, e.fails);
    e.fails == 0
}
