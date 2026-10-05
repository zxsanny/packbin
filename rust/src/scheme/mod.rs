mod bound;

pub use bound::BoundField;

use crate::field::{
    check_order, field_name, flags as layout_flags, id_name, nested_element, rename_container,
    take_id, times as layout_times, when as layout_when, Eq, Field, MapScheme,
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
        anchor: u32,
        cond: Eq,
        members: Vec<SchemeItem<T>>,
    },
    Flags {
        anchor: u32,
        members: Vec<SchemeItem<T>>,
    },
    Times {
        anchor: u32,
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
    pub fn when(anchor: u32, cond: Eq, members: impl IntoIterator<Item = SchemeItem<T>>) -> Self {
        SchemeItem::When {
            anchor,
            cond,
            members: members.into_iter().collect(),
        }
    }

    /// One byte with a bit per member (at most 8), then each member whose bit is set. This is
    /// the only place for a `BoundField::bool_flag`: its bit is set only for `Some(true)`, and
    /// it unpacks as `Some(true)` when set, `None` when clear.
    pub fn flags(anchor: u32, members: impl IntoIterator<Item = SchemeItem<T>>) -> Self {
        SchemeItem::Flags {
            anchor,
            members: members.into_iter().collect(),
        }
    }

    pub fn times(
        anchor: u32,
        count_id: u32,
        members: impl IntoIterator<Item = SchemeItem<T>>,
    ) -> Self {
        SchemeItem::Times {
            anchor,
            count: id_name(count_id),
            members: members.into_iter().collect(),
        }
    }
}

fn compile_items<T: 'static>(
    items: Vec<SchemeItem<T>>,
    next_id: &mut u32,
    name_seq: &mut u32,
) -> (Vec<Field>, Vec<Binder<T>>) {
    let mut fields = Vec::new();
    let mut binders = Vec::new();
    for item in items {
        match item {
            SchemeItem::Bound(mut bound) => {
                match bound.id {
                    Some(id) => take_id(next_id, id),
                    None => {
                        rename_container(&mut bound.field, &format!("__bound_{}", *name_seq));
                        *name_seq = name_seq.saturating_add(1);
                    }
                }
                if let Some(element) = nested_element(&bound.field) {
                    let end = check_order(std::slice::from_ref(element), 0, 0);
                    if let Some((elem_start, elem_end)) = bound.element_ids {
                        if elem_start != 0 {
                            panic!("list element id {elem_start} is not the next order 0");
                        }
                        if end != elem_end {
                            panic!("field id {end} is not the next order {elem_end}");
                        }
                    }
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
            SchemeItem::When {
                anchor,
                cond,
                members,
            } => {
                if anchor != *next_id {
                    panic!("field id {anchor} is not the next order {next_id}");
                }
                let cond_name: &str = cond.field.as_ref();
                if let Ok(id) = cond_name.parse::<u32>() {
                    if id >= *next_id {
                        panic!("field id {id} is not yet walked at order {next_id}");
                    }
                }
                let (child_fields, child_binders) = compile_items(members, next_id, name_seq);
                fields.push(layout_when(anchor, cond, child_fields));
                binders.extend(child_binders);
            }
            SchemeItem::Flags { anchor, members } => {
                if anchor != *next_id {
                    panic!("field id {anchor} is not the next order {next_id}");
                }
                let name = format!("__flags_{}", *name_seq);
                *name_seq = name_seq.saturating_add(1);
                let (child_fields, child_binders) = compile_items(members, next_id, name_seq);
                fields.push(layout_flags(anchor, name.as_str(), child_fields));
                binders.extend(child_binders);
            }
            SchemeItem::Times {
                anchor,
                count,
                members,
            } => {
                if anchor != *next_id {
                    panic!("field id {anchor} is not the next order {next_id}");
                }
                let count_name: &str = count.as_ref();
                if let Ok(id) = count_name.parse::<u32>() {
                    if id >= *next_id {
                        panic!("field id {id} is not yet walked at order {next_id}");
                    }
                }
                let (child_fields, child_binders) = compile_items(members, next_id, name_seq);
                fields.push(layout_times(anchor, count.as_ref(), child_fields));
                binders.extend(child_binders);
            }
            SchemeItem::Field(field) => {
                *next_id = check_order(std::slice::from_ref(&field), *next_id, 0);
                fields.push(field);
            }
        }
    }
    (fields, binders)
}

impl<T: 'static> Scheme<T> {
    pub fn new(type_number: i32, fields: impl IntoIterator<Item = SchemeItem<T>>) -> Self {
        let mut next_id = 0u32;
        let mut name_seq = 0u32;
        let (layout_fields, binders) =
            compile_items(fields.into_iter().collect(), &mut next_id, &mut name_seq);
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
