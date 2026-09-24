use crate::field::{packet, u8 as field_u8, Field, FieldKind, Packet};
use crate::value::{name_of, Name, PackError, UnpackError, Value, Values};
use crate::walk;
use std::marker::PhantomData;

pub struct Scheme<T> {
    packet: Packet,
    binders: Vec<Binder<T>>,
    _marker: PhantomData<T>,
}

struct Binder<T> {
    name: Name,
    get: Box<dyn Fn(&T) -> Value>,
    set: Box<dyn Fn(&mut T, &Value)>,
}

pub struct BoundField<T> {
    field: Field,
    name: Name,
    get: Box<dyn Fn(&T) -> Value>,
    set: Box<dyn Fn(&mut T, &Value)>,
}

pub enum SchemeItem<T> {
    Layout(Field),
    Bound(BoundField<T>),
}

impl<T> From<Field> for SchemeItem<T> {
    fn from(field: Field) -> Self {
        if !matches!(field.kind, FieldKind::TypeNum { .. }) {
            panic!("scheme data fields need get/set accessors");
        }
        SchemeItem::Layout(field)
    }
}

impl<T> From<BoundField<T>> for SchemeItem<T> {
    fn from(field: BoundField<T>) -> Self {
        SchemeItem::Bound(field)
    }
}

impl<T: 'static> BoundField<T> {
    pub fn u8(
        name: impl AsRef<str>,
        get: impl Fn(&T) -> u8 + 'static,
        set: impl Fn(&mut T, u8) + 'static,
    ) -> Self {
        let name = name_of(name);
        let field = field_u8(name.as_ref());
        BoundField {
            field,
            name,
            get: Box::new(move |row| Value::U8(get(row))),
            set: Box::new(move |row, value| {
                if let Value::U8(v) = value {
                    set(row, *v);
                }
            }),
        }
    }
}

impl<T: 'static> Scheme<T> {
    pub fn of(items: impl IntoIterator<Item = SchemeItem<T>>) -> Self {
        let mut fields = Vec::new();
        let mut binders = Vec::new();
        for item in items {
            match item {
                SchemeItem::Layout(field) => fields.push(field),
                SchemeItem::Bound(bound) => {
                    fields.push(bound.field);
                    binders.push(Binder {
                        name: bound.name,
                        get: bound.get,
                        set: bound.set,
                    });
                }
            }
        }
        Scheme {
            packet: packet(fields),
            binders,
            _marker: PhantomData,
        }
    }
}

pub struct BinaryPacker;

impl BinaryPacker {
    pub fn pack<T>(scheme: &Scheme<T>, row: &T) -> Result<Vec<u8>, PackError> {
        let mut values = Values::new();
        for binder in &scheme.binders {
            values.insert(binder.name.clone(), Some((binder.get)(row)));
        }
        walk::pack(&scheme.packet, &values)
    }

    pub fn unpack<T: Default>(scheme: &Scheme<T>, bytes: &[u8]) -> Result<T, UnpackError> {
        let values = walk::unpack(&scheme.packet, bytes)?;
        let mut row = T::default();
        for binder in &scheme.binders {
            if let Some(Some(value)) = values.get(&binder.name) {
                (binder.set)(&mut row, value);
            }
        }
        Ok(row)
    }
}
