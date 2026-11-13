//! The typed form: `Scheme<Row>` built from `SchemeItem`s, with `BinaryPacker::pack` and
//! `BinaryPacker::unpack_with`. `x` is an `opt_u8` (absent is `None`), `b` a `bool_flag` (set only
//! for `Some(true)`, unpacked as `Some(true)` or left `None`). Ids: both `flags` and `x` are 0, `b`
//! is 1.
use crate::{caught, compared, hex, one_line, stopped, values_of, Cells};
use packbin::{BinaryPacker, BoundField, Scheme, SchemeItem};

#[derive(Clone, Debug, Default, PartialEq)]
struct Row {
    x: Option<u8>,
    b: Option<bool>,
}

fn build() -> Scheme<Row> {
    let x = BoundField::opt_u8(0, |r: &Row| r.x, |r: &mut Row, v| r.x = v);
    let b = BoundField::bool_flag(1, |r: &Row| r.b, |r: &mut Row, v| r.b = v);
    Scheme::new(
        1,
        [SchemeItem::flags(
            0,
            [SchemeItem::flags(0, [x.into()]), b.into()],
        )],
    )
}

/// `b = Some(false)` leaves the bit clear as `None` does, so the two compare equal.
fn present(row: &Row) -> Row {
    Row {
        x: row.x,
        b: row.b.filter(|b| *b),
    }
}

pub fn probe(shape: &str) -> Cells {
    let scheme = match caught(build) {
        Ok(scheme) => scheme,
        Err(message) => return stopped(&[format!("refused: panic: {message}")]),
    };
    let (x, b) = values_of(shape);
    let row = Row { x, b };
    let packed = match caught(|| BinaryPacker::pack(&scheme, &row)) {
        Ok(Ok(bytes)) => bytes,
        Ok(Err(error)) => {
            return stopped(&[
                "built".into(),
                format!("refused: {}", one_line(&format!("{error:?}"))),
            ])
        }
        Err(message) => return stopped(&["built".into(), format!("refused: panic: {message}")]),
    };
    let mut got: Option<Row> = None;
    let read =
        caught(|| BinaryPacker::unpack_with(&packed, &mut [&mut scheme.on(|r| got = Some(r))]));
    let unpacked = match read {
        Ok(Ok(())) => match got {
            Some(got) => compared(shape, || {
                if present(&got) == present(&row) {
                    "same".to_string()
                } else {
                    format!("differs: {got:?}")
                }
            }),
            None => "refused: no row came back".to_string(),
        },
        Ok(Err(error)) => format!("refused: {}", one_line(&format!("{error:?}"))),
        Err(message) => format!("threw: {message}"),
    };
    ["built".into(), hex(&packed), unpacked]
}
