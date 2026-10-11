use crate::walk::pack;
use crate::{flags, insert, times, u16, u8, MapScheme, PackError, Value, Values};

// AZ-2120 rule 3: a `times` under `flags` with count 0 and rounds that are empty is refused when a
// list kept beside them holds an item, as it is outside `flags`: the value must not be dropped.

fn ta() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("n"),
            flags(1, "f", vec![times(1, "n", vec![u8("pt")]), u16("heading")]),
        ],
    )
}

fn row(rounds: Option<Vec<Values>>, pt: Option<Vec<u8>>) -> Values {
    let mut vals = Values::new();
    insert(&mut vals, "n", Some(Value::U8(0)));
    insert(&mut vals, "heading", Some(Value::U16(90)));
    if let Some(rounds) = rounds {
        insert(&mut vals, "__times_1", Some(Value::Groups(rounds)));
    }
    if let Some(items) = pt {
        let items = items.into_iter().map(Value::U8).collect();
        insert(&mut vals, "pt", Some(Value::List(items)));
    }
    vals
}

#[test]
fn az2120_count_0_empty_rounds_and_a_kept_list_is_a_pack_error_naming_the_value() {
    match pack(&ta(), &row(Some(Vec::new()), Some(vec![5]))) {
        Err(PackError::Type(text)) => assert!(text.contains("'pt'"), "{text}"),
        other => panic!("{other:?}"),
    }
}

#[test]
fn az2120_count_0_empty_rounds_and_an_empty_kept_list_still_packs() {
    let raw = pack(&ta(), &row(Some(Vec::new()), Some(Vec::new()))).expect("pack");
    assert_eq!(crate::to_hex(&raw), "0100025a00");
}

#[test]
fn az2120_count_0_empty_rounds_alone_still_packs() {
    let raw = pack(&ta(), &row(Some(Vec::new()), None)).expect("pack");
    assert_eq!(crate::to_hex(&raw), "0100025a00");
}
