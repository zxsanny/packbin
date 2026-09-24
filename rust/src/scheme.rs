use crate::field::{
    i32 as field_i32, u16 as field_u16, u8 as field_u8, utf8 as field_utf8, Field, MapScheme,
};
use crate::value::{name_of, Name, PackError, ShortPacket, UnpackError, Value, Values};
use crate::walk;
use std::collections::HashSet;
use std::marker::PhantomData;

pub struct Scheme<T> {
    layout: MapScheme,
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
    Bound(BoundField<T>),
    Field(Field),
}

impl<T> From<BoundField<T>> for SchemeItem<T> {
    fn from(field: BoundField<T>) -> Self {
        SchemeItem::Bound(field)
    }
}

impl<T> From<Field> for SchemeItem<T> {
    fn from(field: Field) -> Self {
        SchemeItem::Field(field)
    }
}

impl<T: 'static> BoundField<T> {
    pub fn u8(
        name: impl AsRef<str>,
        get: impl Fn(&T) -> u8 + 'static,
        set: impl Fn(&mut T, u8) + 'static,
    ) -> Self {
        let name = name_of(name);
        BoundField {
            field: field_u8(name.as_ref()),
            name,
            get: Box::new(move |row| Value::U8(get(row))),
            set: Box::new(move |row, value| {
                if let Value::U8(v) = value {
                    set(row, *v);
                }
            }),
        }
    }

    pub fn u16(
        name: impl AsRef<str>,
        get: impl Fn(&T) -> u16 + 'static,
        set: impl Fn(&mut T, u16) + 'static,
    ) -> Self {
        let name = name_of(name);
        BoundField {
            field: field_u16(name.as_ref()),
            name,
            get: Box::new(move |row| Value::U16(get(row))),
            set: Box::new(move |row, value| {
                if let Value::U16(v) = value {
                    set(row, *v);
                }
            }),
        }
    }

    pub fn i32(
        name: impl AsRef<str>,
        get: impl Fn(&T) -> i32 + 'static,
        set: impl Fn(&mut T, i32) + 'static,
    ) -> Self {
        let name = name_of(name);
        BoundField {
            field: field_i32(name.as_ref()),
            name,
            get: Box::new(move |row| Value::I32(get(row))),
            set: Box::new(move |row, value| {
                if let Value::I32(v) = value {
                    set(row, *v);
                }
            }),
        }
    }

    pub fn utf8(
        name: impl AsRef<str>,
        get: impl Fn(&T) -> String + 'static,
        set: impl Fn(&mut T, String) + 'static,
    ) -> Self {
        let name = name_of(name);
        BoundField {
            field: field_utf8(name.as_ref()),
            name,
            get: Box::new(move |row| Value::Str(get(row))),
            set: Box::new(move |row, value| {
                if let Value::Str(v) = value {
                    set(row, v.clone());
                }
            }),
        }
    }
}

impl<T: 'static> Scheme<T> {
    pub fn new(type_number: i32, fields: impl IntoIterator<Item = SchemeItem<T>>) -> Self {
        let mut layout_fields = Vec::new();
        let mut binders = Vec::new();
        for item in fields {
            match item {
                SchemeItem::Bound(bound) => {
                    layout_fields.push(bound.field);
                    binders.push(Binder {
                        name: bound.name,
                        get: bound.get,
                        set: bound.set,
                    });
                }
                SchemeItem::Field(field) => layout_fields.push(field),
            }
        }
        Scheme {
            layout: MapScheme::new(type_number, layout_fields),
            binders,
            _marker: PhantomData,
        }
    }

    pub fn type_number(&self) -> u8 {
        self.layout.type_number()
    }

    pub fn on<'a, F>(&'a self, handler: F) -> On<'a, T, F>
    where
        F: FnMut(T),
    {
        On {
            scheme: self,
            handler,
        }
    }
}

pub struct On<'a, T, F> {
    scheme: &'a Scheme<T>,
    handler: F,
}

pub trait DispatchHandler {
    fn type_number(&self) -> u8;
    fn handle(&mut self, body: &[u8]) -> Result<(), UnpackError>;
}

impl<'a, T: Default + 'static, F: FnMut(T)> DispatchHandler for On<'a, T, F> {
    fn type_number(&self) -> u8 {
        self.scheme.type_number()
    }

    fn handle(&mut self, body: &[u8]) -> Result<(), UnpackError> {
        let row = unpack(self.scheme, body)?;
        (self.handler)(row);
        Ok(())
    }
}

pub fn pack<T>(scheme: &Scheme<T>, row: &T) -> Result<Vec<u8>, PackError> {
    let mut values = Values::new();
    for binder in &scheme.binders {
        values.insert(binder.name.clone(), Some((binder.get)(row)));
    }
    walk::pack(&scheme.layout, &values)
}

pub fn unpack<T: Default>(scheme: &Scheme<T>, bytes: &[u8]) -> Result<T, UnpackError> {
    let values = walk::unpack(&scheme.layout, bytes)?;
    let mut row = T::default();
    for binder in &scheme.binders {
        if let Some(Some(value)) = values.get(&binder.name) {
            (binder.set)(&mut row, value);
        }
    }
    Ok(row)
}

pub fn unpack_with(bytes: &[u8], handlers: &mut [&mut dyn DispatchHandler]) -> Result<(), UnpackError> {
    let mut seen = HashSet::new();
    for handler in handlers.iter() {
        let n = handler.type_number();
        if !seen.insert(n) {
            return Err(UnpackError::DuplicateType { type_number: n });
        }
    }
    if bytes.is_empty() {
        return Err(UnpackError::Short(ShortPacket {
            field: String::new(),
            needed: 1,
            left: 0,
        }));
    }
    let actual = bytes[0];
    for handler in handlers.iter_mut() {
        if handler.type_number() == actual {
            return handler.handle(bytes);
        }
    }
    Err(UnpackError::Type {
        expected: 0,
        actual,
    })
}
