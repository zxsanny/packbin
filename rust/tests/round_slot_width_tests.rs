use packbin::{
    bytes, dict, eq, flag_byte, flags, group, insert, list, pack, repeat, sized, times, to_hex, u2,
    u8, unpack, when, MapScheme, PackError, ShortPacket, UnpackError, Value, Values,
};

// AZ-2382 (U2): a round of a `repeat` or `times` charges `max_slots` the number of distinct names it
// can hold, as TypeScript does (`_docs/03_implementation/reference_loop21_slots.md` section 1, rows 1
// to 14). A non-empty group's own name, `flags`, a flag byte and the anchors are no slot; an
// empty group's name is; a name twice in a round is one slot. Rust takes a repeat's rounds as
// `Value::Groups` under `__repeat__`, so a row's lists become one `Values` per round.

fn v(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

fn n(x: u8) -> Value {
    Value::U8(x)
}

fn rounds(rows: &[Values]) -> Values {
    v(&[("__repeat__", Value::Groups(rows.to_vec()))])
}

fn hex_of(result: Result<Vec<u8>, PackError>) -> Result<String, PackError> {
    result.map(|raw| to_hex(&raw))
}

fn from_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

fn over(member: &str, need: usize, limit: usize) -> PackError {
    PackError::Type(format!(
        "{member}: the rounds would hold {need} slots, above the limit of {limit} slots"
    ))
}

/// One reference row: the body of `repeat(0, ...)`, its slot width, the rounds the table packs, the
/// third round, the hex at `max_slots` = 2W and at 3W, and what is left when unpack refuses round 3.
struct Row {
    id: u32,
    body: fn() -> Vec<packbin::Field>,
    width: usize,
    member: &'static str,
    two: Vec<Values>,
    third: Values,
    hex2: &'static str,
    hex3: &'static str,
    left: usize,
}

fn scheme(row: &Row, max_slots: usize) -> MapScheme {
    MapScheme::new(1, vec![repeat(0, (row.body)())]).with_limits(65_535, max_slots)
}

fn rows() -> Vec<Row> {
    vec![
        Row {
            id: 1,
            body: || vec![u8("a"), flags(1, "f", vec![group(1, "g", vec![])])],
            width: 2,
            member: "a",
            two: vec![v(&[("a", n(1)), ("g", n(1))]), v(&[("a", n(2))])],
            third: v(&[("a", n(3)), ("g", n(1))]),
            hex2: "0101010200",
            hex3: "01010102000301",
            left: 2,
        },
        Row {
            id: 2,
            body: || {
                vec![
                    u8("m"),
                    when(1, eq("m", n(1)), vec![u8("k")]),
                    when(2, eq("m", n(2)), vec![u8("k")]),
                ]
            },
            width: 2,
            member: "m",
            two: vec![v(&[("m", n(1)), ("k", n(7))]), v(&[("m", n(2)), ("k", n(8))])],
            third: v(&[("m", n(1)), ("k", n(9))]),
            hex2: "0101070208",
            hex3: "01010702080109",
            left: 2,
        },
        Row {
            id: 3,
            body: || vec![flags(0, "f", vec![group(0, "on", vec![]), u8("v")])],
            width: 2,
            member: "on",
            two: vec![v(&[("on", n(1)), ("v", n(5))]), v(&[("on", n(1)), ("v", n(6))])],
            third: v(&[("on", n(1)), ("v", n(7))]),
            hex2: "0103050306",
            hex3: "01030503060307",
            left: 2,
        },
        Row {
            id: 4,
            body: || {
                let m = flag_byte("m");
                vec![m.byte(), m.bit(u8("a")), m.bit(u8("b"))]
            },
            width: 2,
            member: "a",
            two: vec![v(&[("a", n(1)), ("b", n(4))]), v(&[("a", n(2)), ("b", n(5))])],
            third: v(&[("a", n(3)), ("b", n(6))]),
            hex2: "01030104030205",
            hex3: "01030104030205030306",
            left: 3,
        },
        Row {
            id: 5,
            body: || vec![u8("m"), when(1, eq("m", n(1)), vec![u8("k")])],
            width: 2,
            member: "m",
            two: vec![v(&[("m", n(0))]), v(&[("m", n(0))])],
            third: v(&[("m", n(0))]),
            hex2: "010000",
            hex3: "01000000",
            left: 1,
        },
        Row {
            id: 6,
            body: || {
                vec![
                    u8("a"),
                    group(1, "g", vec![u8("b"), group(2, "h", vec![u8("c")])]),
                ]
            },
            width: 3,
            member: "a",
            two: vec![
                v(&[("a", n(1)), ("b", n(4)), ("c", n(7))]),
                v(&[("a", n(2)), ("b", n(5)), ("c", n(8))]),
            ],
            third: v(&[("a", n(3)), ("b", n(6)), ("c", n(9))]),
            hex2: "01010407020508",
            hex3: "01010407020508030609",
            left: 3,
        },
        Row {
            id: 7,
            body: || vec![u8("a"), group(1, "g", vec![u8("b")])],
            width: 2,
            member: "a",
            two: vec![v(&[("a", n(1)), ("b", n(4))]), v(&[("a", n(2)), ("b", n(5))])],
            third: v(&[("a", n(3)), ("b", n(6))]),
            hex2: "0101040205",
            hex3: "01010402050306",
            left: 2,
        },
        Row {
            id: 8,
            body: || vec![u8("a"), u2(&["p", "q", "r"])],
            width: 4,
            member: "a",
            two: vec![
                v(&[("a", n(1)), ("p", n(1)), ("q", n(2)), ("r", n(3))]),
                v(&[("a", n(2)), ("p", n(1)), ("q", n(2)), ("r", n(3))]),
            ],
            third: v(&[("a", n(3)), ("p", n(1)), ("q", n(2)), ("r", n(3))]),
            hex2: "0101390239",
            hex3: "01013902390339",
            left: 2,
        },
        Row {
            id: 9,
            body: || vec![u8("n"), list("l", u8("e")), dict("d", u8("e"))],
            width: 3,
            member: "n",
            two: vec![
                v(&[("n", n(1)), ("l", Value::List(vec![n(0), n(1)])), ("d", map(0))]),
                v(&[("n", n(2)), ("l", Value::List(vec![n(1), n(2)])), ("d", map(1))]),
            ],
            third: v(&[("n", n(3)), ("l", Value::List(vec![n(2), n(3)])), ("d", map(2))]),
            hex2: "010102000001010001006b000202000102010001006b01",
            hex3: "010102000001010001006b000202000102010001006b010302000203010001006b02",
            left: 11,
        },
        Row {
            id: 10,
            body: || vec![u8("n"), bytes("b", 2), sized("s", "n")],
            width: 3,
            member: "n",
            two: vec![
                v(&[("n", n(1)), ("b", Value::Bytes(vec![0, 0])), ("s", Value::Bytes(vec![9]))]),
                v(&[("n", n(1)), ("b", Value::Bytes(vec![1, 1])), ("s", Value::Bytes(vec![9]))]),
            ],
            third: v(&[("n", n(1)), ("b", Value::Bytes(vec![2, 2])), ("s", Value::Bytes(vec![9]))]),
            hex2: "010100000901010109",
            hex3: "01010000090101010901020209",
            left: 4,
        },
    ]
}

fn map(k: u8) -> Value {
    Value::Map([("k".to_string(), n(k))].into_iter().collect())
}

fn three(row: &Row) -> Values {
    let mut all = row.two.clone();
    all.push(row.third.clone());
    rounds(&all)
}

#[test]
fn ac1_rows_1_to_10_two_rounds_pack_exactly_at_the_limit() {
    for row in rows() {
        // Arrange
        let at_limit = scheme(&row, 2 * row.width);

        // Act
        let wire = hex_of(pack(&at_limit, &rounds(&row.two)));

        // Assert
        assert_eq!(wire, Ok(row.hex2.to_string()), "row {}", row.id);
    }
}

#[test]
fn ac1_rows_1_to_10_the_third_round_is_refused_naming_the_first_member() {
    for row in rows() {
        // Arrange
        let at_limit = scheme(&row, 2 * row.width);

        // Act
        let refused = pack(&at_limit, &three(&row));

        // Assert
        assert_eq!(
            refused,
            Err(over(row.member, 3 * row.width, 2 * row.width)),
            "row {}",
            row.id
        );
    }
}

#[test]
fn ac1_rows_1_to_10_three_rounds_pack_at_three_widths() {
    for row in rows() {
        // Arrange
        let roomy = scheme(&row, 3 * row.width);

        // Act
        let wire = hex_of(pack(&roomy, &three(&row)));

        // Assert
        assert_eq!(wire, Ok(row.hex3.to_string()), "row {}", row.id);
    }
}

#[test]
fn ac1_rows_1_to_10_unpack_refuses_the_same_third_round() {
    for row in rows() {
        // Arrange
        let at_limit = scheme(&row, 2 * row.width);

        // Act
        let refused = unpack(&at_limit, &from_hex(row.hex3));

        // Assert: Rust names the field "repeat" (a refused round has no name of its own)
        assert_eq!(
            refused,
            Err(UnpackError::Short(ShortPacket {
                field: "repeat".to_string(),
                needed: 0,
                left: row.left,
            })),
            "row {}",
            row.id
        );
    }
}

#[test]
fn ac2_rows_1_to_10_the_packet_written_at_the_limit_unpacks_and_packs_again() {
    for row in rows() {
        // Arrange
        let at_limit = scheme(&row, 2 * row.width);
        let wire = from_hex(row.hex2);

        // Act
        let values = unpack(&at_limit, &wire).unwrap_or_else(|e| panic!("row {}: {e:?}", row.id));
        let again = hex_of(pack(&at_limit, &values));

        // Assert
        assert_eq!(again, Ok(row.hex2.to_string()), "row {}", row.id);
    }
}

#[test]
fn rows_1_to_10_one_slot_below_two_widths_refuses_the_second_round() {
    for row in rows() {
        // Arrange
        let below = scheme(&row, 2 * row.width - 1);

        // Act
        let refused = pack(&below, &rounds(&row.two));

        // Assert
        assert_eq!(
            refused,
            Err(over(row.member, 2 * row.width, 2 * row.width - 1)),
            "row {}",
            row.id
        );
    }
}

/// `u8 n; times n { u8 m; when m == 1 { u8 k }; when m == 2 { u8 k } }`, W = 2
fn times_scheme(max_slots: usize) -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("n"),
            times(
                1,
                "n",
                vec![
                    u8("m"),
                    when(2, eq("m", n(1)), vec![u8("k")]),
                    when(3, eq("m", n(2)), vec![u8("k")]),
                ],
            ),
        ],
    )
    .with_limits(65_535, max_slots)
}

fn times_row(count: u8, ms: &[(u8, Option<u8>)]) -> Values {
    let rows: Vec<Values> = ms
        .iter()
        .map(|(m, k)| {
            let mut r = v(&[("m", n(*m))]);
            if let Some(k) = k {
                insert(&mut r, "k", Some(n(*k)));
            }
            r
        })
        .collect();
    let mut vals = v(&[("n", n(count))]);
    insert(&mut vals, "__times_1", Some(Value::Groups(rows)));
    vals
}

#[test]
fn row_11_a_times_of_two_rounds_packs_at_four_slots() {
    // Arrange
    let vals = times_row(2, &[(1, Some(7)), (2, Some(8))]);

    // Act
    let wire = hex_of(pack(&times_scheme(4), &vals));

    // Assert
    assert_eq!(wire, Ok("010201070208".to_string()));
}

#[test]
fn row_12_a_third_times_round_is_refused_at_four_slots() {
    // Arrange
    let vals = times_row(3, &[(1, Some(7)), (2, Some(8)), (1, Some(9))]);

    // Act
    let refused = pack(&times_scheme(4), &vals);
    let by_unpack = unpack(&times_scheme(4), &from_hex("0103010702080109"));

    // Assert
    assert_eq!(refused, Err(over("m", 6, 4)));
    assert_eq!(
        by_unpack,
        Err(UnpackError::Short(ShortPacket {
            field: "times".to_string(),
            needed: 0,
            left: 2,
        }))
    );
}

/// `u8 n; times n { u8 a }; repeat { u8 b }`, one slot per round
fn one_counter_scheme(max_slots: usize) -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("n"),
            times(1, "n", vec![u8("a")]),
            repeat(2, vec![u8("b")]),
        ],
    )
    .with_limits(65_535, max_slots)
}

fn one_counter_row(b: &[u8]) -> Values {
    let mut vals = v(&[("n", n(1)), ("a", Value::List(vec![n(1)]))]);
    let rows: Vec<Values> = b.iter().map(|x| v(&[("b", n(*x))])).collect();
    insert(&mut vals, "__repeat__", Some(Value::Groups(rows)));
    vals
}

#[test]
fn row_13_one_counter_per_call_is_shared_by_a_times_and_a_repeat() {
    // Arrange
    let vals = one_counter_row(&[2, 3]);

    // Act
    let wire = hex_of(pack(&one_counter_scheme(3), &vals));

    // Assert: 1 + 2 rounds = 3 slots
    assert_eq!(wire, Ok("0101010203".to_string()));
}

#[test]
fn row_14_the_fourth_slot_of_the_shared_counter_is_refused() {
    // Arrange
    let vals = one_counter_row(&[2, 3, 4]);

    // Act
    let refused = pack(&one_counter_scheme(3), &vals);

    // Assert
    assert_eq!(refused, Err(over("b", 4, 3)));
}
