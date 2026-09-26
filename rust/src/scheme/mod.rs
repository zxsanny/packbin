mod bound;

pub use bound::BoundField;

use crate::field::{
    field_name, flags as layout_flags, id_name, times as layout_times, when as layout_when, Eq,
    Field, MapScheme,
};
use crate::value::{Name, PackError, ShortPacket, UnpackError, Value, Values};
use crate::walk;
use std::collections::HashSet;
use std::marker::PhantomData;

struct Binder<T> {
    name: Name,
    get: Box<dyn Fn(&T) -> Option<Value>>,
    set: Box<dyn Fn(&mut T, &Value)>,
}

pub struct Scheme<T> {
    layout: MapScheme,
    binders: Vec<Binder<T>>,
    _marker: PhantomData<T>,
}

pub enum SchemeItem<T> {
    Bound(BoundField<T>),
    When {
        cond: Eq,
        members: Vec<SchemeItem<T>>,
    },
    Flags {
        members: Vec<SchemeItem<T>>,
    },
    Times {
        count: crate::value::Name,
        members: Vec<SchemeItem<T>>,
    },
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

impl<T: 'static> SchemeItem<T> {
    pub fn when(cond: Eq, members: impl IntoIterator<Item = SchemeItem<T>>) -> Self {
        SchemeItem::When {
            cond,
            members: members.into_iter().collect(),
        }
    }

    pub fn flags(members: impl IntoIterator<Item = SchemeItem<T>>) -> Self {
        SchemeItem::Flags {
            members: members.into_iter().collect(),
        }
    }

    pub fn times(count_id: u32, members: impl IntoIterator<Item = SchemeItem<T>>) -> Self {
        SchemeItem::Times {
            count: id_name(count_id),
            members: members.into_iter().collect(),
        }
    }
}

fn take_id(next: &mut u32, id: u32) {
    if id != *next {
        panic!("field id {id} is not the next order {next}");
    }
    *next = next.saturating_add(1);
}

fn compile_items<T: 'static>(
    items: Vec<SchemeItem<T>>,
    next_id: &mut u32,
    flag_seq: &mut u32,
) -> (Vec<Field>, Vec<Binder<T>>) {
    let mut fields = Vec::new();
    let mut binders = Vec::new();
    for item in items {
        match item {
            SchemeItem::Bound(bound) => {
                if let Some(id) = bound.id {
                    take_id(next_id, id);
                } else if let Some((elem_start, elem_end)) = bound.element_ids {
                    if elem_start != 0 {
                        panic!("list element id {elem_start} is not the next order 0");
                    }
                    let _ = elem_end;
                }
                let name = field_name(&bound.field)
                    .map(|s| crate::value::name_of(s))
                    .expect("bound field needs a name");
                fields.push(bound.field);
                binders.push(Binder {
                    name,
                    get: bound.get,
                    set: bound.set,
                });
            }
            SchemeItem::When { cond, members } => {
                let (child_fields, child_binders) = compile_items(members, next_id, flag_seq);
                fields.push(layout_when(cond, child_fields));
                binders.extend(child_binders);
            }
            SchemeItem::Flags { members } => {
                let name = format!("__flags_{}", *flag_seq);
                *flag_seq = flag_seq.saturating_add(1);
                let (child_fields, child_binders) = compile_items(members, next_id, flag_seq);
                fields.push(layout_flags(name.as_str(), child_fields));
                binders.extend(child_binders);
            }
            SchemeItem::Times { count, members } => {
                let (child_fields, child_binders) = compile_items(members, next_id, flag_seq);
                fields.push(layout_times(count.as_ref(), child_fields));
                binders.extend(child_binders);
            }
            SchemeItem::Field(field) => fields.push(field),
        }
    }
    (fields, binders)
}

impl<T: 'static> Scheme<T> {
    pub fn new(type_number: i32, fields: impl IntoIterator<Item = SchemeItem<T>>) -> Self {
        let mut next_id = 0u32;
        let mut flag_seq = 0u32;
        let (layout_fields, binders) =
            compile_items(fields.into_iter().collect(), &mut next_id, &mut flag_seq);
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
        let row = BinaryPacker::unpack(self.scheme, body)?;
        (self.handler)(row);
        Ok(())
    }
}

pub struct BinaryPacker;

impl BinaryPacker {
    pub fn pack<T>(scheme: &Scheme<T>, row: &T) -> Result<Vec<u8>, PackError> {
        let mut values = Values::new();
        for binder in &scheme.binders {
            values.insert(binder.name.clone(), (binder.get)(row));
        }
        walk::pack(&scheme.layout, &values)
    }

    fn unpack<T: Default>(scheme: &Scheme<T>, bytes: &[u8]) -> Result<T, UnpackError> {
        let values = walk::unpack(&scheme.layout, bytes)?;
        let mut row = T::default();
        for binder in &scheme.binders {
            if let Some(Some(value)) = values.get(&binder.name) {
                (binder.set)(&mut row, value);
            }
        }
        Ok(row)
    }

    pub fn unpack_with(
        bytes: &[u8],
        handlers: &mut [&mut dyn DispatchHandler],
    ) -> Result<(), UnpackError> {
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
}
