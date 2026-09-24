use packbin::pack;

struct MarkerRow {
    sid: u8,
}

fn main() {
    let row = MarkerRow { sid: 23 };
    let _ = pack(&row);
}
