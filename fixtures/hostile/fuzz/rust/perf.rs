// (b) ECC repair time and (c) text amplification (included by main.rs).

// ---------------------------------------------------------------- (b) ecc time

fn ecctime(calls: usize) -> bool {
    let n = 32;
    let mut rng = Rng(0xECC7_1E);
    let words: Vec<(Vec<u8>, Vec<u8>)> = (0..64)
        .map(|_| {
            let mut clear = rng.fill(254 - n);
            clear[0] = 1;
            let w = protect(&clear, n);
            (clear, w)
        })
        .collect();
    let scheme = b_scheme(1, 254 - n, n);
    println!("ecctime: n {n}, N 254, {calls} calls per case, debug_assertions {}", cfg!(debug_assertions));
    type Make = Box<dyn Fn(&mut Rng, &[u8]) -> Vec<u8>>;
    let cases: Vec<(&str, usize, Make)> = vec![
        ("intact, t=0 (default)", 0, Box::new(|_: &mut Rng, w: &[u8]| w.to_vec())),
        ("intact, t=16", 16, Box::new(|_: &mut Rng, w: &[u8]| w.to_vec())),
        ("1 wrong, t=0 (default)", 0, Box::new(|r: &mut Rng, w: &[u8]| { let mut v = w.to_vec(); corrupt(&mut v, 1, r); v })),
        ("16 wrong, t=0 (default)", 0, Box::new(|r: &mut Rng, w: &[u8]| { let mut v = w.to_vec(); corrupt(&mut v, 16, r); v })),
        ("8 wrong, t=16", 16, Box::new(|r: &mut Rng, w: &[u8]| { let mut v = w.to_vec(); corrupt(&mut v, 8, r); v })),
        ("16 wrong, t=16 (max repair)", 16, Box::new(|r: &mut Rng, w: &[u8]| { let mut v = w.to_vec(); corrupt(&mut v, 16, r); v })),
        ("16 wrong at the end, t=16", 16, Box::new(|r: &mut Rng, w: &[u8]| { let mut v = w.to_vec(); let l = v.len(); for p in l - 16..l { v[p] ^= r.byte() | 1; } v })),
        ("16 wrong at the start, t=16", 16, Box::new(|r: &mut Rng, w: &[u8]| { let mut v = w.to_vec(); for p in 0..16 { v[p] ^= r.byte() | 1; } v })),
        ("17 wrong, t=16", 16, Box::new(|r: &mut Rng, w: &[u8]| { let mut v = w.to_vec(); corrupt(&mut v, 17, r); v })),
        ("32 wrong, t=16", 16, Box::new(|r: &mut Rng, w: &[u8]| { let mut v = w.to_vec(); corrupt(&mut v, 32, r); v })),
        ("random 254 bytes, t=16", 16, Box::new(|r: &mut Rng, _: &[u8]| r.fill(254))),
        ("all 0xff, t=16", 16, Box::new(|_: &mut Rng, _: &[u8]| vec![0xff; 254])),
    ];
    let mut ok_all = true;
    for (name, t, make) in &cases {
        let inputs: Vec<Vec<u8>> = (0..64).map(|i| make(&mut rng, &words[i].1)).collect();
        let mut times = Vec::with_capacity(calls);
        let (mut accepted, mut refused) = (0, 0);
        for i in 0..calls {
            let input = &inputs[i % 64];
            let started = Instant::now();
            let r = catch_unwind(AssertUnwindSafe(|| unpack_repair(&scheme, input, *t)));
            times.push(started.elapsed().as_nanos() as u64);
            match r {
                Ok(Ok(v)) => {
                    accepted += 1;
                    std::hint::black_box(v);
                }
                Ok(Err(_)) => refused += 1,
                Err(_) => {
                    ok_all = false;
                    println!("PANIC in {name}");
                }
            }
        }
        times.sort_unstable();
        let med = times[times.len() / 2];
        let p99 = times[times.len() * 99 / 100];
        let max = *times.last().unwrap();
        println!(
            "{name:<30} accepted {accepted:>6} refused {refused:>6}  median {:>7.1} us  p99 {:>7.1} us  max {:>8.1} us",
            med as f64 / 1e3,
            p99 as f64 / 1e3,
            max as f64 / 1e3
        );
        if max > 1_000_000_000 {
            ok_all = false;
        }
    }
    // Pure refusals that must not do arithmetic: a 16 MiB buffer (too_long) and a buffer shorter than n.
    let big = vec![0u8; 16 << 20];
    let started = Instant::now();
    let r = unpack_repair(&scheme, &big, 16);
    println!("16 MiB buffer, n 32: {:?} in {:.1} us", r.err(), started.elapsed().as_secs_f64() * 1e6);
    report_usage("ecctime");
    ok_all
}

// ---------------------------------------------------------------- (c) text amplification

/// The largest compact text: `о` x 32767 and a space in Russian mode, 65,535 UTF-8 bytes.
fn max_text_payload(codes: &Codes) -> Vec<u8> {
    let mut b = Bits::new(codes, RU);
    for _ in 0..32767 {
        b.sym(RU, 15);
    }
    b.sym(RU, shared(RU, 0));
    b.finish()
}

/// A payload of `bytes` bytes of mode switches only (Ukrainian <-> number): an empty text.
fn controls_payload(codes: &Codes, bytes: usize) -> Vec<u8> {
    let mut b = Bits::new(codes, UA);
    let pair = codes.modes[UA][sw(UA, NUM)].1 as usize + codes.modes[NUM][sw(NUM, UA)].1 as usize;
    while b.n + pair <= bytes * 8 {
        b.sym(UA, sw(UA, NUM));
        b.sym(NUM, sw(NUM, UA));
    }
    // Fill to exactly `bytes` with whole switches where possible; leftover bits are pad.
    let mut v = b.finish();
    v.truncate(bytes);
    v
}

fn timed_unpack(scheme: &MapScheme, packet: &[u8], reps: usize) -> (Result<Values, UnpackError>, f64) {
    let mut last = None;
    let started = Instant::now();
    for _ in 0..reps {
        // Drop the previous row first, so the peak is one row.
        drop(last.take());
        last = Some(unpack(scheme, packet));
    }
    (last.unwrap(), started.elapsed().as_secs_f64() / reps as f64)
}

/// (decoded UTF-8 bytes, String capacity held) of the strings in a row.
fn decoded_total(v: &Values) -> (usize, usize) {
    match v.get("l").or_else(|| v.get("s")) {
        Some(Some(Value::List(items))) => items.iter().fold((0, 0), |(l, c), i| match i {
            Value::Str(s) => (l + s.len(), c + s.capacity()),
            _ => (l, c),
        }),
        Some(Some(Value::Str(s))) => (s.len(), s.capacity()),
        _ => (0, 0),
    }
}

fn textamp(checkout: &str, case: &str) -> bool {
    let codes = Codes::load(checkout);
    let (cpu0, rss0) = usage();
    let (packet, scheme, reps, label): (Vec<u8>, MapScheme, usize, String) = match case {
        "one" => {
            let p = max_text_payload(&codes);
            let mut packet = vec![1u8];
            packet.extend(field(&p));
            (packet, s_scheme(), 200, format!("one compact text, payload {} bytes", p.len()))
        }
        "list1m" | "list8m" => {
            let p = field(&max_text_payload(&codes));
            let size = if case == "list1m" { 1 << 20 } else { 8 << 20 };
            let k = (size - 3) / p.len();
            let mut packet = vec![1u8, k as u8, (k >> 8) as u8];
            for _ in 0..k {
                packet.extend_from_slice(&p);
            }
            (packet, l_scheme(), 3, format!("list of {k} max texts"))
        }
        "controls" => {
            let p = controls_payload(&codes, 2_097_151);
            let mut packet = vec![1u8];
            packet.extend(field(&p));
            (packet, s_scheme(), 5, "one 2,097,151-byte payload of mode switches".to_string())
        }
        "short" => {
            // 65,535 list elements of a 3-byte field `ооо` (2-byte payload, 6 UTF-8 bytes each).
            let mut b = Bits::new(&codes, RU);
            for _ in 0..3 {
                b.sym(RU, 15);
            }
            let f = field(&b.finish());
            let mut packet = vec![1u8, 0xff, 0xff];
            for _ in 0..65535 {
                packet.extend_from_slice(&f);
            }
            (packet, l_scheme(), 3, format!("list of 65,535 fields {}", to_hex(&f)))
        }
        _ => panic!("textamp case: one | list1m | list8m | controls | short"),
    };
    let (cpu1, rss1) = usage();
    let (r, per_call) = timed_unpack(&scheme, &packet, reps);
    let (cpu2, rss2) = usage();
    let ok = r.is_ok();
    let (total, held) = r.as_ref().map(decoded_total).unwrap_or((0, 0));
    println!(
        "textamp {case}: {label}; packet {} bytes; accepted {ok}; decoded {} UTF-8 bytes ({:.3} per packet byte), String capacity held {} bytes ({:.3} per packet byte); {:.2} ms per unpack ({reps} reps)",
        packet.len(),
        total,
        total as f64 / packet.len() as f64,
        held,
        held as f64 / packet.len() as f64,
        per_call * 1e3
    );
    println!(
        "  peak RSS: start {rss0:.1} MB, after building the packet {rss1:.1} MB, after unpack {rss2:.1} MB (+{:.1} MB); cpu build {:.2} s, unpack {:.2} s",
        rss2 - rss1,
        cpu1 - cpu0,
        cpu2 - cpu1
    );
    drop(r);
    per_call < 1.0
}
