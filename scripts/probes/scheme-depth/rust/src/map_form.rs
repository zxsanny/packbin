//! The map form: `MapScheme` with `packbin::pack` and `packbin::unpack`, fields named by their order
//! id as text ("0", "1"), values keyed by those names.
use crate::{caught, hex, message, Cells};
use packbin::{eq, group, insert, pack, u8, unpack, when, Field, MapScheme, Value, Values};

/// `u8 "0"`, then `depth` `when("0" == 1)` inside each other, the innermost holding `u8 "1"`.
/// Every `when` is anchored at order id 1, the id of its first member. Built innermost first.
fn when_fields(depth: usize) -> Vec<Field> {
    let mut inner = vec![u8("1")];
    for _ in 0..depth {
        inner = vec![when(1, eq("0", Value::U8(1)), inner)];
    }
    let mut fields = vec![u8("0")];
    fields.extend(inner);
    fields
}

/// `depth` groups inside each other, anchored at id 0, the innermost holding `u8 "b"`.
fn group_fields(depth: usize) -> Vec<Field> {
    let mut inner = vec![u8("b")];
    for level in (0..depth).rev() {
        inner = vec![group(0, format!("g{level}"), inner)];
    }
    inner
}

fn values(shape: &str) -> Values {
    let mut row = Values::new();
    if shape == "when" {
        insert(&mut row, "0", Some(Value::U8(1)));
        insert(&mut row, "1", Some(Value::U8(7)));
    } else {
        insert(&mut row, "b", Some(Value::U8(7)));
    }
    row
}

pub fn run(shape: &str, depth: usize) -> Cells {
    let mut cells = Cells {
        shape: format!("{shape}-{depth}"),
        build: String::new(),
        pack: "-".to_string(),
        unpack: "-".to_string(),
    };
    let fields = if shape == "when" {
        when_fields(depth)
    } else {
        group_fields(depth)
    };
    let scheme = match caught(|| MapScheme::new(1, fields)) {
        Ok(scheme) => scheme,
        Err(text) => {
            cells.build = format!("refused: {}", message(&text));
            return cells;
        }
    };
    cells.build = "built".to_string();
    let given = values(shape);
    let packed = match caught(|| pack(&scheme, &given)) {
        Ok(Ok(bytes)) => bytes,
        Ok(Err(error)) => {
            cells.pack = format!("refused: {}", message(&format!("{error:?}")));
            std::mem::forget(scheme);
            return cells;
        }
        Err(text) => {
            cells.pack = format!("threw: {}", message(&text));
            std::mem::forget(scheme);
            return cells;
        }
    };
    cells.pack = hex(&packed);
    cells.unpack = match caught(|| unpack(&scheme, &packed)) {
        Ok(Ok(got)) if got == given => "same".to_string(),
        Ok(Ok(got)) => format!("differs: {}", message(&format!("{got:?}"))),
        Ok(Err(error)) => format!("refused: {}", message(&format!("{error:?}"))),
        Err(text) => format!("threw: {}", message(&text)),
    };
    std::mem::forget(scheme);
    cells
}
