use packbin::nostd::{self, dict, key, u8 as nu8, Num, Row, Scheme, DICT_KEY};
use packbin::{dict as sdict, insert, pack, to_hex, u8 as su8, unpack, MapScheme, Value, Values};
use std::collections::BTreeMap;

struct Item { k: Vec<u8>, v: u8 }
const CAP: usize = 64;
impl Row for Item {
    fn num(&self, id: u16) -> Option<Num> { if id == 0 { Some(Num::U8(self.v)) } else { None } }
    fn bytes(&self, id: u16) -> Option<&[u8]> { if id == DICT_KEY { Some(&self.k) } else { None } }
    fn set_num(&mut self, id: u16, v: Num) -> bool { if let (0, Num::U8(x)) = (id, v) { self.v = x; true } else { false } }
    fn set_bytes(&mut self, id: u16, b: &[u8]) -> bool { if id == DICT_KEY { self.k = b.to_vec(); true } else { false } }
    fn slots(&mut self, id: u16) -> Option<&mut [u8]> { if id == DICT_KEY { self.k = vec![0; CAP]; Some(&mut self.k) } else { None } }
    fn set_count(&mut self, id: u16, n: usize) -> bool { if id == DICT_KEY && n <= self.k.len() { self.k.truncate(n); true } else { false } }
}
#[derive(Default)]
struct Top { items: Vec<Item> }
impl Row for Top {
    fn num(&self, _: u16) -> Option<Num> { None }
    fn bytes(&self, _: u16) -> Option<&[u8]> { None }
    fn set_num(&mut self, _: u16, _: Num) -> bool { false }
    fn set_bytes(&mut self, _: u16, _: &[u8]) -> bool { false }
    fn count(&self, id: u16) -> Option<usize> { (id == 0).then_some(self.items.len()) }
    fn item(&self, id: u16, k: usize) -> Option<&dyn Row> { if id == 0 { self.items.get(k).map(|i| i as &dyn Row) } else { None } }
    fn set_count(&mut self, id: u16, n: usize) -> bool { id == 0 && self.items.len() == n || id == 0 }
    fn item_mut(&mut self, id: u16, k: usize) -> Option<&mut dyn Row> {
        if id != 0 { return None; }
        while self.items.len() <= k { self.items.push(Item { k: vec![], v: 0 }); }
        self.items.get_mut(k).map(|i| i as &mut dyn Row)
    }
}

fn std_pack(m: BTreeMap<String, Value>) -> Vec<u8> {
    let s = MapScheme::new(1, vec![sdict("d", su8("v"))]);
    let mut v = Values::new();
    insert(&mut v, "d", Some(Value::Map(m)));
    pack(&s, &v).expect("pack")
}

fn nostd_try(label: &str, keys: &[&[u8]]) {
    const F: [nostd::Field; 3] = [dict(0, 2), key(), nu8(0)];
    let scheme = Scheme::new(1, &F);
    let row = Top { items: keys.iter().enumerate().map(|(i, k)| Item { k: k.to_vec(), v: i as u8 + 1 }).collect() };
    let mut out = vec![0u8; 256];
    let mut scratch = vec![0u32; 3 * 64];
    match nostd::pack_with(&scheme, &row, &mut out, &mut scratch) {
        Ok(n) => {
            let wire = out[..n].to_vec();
            let mut back = Top::default();
            println!("  nostd {label}: pack OK {}; unpack = {:?}", to_hex(&wire), nostd::unpack(&scheme, &wire, &mut back).map_err(|f| f.error));
        }
        Err(f) => println!("  nostd {label}: pack Err {:?} (offset {}, field {})", f.error, f.offset, f.field),
    }
}

fn main() {
    println!("== Rust probes (compile-time check of U+D800 literal is in compile_fail/) ==");
    println!("char::from_u32(0xD800) = {:?}", char::from_u32(0xD800));
    println!("char::from_u32(0xDFFF) = {:?}", char::from_u32(0xDFFF));
    println!("String::from_utf16(&[0xD800]) = {:?}", String::from_utf16(&[0xD800]));
    println!("String::from_utf8(ED A0 80) = {:?}", String::from_utf8(vec![0xED, 0xA0, 0x80]));
    let lossy = String::from_utf16_lossy(&[0xD800]);
    println!("from_utf16_lossy(&[0xD800]) = {:?} bytes {:02x?} chars {:?}", lossy, lossy.as_bytes(), lossy.chars().map(|c| c as u32).collect::<Vec<_>>());
    println!("lossy == \"\\u{{FFFD}}\": {}", lossy == "\u{FFFD}");
    let lossy2 = String::from_utf16_lossy(&[0xDC00]);
    println!("lossy(0xDC00) == lossy(0xD800): {}", lossy == lossy2);

    println!("-- harness: normal two-key pack/unpack (std)");
    let mut m = BTreeMap::new();
    m.insert("a".to_string(), Value::U8(1));
    m.insert("b".to_string(), Value::U8(2));
    let w = std_pack(m);
    println!("  wire {}", to_hex(&w));
    let s = MapScheme::new(1, vec![sdict("d", su8("v"))]);
    println!("  unpack {:?}", unpack(&s, &w).map(|v| v.get("d").cloned()));

    println!("-- collision candidates in valid strings (std map)");
    let mut m = BTreeMap::new();
    m.insert("\u{FFFD}".to_string(), Value::U8(1));
    m.insert(String::from_utf16_lossy(&[0xD800]), Value::U8(2));
    m.insert(String::from_utf16_lossy(&[0xDC00]), Value::U8(3));
    println!("  map len after inserting FFFD, lossy(D800), lossy(DC00): {}", m.len());
    let w = std_pack(m);
    println!("  wire {}", to_hex(&w));
    println!("  unpack {:?}", unpack(&s, &w).map(|v| v.get("d").cloned()));

    println!("-- distinct valid keys never give equal key bytes (all pairs of 4 look-alikes)");
    let ks = ["\u{FFFD}", "\u{FFFD}\u{FFFD}", "\u{00E9}", "e\u{0301}", "\u{D7FF}", "\u{E000}", "\u{10FFFF}", ""];
    let mut ok = true;
    for a in ks { for b in ks { if a != b && a.as_bytes() == b.as_bytes() { ok = false; } } }
    let mut m = BTreeMap::new();
    for (i, k) in ks.iter().enumerate() { m.insert(k.to_string(), Value::U8(i as u8)); }
    let w = std_pack(m);
    println!("  distinct strings => distinct bytes: {ok}; packed {} keys, unpack ok: {}", ks.len(), unpack(&s, &w).is_ok());

    println!("-- nostd (key bytes API: Row::bytes -> &[u8])");
    nostd_try("two normal keys a,b", &[b"a", b"b"]);
    nostd_try("two keys U+FFFD", &["\u{FFFD}".as_bytes(), "\u{FFFD}".as_bytes()]);
    nostd_try("ED A0 80 (lone high half, CESU/WTF-8)", &[&[0xED, 0xA0, 0x80]]);
    nostd_try("ED A0 80 then ED B0 80 (two lone halves)", &[&[0xED, 0xA0, 0x80], &[0xED, 0xB0, 0x80]]);
    nostd_try("EF BF BD then ED A0 80", &[&[0xEF, 0xBF, 0xBD], &[0xED, 0xA0, 0x80]]);
    nostd_try("single byte FF", &[&[0xFF]]);
}
