// Probe calls: the schemes, unpack and repair wrappers, the mutator and the dispatch handler (included
// by main.rs).

// ---------------------------------------------------------------- schemes and calls

fn s_scheme() -> MapScheme {
    MapScheme::new(1, vec![utf8("s")])
}
fn l_scheme() -> MapScheme {
    MapScheme::new(1, vec![list("l", utf8("e"))])
}
fn d_scheme() -> MapScheme {
    MapScheme::new(1, vec![dict("d", packbin::u8("v"))])
}
/// A scheme whose clear message is the type byte and `clear_len - 1` raw bytes, with `n` parity bytes.
fn b_scheme(type_number: u8, clear_len: usize, n: usize) -> MapScheme {
    MapScheme::new(type_number as i32, vec![bytes("b", clear_len.max(1) - 1)]).with_parity(n)
}

fn text_of(v: &Values, name: &str) -> Option<String> {
    match v.get(name) {
        Some(Some(Value::Str(s))) => Some(s.clone()),
        _ => None,
    }
}

/// Unpacks one string field (`[01] + field`); Ok(text) or Err(debug of the error).
fn read_text(f: &[u8]) -> Result<String, String> {
    let mut packet = vec![1u8];
    packet.extend_from_slice(f);
    match unpack(&s_scheme(), &packet) {
        Ok(v) => Ok(text_of(&v, "s").unwrap_or_default()),
        Err(e) => Err(format!("{e:?}")),
    }
}

/// The protected message of `clear` (type byte first) with `n` parity bytes.
fn protect(clear: &[u8], n: usize) -> Vec<u8> {
    let scheme = b_scheme(clear[0], clear.len(), n);
    let mut vals = Values::new();
    insert(&mut vals, "b", Some(Value::Bytes(clear[1..].to_vec())));
    pack(&scheme, &vals).expect("pack")
}

/// unpack_repair with the bytes-shaped scheme whose type number is the first received byte.
fn repair_bytes(buf: &[u8], n: usize, t: usize) -> Result<(Vec<u8>, usize), UnpackError> {
    repair_typed(buf, n, t, buf.first().copied().unwrap_or(1))
}

/// unpack_repair with the bytes-shaped scheme of type `ty`; Ok((clear, repaired)).
fn repair_typed(buf: &[u8], n: usize, t: usize, ty: u8) -> Result<(Vec<u8>, usize), UnpackError> {
    let clear_len = buf.len().saturating_sub(n).max(1);
    let scheme = b_scheme(ty, clear_len, n);
    let (vals, repaired) = unpack_repair(&scheme, buf, t)?;
    let mut clear = vec![ty];
    if let Some(Some(Value::Bytes(b))) = vals.get("b") {
        clear.extend_from_slice(b);
    }
    Ok((clear, repaired))
}

fn hamming(a: &[u8], b: &[u8]) -> usize {
    a.iter().zip(b).filter(|(x, y)| x != y).count()
}

/// Changes `k` distinct positions of `w`, each to a different value.
fn corrupt(w: &mut [u8], k: usize, rng: &mut Rng) -> Vec<usize> {
    let mut hit = Vec::new();
    while hit.len() < k.min(w.len()) {
        let p = rng.below(w.len());
        if !hit.contains(&p) {
            hit.push(p);
            w[p] ^= rng.byte() | 1;
        }
    }
    hit
}

fn mutate(rng: &mut Rng, data: &mut Vec<u8>, pool: &[Vec<u8>]) {
    const SPECIAL: [u8; 12] = [0x00, 0x10, 0x7f, 0x80, 0xff, 0xc0, 0xe0, 0xf0, 0xf4, 0xed, 0x1c, 0xfc];
    for _ in 0..1 + rng.below(4) {
        let len = data.len();
        match rng.below(9) {
            0 if len > 0 => {
                let p = rng.below(len);
                data[p] ^= 1 << rng.below(8);
            }
            1 if len > 0 => {
                let p = rng.below(len);
                data[p] = rng.byte();
            }
            2 => {
                let p = rng.below(len + 1);
                data.insert(p, rng.byte());
            }
            3 if len > 0 => {
                data.remove(rng.below(len));
            }
            4 => data.truncate(rng.below(len + 1)),
            5 => {
                let k = 1 + rng.below(16);
                let extra = rng.fill(k);
                data.extend_from_slice(&extra);
            }
            6 if !pool.is_empty() => {
                let other = &pool[rng.below(pool.len())];
                let cut = rng.below(len + 1);
                let from = rng.below(other.len() + 1);
                data.truncate(cut);
                data.extend_from_slice(&other[from..]);
            }
            7 if len > 0 => {
                let p = rng.below(len);
                data[p] = SPECIAL[rng.below(SPECIAL.len())];
            }
            8 => {
                // Rewrite the leading count with a random one of 1 to 3 bytes.
                let drop = (1 + rng.below(3)).min(data.len());
                data.drain(..drop);
                let groups = 1 + rng.below(3);
                let c = rng.below(1 << (7 * groups));
                let mut v = varint(c);
                v.extend_from_slice(data);
                *data = v;
            }
            _ => {}
        }
    }
}

/// A dispatch handler that keeps the message it was handed.
struct Rec {
    ty: u8,
    n: usize,
    got: Option<Vec<u8>>,
}

impl Rec {
    fn new(ty: u8, n: usize) -> Rec {
        Rec { ty, n, got: None }
    }
}

impl DispatchHandler for Rec {
    fn type_number(&self) -> u8 {
        self.ty
    }
    fn parity(&self) -> usize {
        self.n
    }
    fn handle(&mut self, body: &[u8]) -> Result<(), UnpackError> {
        self.got = Some(body.to_vec());
        Ok(())
    }
}
