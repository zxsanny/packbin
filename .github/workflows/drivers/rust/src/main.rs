use packbin::{flags, i16, u16, u8, BoundField, BinaryPacker, Scheme};

#[derive(Default)]
struct PositionRow {
    sid: u16,
    lat: i32,
    lon: i32,
    profile: u8,
}

fn main() {
    let scheme = Scheme::new(
        0x40,
        [
            BoundField::u16(
                0,
                |r: &PositionRow| r.sid,
                |r: &mut PositionRow, v| r.sid = v,
            )
            .into(),
            BoundField::i32(
                1,
                |r: &PositionRow| r.lat,
                |r: &mut PositionRow, v| r.lat = v,
            )
            .into(),
            BoundField::i32(
                2,
                |r: &PositionRow| r.lon,
                |r: &mut PositionRow, v| r.lon = v,
            )
            .into(),
            BoundField::u8(
                3,
                |r: &PositionRow| r.profile,
                |r: &mut PositionRow, v| r.profile = v,
            )
            .into(),
            flags(
                "motion",
                vec![u16("heading"), u8("speed"), i16("altitude")],
            )
            .into(),
        ],
    );
    let row = PositionRow {
        sid: 1,
        lat: 500_000_000,
        lon: 300_000_000,
        profile: 1,
    };
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    println!("{}", packbin::to_hex(&bytes));
}
