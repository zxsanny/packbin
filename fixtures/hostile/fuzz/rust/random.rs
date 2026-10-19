// (a) seeded random and mutated inputs (included by main.rs).

// ---------------------------------------------------------------- (a) random

#[derive(Default)]
struct Tally {
    calls: u64,
    ok: u64,
    refused: u64,
    panics: u64,
    slowest: Duration,
    slowest_input: String,
    violations: u64,
}

impl Tally {
    fn record(&mut self, ok: Option<bool>, dt: Duration, input: &[u8]) {
        self.calls += 1;
        match ok {
            Some(true) => self.ok += 1,
            Some(false) => self.refused += 1,
            None => self.panics += 1,
        }
        if dt > self.slowest {
            self.slowest = dt;
            self.slowest_input = head(input);
        }
        if dt > Duration::from_secs(1) {
            self.violations += 1;
            println!("VIOLATION over 1 s: {:?} for {}", dt, head(input));
        }
    }
    fn print(&self, name: &str) {
        println!(
            "{name:<22} calls {:>8}  accepted {:>8}  refused {:>8}  panics {}  violations {}  slowest {:.1} us ({})",
            self.calls,
            self.ok,
            self.refused,
            self.panics,
            self.violations,
            self.slowest.as_secs_f64() * 1e6,
            self.slowest_input
        );
    }
}

fn violation(t: &mut Tally, msg: String) {
    t.violations += 1;
    println!("VIOLATION: {msg}");
}

/// The payload length of a lone string packet `[01] + field` that unpack accepted (no trailing bytes).
fn payload_len(field: &[u8]) -> usize {
    let mut used = 0;
    while used < field.len() && field[used] & 0x80 != 0 {
        used += 1;
    }
    field.len() - (used + 1).min(field.len())
}

fn random(checkout: &str, seed: u64, calls: u64) -> bool {
    let seeds = load_seeds(checkout);
    let mut rng = Rng(seed);
    println!("random: seed {seed:#x}, calls per target {calls}, debug_assertions {}", cfg!(debug_assertions));
    let (s, l, d) = (s_scheme(), l_scheme(), d_scheme());
    let mut text_pool = seeds.text.clone();
    text_pool.extend(seeds.corpus.iter().cloned());

    // Text: one string field.
    let mut ts = Tally::default();
    for _ in 0..calls {
        let mut f = if rng.below(10) == 0 {
            let n = rng.below(64);
            rng.fill(n)
        } else {
            seeds.text[rng.below(seeds.text.len())].clone()
        };
        mutate(&mut rng, &mut f, &text_pool);
        let mut packet = vec![1u8];
        packet.extend_from_slice(&f);
        let (r, dt) = guarded(|| unpack(&s, &packet));
        let ok = r.as_ref().map(|r| r.is_ok());
        if let Some(Ok(v)) = &r {
            let text = text_of(v, "s").unwrap_or_default();
            let n = payload_len(&f);
            if text.len() > 65535 || text.len() > 6 * n + 8 {
                violation(&mut ts, format!("decoded {} bytes from a {n}-byte payload: {}", text.len(), head(&f)));
            }
        }
        ts.record(ok, dt, &packet);
    }
    ts.print("text lone string");

    // Text: a list of strings and a dict keyed by strings.
    let mut tl = Tally::default();
    let mut td = Tally::default();
    for i in 0..calls {
        let items = 1 + rng.below(4);
        let mut body = Vec::new();
        for _ in 0..items {
            let mut f = seeds.text[rng.below(seeds.text.len())].clone();
            if rng.below(2) == 0 {
                mutate(&mut rng, &mut f, &text_pool);
            }
            body.extend_from_slice(&f);
            if i % 2 == 1 {
                body.push(rng.byte());
            }
        }
        let count = if rng.below(8) == 0 { rng.below(65536) } else { items };
        let mut packet = vec![1u8, count as u8, (count >> 8) as u8];
        packet.extend_from_slice(&body);
        if rng.below(4) == 0 {
            let mut p = packet.clone();
            mutate(&mut rng, &mut p, &text_pool);
            packet = p;
        }
        if i % 2 == 0 {
            let (r, dt) = guarded(|| unpack(&l, &packet));
            tl.record(r.map(|r| r.is_ok()), dt, &packet);
        } else {
            let (r, dt) = guarded(|| unpack(&d, &packet));
            td.record(r.map(|r| r.is_ok()), dt, &packet);
        }
    }
    tl.print("text list");
    td.print("text dict");

    // ECC: random buffers, any n and t.
    let mut er = Tally::default();
    for _ in 0..calls {
        let n = 1 + rng.below(32);
        let t = rng.below(n / 2 + 1);
        let len = if rng.below(16) == 0 { 255 + rng.below(64) } else { rng.below(255) };
        let buf = match rng.below(4) {
            0 => vec![0u8; len],
            1 => vec![0xffu8; len],
            _ => rng.fill(len),
        };
        let before = buf.clone();
        let (r, dt) = guarded(|| repair_bytes(&buf, n, t));
        if buf != before {
            violation(&mut er, "input written".into());
        }
        if let Some(Ok((clear, repaired))) = &r {
            let again = protect(clear, n);
            if repaired > &t || again.len() != buf.len() || hamming(&again, &buf) != *repaired {
                violation(&mut er, format!("repair not a code word within t: n {n} t {t} rep {repaired} {}", head(&buf)));
            }
        }
        er.record(r.map(|r| r.is_ok()), dt, &buf);
    }
    er.print("ecc random buffers");

    // ECC: code words with k wrong bytes. k <= t must repair to the sent message; t < k <= n - t must be refused.
    let mut ec = Tally::default();
    for _ in 0..calls {
        let n = 1 + rng.below(32);
        let t = rng.below(n / 2 + 1);
        let clear_len = 1 + rng.below(254 - n);
        let mut clear = rng.fill(clear_len);
        clear[0] = 1;
        let sent = protect(&clear, n);
        let k = rng.below(n + 1);
        let mut word = sent.clone();
        corrupt(&mut word, k, &mut rng);
        let (r, dt) = guarded(|| repair_typed(&word, n, t, 1));
        match &r {
            Some(Ok((got, rep))) => {
                if k <= t && (got != &clear || *rep != k) {
                    violation(&mut ec, format!("k {k} <= t {t} repaired wrong: n {n}"));
                }
                if k > t && k <= n - t {
                    violation(&mut ec, format!("k {k} in t+1..n-t accepted: n {n} t {t}"));
                }
            }
            Some(Err(_)) => {
                if k <= t {
                    violation(&mut ec, format!("k {k} <= t {t} refused: n {n} len {}", word.len()));
                }
            }
            None => {}
        }
        ec.record(r.map(|r| r.is_ok()), dt, &word);
    }
    ec.print("ecc code words + k");

    // ECC: vector seeds, mutated.
    let mut ev = Tally::default();
    let ecc_pool: Vec<Vec<u8>> = seeds.ecc.iter().map(|(_, b)| b.clone()).collect();
    for _ in 0..calls {
        let (n, b) = &seeds.ecc[rng.below(seeds.ecc.len())];
        let n = (*n).max(1);
        let t = rng.below(n / 2 + 1);
        let mut buf = b.clone();
        mutate(&mut rng, &mut buf, &ecc_pool);
        let (r, dt) = guarded(|| repair_bytes(&buf, n, t));
        ev.record(r.map(|r| r.is_ok()), dt, &buf);
    }
    ev.print("ecc vector seeds");

    // Strings inside protected messages: corrupt up to n bytes, read with the text scheme.
    let mut ep = Tally::default();
    for _ in 0..calls {
        let n = 1 + rng.below(32);
        let t = rng.below(n / 2 + 1);
        let mut f = seeds.text[rng.below(seeds.text.len())].clone();
        if rng.below(2) == 0 {
            mutate(&mut rng, &mut f, &text_pool);
        }
        if f.len() + 1 > 254 - n {
            continue;
        }
        let mut clear = vec![1u8];
        clear.extend_from_slice(&f);
        let mut word = protect(&clear, n);
        let k = rng.below(t + 2);
        corrupt(&mut word, k, &mut rng);
        let scheme = s_scheme().with_parity(n);
        let (r, dt) = guarded(|| unpack_repair(&scheme, &word, t));
        if let Some(r) = &r {
            let direct = read_text(&f);
            if k <= t && r.is_ok() != direct.is_ok() {
                violation(&mut ep, format!("protected read {} vs clear read {}", r.is_ok(), direct.is_ok()));
            }
        }
        ep.record(r.map(|r| r.is_ok()), dt, &word);
    }
    ep.print("text in protected msg");

    // Session: after every hostile payload the next valid payload must read (no receive-index desync).
    let mut se = Tally::default();
    let mut opener = PackSession::load(&[9; SEED_SIZE]).expect("load");
    let mut waiter = PackSession::load(&[9; SEED_SIZE]).expect("load");
    let nonce = opener.start_with(&[3; NONCE_SIZE]).expect("start");
    assert!(waiter.join(&nonce));
    for _ in 0..calls / 4 {
        let n = rng.below(33);
        let t = rng.below(n / 2 + 1);
        let len = 1 + rng.below(40.min(253 - n));
        let a = rng.fill(len);
        let b = rng.fill(len);
        let wire_a = session_pack(&mut opener, &a, n);
        let wire_b = session_pack(&mut opener, &b, n);
        let mut hostile = wire_a.clone();
        let k = rng.below(n + 2);
        if rng.below(3) == 0 {
            mutate(&mut rng, &mut hostile, &[]);
        } else {
            corrupt(&mut hostile, k, &mut rng);
        }
        let mut h = Rec::new(1, n);
        let (r, dt) = guarded(|| waiter.unpack_repair(&hostile, &mut [&mut h], t));
        if let Some(Ok(_)) = &r {
            if hostile.len() == wire_a.len() && hamming(&hostile, &wire_a) <= t && h.got.as_deref().map(|g| &g[1..]) != Some(&a[..]) {
                violation(&mut se, format!("session repaired to another row: n {n} t {t}"));
            }
        }
        se.record(r.map(|r| r.is_ok()), dt, &hostile);
        let mut h2 = Rec::new(1, n);
        let next = waiter.unpack_repair(&wire_b, &mut [&mut h2], 0);
        if next.is_err() || h2.got.as_deref().map(|g| &g[1..]) != Some(&b[..]) {
            violation(&mut se, format!("next payload not read after a hostile one: {next:?} n {n}"));
            break;
        }
    }
    se.print("session hostile+next");

    report_usage("random");
    let bad = [&ts, &tl, &td, &er, &ec, &ev, &ep, &se].iter().any(|t| t.panics > 0 || t.violations > 0);
    !bad
}
