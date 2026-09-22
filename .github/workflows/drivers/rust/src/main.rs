fn main() {
    let pkt = packbin::packet(vec![
        packbin::u8("type"),
        packbin::u16("sid"),
        packbin::i32("lat"),
        packbin::i32("lon"),
        packbin::u8("profile"),
        packbin::flags(
            "motion",
            vec![
                packbin::u16("heading"),
                packbin::u8("speed"),
                packbin::i16("altitude"),
            ],
        ),
    ]);
    let mut values = packbin::Values::new();
    packbin::insert(&mut values, "type", Some(packbin::Value::U8(64)));
    packbin::insert(&mut values, "sid", Some(packbin::Value::U16(1)));
    packbin::insert(&mut values, "lat", Some(packbin::Value::I32(500_000_000)));
    packbin::insert(&mut values, "lon", Some(packbin::Value::I32(300_000_000)));
    packbin::insert(&mut values, "profile", Some(packbin::Value::U8(1)));
    let bytes = packbin::pack(&pkt, &values).expect("pack");
    println!("{}", packbin::to_hex(&bytes));
}
