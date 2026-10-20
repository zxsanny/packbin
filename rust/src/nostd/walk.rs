use super::error::{Error, Fault};
use super::io::{Reader, Writer};
use super::row::{Num, Row};
use super::scheme::{validate, Field, Kind, Scheme};

/// Packs `row` into `out` and returns the bytes written: the type number, then each field.
/// A scheme that is not valid, a row without a value for a field (or with one of another kind or
/// length) and an `out` that is too small are errors; the failure names the field.
pub fn pack<R: Row + ?Sized>(scheme: &Scheme<'_>, row: &R, out: &mut [u8]) -> Result<usize, Fault> {
    validate(scheme)?;
    let mut writer = Writer::new(out);
    writer.put(&[scheme.type_number], -1)?;
    for field in scheme.fields {
        pack_field(&mut writer, field, row)?;
    }
    Ok(writer.len())
}

/// Like [`pack`], into a new `Vec` of at most `limit` bytes (needs the `alloc` feature).
#[cfg(feature = "alloc")]
pub fn pack_vec<R: Row + ?Sized>(
    scheme: &Scheme<'_>,
    row: &R,
    limit: usize,
) -> Result<alloc::vec::Vec<u8>, Fault> {
    let mut out = alloc::vec![0u8; limit];
    let n = pack(scheme, row, &mut out)?;
    out.truncate(n);
    Ok(out)
}

/// Unpacks `bytes` into `row` and returns the bytes read, all of them. A failure may leave the
/// fields read before it in `row`. Nothing is read from a packet of another type number
/// ([`Error::TypeMismatch`], `needed` the expected one).
pub fn unpack<R: Row + ?Sized>(
    scheme: &Scheme<'_>,
    bytes: &[u8],
    row: &mut R,
) -> Result<usize, Fault> {
    validate(scheme)?;
    let mut reader = Reader::new(bytes);
    let first = reader.take(1, -1)?;
    if first.first() != Some(&scheme.type_number) {
        return Err(Fault::new(
            Error::TypeMismatch,
            0,
            -1,
            usize::from(scheme.type_number),
        ));
    }
    for field in scheme.fields {
        unpack_field(&mut reader, field, row)?;
    }
    reader.finish()?;
    Ok(reader.pos())
}

fn bad_value(writer_len: usize, field: &Field) -> Fault {
    Fault::new(Error::BadValue, writer_len, i32::from(field.id), 0)
}

fn pack_field<R: Row + ?Sized>(
    writer: &mut Writer<'_>,
    field: &Field,
    row: &R,
) -> Result<(), Fault> {
    let id = i32::from(field.id);
    if field.kind == Kind::Bytes {
        let value = row
            .bytes(field.id)
            .filter(|b| b.len() == usize::from(field.size))
            .ok_or_else(|| bad_value(writer.len(), field))?;
        return writer.put(value, id);
    }
    let num = row
        .num(field.id)
        .filter(|n| n.kind() == field.kind)
        .ok_or_else(|| bad_value(writer.len(), field))?;
    let width = field
        .kind
        .width()
        .ok_or_else(|| bad_value(writer.len(), field))?;
    let little = num.bits().to_le_bytes();
    let mut ordered = [0u8; 8];
    let low = little
        .get(..width)
        .ok_or_else(|| bad_value(writer.len(), field))?;
    for (slot, byte) in ordered.iter_mut().zip(low.iter()) {
        *slot = *byte;
    }
    let wire = ordered
        .get_mut(..width)
        .ok_or_else(|| bad_value(writer.len(), field))?;
    if field.big_endian {
        wire.reverse();
    }
    writer.put(wire, id)
}

fn unpack_field<R: Row + ?Sized>(
    reader: &mut Reader<'_>,
    field: &Field,
    row: &mut R,
) -> Result<(), Fault> {
    let id = i32::from(field.id);
    let at = reader.pos();
    if field.kind == Kind::Bytes {
        let value = reader.take(usize::from(field.size), id)?;
        return if row.set_bytes(field.id, value) {
            Ok(())
        } else {
            Err(bad_value(at, field))
        };
    }
    let width = field.kind.width().ok_or_else(|| bad_value(at, field))?;
    let wire = reader.take(width, id)?;
    let mut bits: u64 = 0;
    if field.big_endian {
        for byte in wire {
            bits = (bits << 8) | u64::from(*byte);
        }
    } else {
        for byte in wire.iter().rev() {
            bits = (bits << 8) | u64::from(*byte);
        }
    }
    let num = Num::from_bits(field.kind, bits).ok_or_else(|| bad_value(at, field))?;
    if row.set_num(field.id, num) {
        Ok(())
    } else {
        Err(bad_value(at, field))
    }
}
