// (d) the session check order and receive-index moves (included by main.rs).

/// Session check order and receive-index moves. Returns Ok(summary) or Err(first mismatch).
fn session_order() -> Result<String, String> {
    let mut log = Vec::new();
    let mut opener = PackSession::load(&[5; SEED_SIZE]).ok_or("load")?;
    let mut waiter = PackSession::load(&[5; SEED_SIZE]).ok_or("load")?;
    // Not open: answers first, even with an empty handler list and a bad limit.
    let r = waiter.unpack_repair(&[1, 2, 3], &mut [], 99);
    match &r {
        Err(UnpackError::Short(s)) if s.needed == 1 && s.left == 0 => log.push("not-open first"),
        other => return Err(format!("not open: {other:?}")),
    }
    let nonce = opener.start_with(&[2; NONCE_SIZE]).ok_or("start")?;
    if !waiter.join(&nonce) {
        return Err("join".into());
    }
    let n = 8;
    let mut next_body = 0u8;
    let mut send = |opener: &mut PackSession| {
        next_body = next_body.wrapping_add(1);
        let body = vec![next_body; 20];
        (session_pack(opener, &body, n), body)
    };
    let reads = |waiter: &mut PackSession, wire: &[u8], body: &[u8]| -> bool {
        let mut h = Rec::new(1, n);
        waiter.unpack_repair(wire, &mut [&mut h], 0).is_ok() && h.got.as_deref().map(|g| &g[1..]) == Some(body)
    };
    // Refusals of the call: the index must not move (the next payload at index 0 still reads).
    let (w0, b0) = send(&mut opener);
    let refusals: Vec<(&str, Box<dyn Fn(&mut PackSession) -> Result<usize, UnpackError>>)> = vec![
        ("empty", Box::new(|s: &mut PackSession| s.unpack_repair(&[1; 30], &mut [], 0))),
        ("duplicate", Box::new(|s: &mut PackSession| {
            let (mut a, mut b) = (Rec::new(1, 8), Rec::new(1, 4));
            s.unpack_repair(&[1; 30], &mut [&mut a, &mut b], 99)
        })),
        ("mixed", Box::new(|s: &mut PackSession| {
            let (mut a, mut b) = (Rec::new(1, 8), Rec::new(2, 4));
            s.unpack_repair(&[1; 30], &mut [&mut a, &mut b], 99)
        })),
        ("limit", Box::new(|s: &mut PackSession| {
            let mut a = Rec::new(1, 8);
            s.unpack_repair(&[1; 30], &mut [&mut a], 5)
        })),
    ];
    for (name, call) in &refusals {
        if call(&mut waiter).is_ok() {
            return Err(format!("{name} accepted"));
        }
    }
    if !reads(&mut waiter, &w0, &b0) {
        return Err("a refused call moved the receive index".into());
    }
    log.push("4 call refusals keep the index");
    // Hostile payloads: each uses one index; the next valid payload must read.
    let hostile: Vec<(&str, Box<dyn Fn(&[u8]) -> Vec<u8>>)> = vec![
        ("too_long 300 bytes", Box::new(|_: &[u8]| vec![0u8; 300])),
        ("short below n", Box::new(|_: &[u8]| vec![1u8; 5])),
        ("empty", Box::new(|_: &[u8]| Vec::new())),
        ("uncorrectable (t 0, 1 wrong)", Box::new(|w: &[u8]| {
            let mut v = w.to_vec();
            v[3] ^= 1;
            v
        })),
        ("unknown type after the pad", Box::new(|w: &[u8]| w.to_vec())),
    ];
    for (name, make) in &hostile {
        let (w, _) = send(&mut opener);
        let mut h = Rec::new(if *name == "unknown type after the pad" { 2 } else { 1 }, n);
        let r = waiter.unpack_repair(&make(&w), &mut [&mut h], 0);
        if r.is_ok() {
            return Err(format!("{name} accepted"));
        }
        let (w2, b2) = send(&mut opener);
        if !reads(&mut waiter, &w2, &b2) {
            return Err(format!("after {name} the next payload did not read"));
        }
    }
    log.push("5 hostile payloads use one index each");
    // Repair in a session: one wrong byte with t 1 is repaired; the pad is removed after.
    let (w, b) = send(&mut opener);
    let mut c = w.clone();
    c[2] ^= 0xff;
    let mut h = Rec::new(1, n);
    match waiter.unpack_repair(&c, &mut [&mut h], 1) {
        Ok(1) if h.got.as_deref().map(|g| &g[1..]) == Some(&b[..]) => log.push("session repair 1 byte"),
        other => return Err(format!("session repair: {other:?}")),
    }
    Ok(log.join("; "))
}
