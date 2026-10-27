mod bound;
mod bound_collections;
mod times;

pub use bound::BoundField;
use times::TimesItem;

use crate::ecc;
use crate::field::{
    check_order, field_name, flags as layout_flags, nested_element, rename_container, take_id,
    times as layout_times, when as layout_when, Eq, Field, MapScheme,
};
use crate::value::{Name, PackError, ShortPacket, UnpackError, Value, Values};
use crate::walk;
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
    Times(TimesItem<T>),
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
    /// it unpacks as `Some(true)` when set, `None` when clear. A `flags` nested in a `flags` is
    /// on when any value inside it is present.
    pub fn flags(anchor: u32, members: impl IntoIterator<Item = SchemeItem<T>>) -> Self {
        SchemeItem::Flags {
            anchor,
            members: members.into_iter().collect(),
        }
    }

    /// One round per element of a `Vec<E>`, as many as the integer field `count_id` says. `get`
    /// lends the elements and `set` takes the ones unpacked, one `E::default()` filled by
    /// `members` per round. `members` are items on `E`, numbered from `anchor` on like the
    /// items of a `when`; a reference among them names an id of the same element. Pack fails
    /// when the count differs from the number of elements.
    pub fn times<E: Default + 'static>(
        anchor: u32,
        count_id: u32,
        get: impl Fn(&T) -> &[E] + 'static,
        set: impl Fn(&mut T, Vec<E>) + 'static,
        members: impl IntoIterator<Item = SchemeItem<E>>,
    ) -> Self {
        SchemeItem::Times(TimesItem::new(
            anchor,
            count_id,
            get,
            set,
            members.into_iter().collect(),
        ))
    }
}

fn read_values<T>(binders: &[Binder<T>], row: &T) -> Values {
    let mut values = Values::new();
    for binder in binders {
        values.insert(binder.name.clone(), (binder.get)(row));
    }
    values
}

fn build_row<T: Default>(binders: &[Binder<T>], values: &Values) -> T {
    let mut row = T::default();
    for binder in binders {
        if let Some(Some(value)) = values.get(&binder.name) {
            (binder.set)(&mut row, value);
        }
    }
    row
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
            SchemeItem::Times(item) => {
                if item.anchor != *next_id {
                    panic!("field id {} is not the next order {next_id}", item.anchor);
                }
                let count_name: &str = item.count.as_ref();
                if let Ok(id) = count_name.parse::<u32>() {
                    if id >= *next_id {
                        panic!("field id {id} is not yet walked at order {next_id}");
                    }
                }
                let compiled = (item.compile)(name_seq);
                *next_id = compiled.end;
                fields.push(layout_times(item.anchor, count_name, compiled.fields));
                binders.push(compiled.binder);
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

    /// Returns the scheme with other round limits: the most rounds one `repeat` or `times`
    /// field may start, and the most slots all rounds of one call may create together (see
    /// [`MapScheme::with_limits`]). Panics when either is 0.
    pub fn with_limits(mut self, max_rounds: usize, max_slots: usize) -> Self {
        self.layout = self.layout.with_limits(max_rounds, max_slots);
        self
    }

    /// Returns the scheme with another output budget: the most bytes one `pack` call may write,
    /// type byte included (see [`MapScheme::with_max_bytes`]). Panics when it is 0.
    pub fn with_max_bytes(mut self, max_bytes: usize) -> Self {
        self.layout = self.layout.with_max_bytes(max_bytes);
        self
    }

    /// Returns the scheme with `n` parity bytes after every message (default 0; see
    /// [`MapScheme::with_parity`]). Panics, naming `n` and the limit 32, when `n` is above it.
    pub fn with_parity(mut self, n: usize) -> Self {
        self.layout = self.layout.with_parity(n);
        self
    }

    pub fn max_rounds(&self) -> usize {
        self.layout.max_rounds()
    }

    pub fn max_bytes(&self) -> usize {
        self.layout.max_bytes()
    }

    pub fn max_slots(&self) -> usize {
        self.layout.max_slots()
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

impl<T> Scheme<T> {
    /// The parity bytes after every message (0 unless `with_parity` set it).
    pub fn parity(&self) -> usize {
        self.layout.parity()
    }
}

pub struct On<'a, T, F> {
    scheme: &'a Scheme<T>,
    handler: F,
}

/// A handler of one scheme for [`BinaryPacker::unpack_with`].
///
/// ```
/// use packbin::{DispatchHandler, UnpackError};
/// struct Clear;
/// impl DispatchHandler for Clear {
///     fn type_number(&self) -> u8 { 1 }
///     fn parity(&self) -> usize { 0 }
///     fn handle(&mut self, _body: &[u8]) -> Result<(), UnpackError> { Ok(()) }
/// }
/// ```
///
/// `parity()` has no default, so a handler of a scheme with parity bytes cannot leave it out and
/// lose the repair:
///
/// ```compile_fail
/// use packbin::{DispatchHandler, UnpackError};
/// struct Clear;
/// impl DispatchHandler for Clear {
///     fn type_number(&self) -> u8 { 1 }
///     fn handle(&mut self, _body: &[u8]) -> Result<(), UnpackError> { Ok(()) }
/// }
/// ```
pub trait DispatchHandler {
    fn type_number(&self) -> u8;
    /// The parity bytes of the handler's scheme; a dispatch takes handlers of one count only.
    fn parity(&self) -> usize;
    fn handle(&mut self, body: &[u8]) -> Result<(), UnpackError>;
}

impl<'a, T: Default + 'static, F: FnMut(T)> DispatchHandler for On<'a, T, F> {
    fn type_number(&self) -> u8 {
        self.scheme.type_number()
    }

    fn parity(&self) -> usize {
        self.scheme.parity()
    }

    fn handle(&mut self, body: &[u8]) -> Result<(), UnpackError> {
        let row = BinaryPacker::unpack_clear(self.scheme, body)?;
        (self.handler)(row);
        Ok(())
    }
}

pub struct BinaryPacker;

impl BinaryPacker {
    pub fn pack<T>(scheme: &Scheme<T>, row: &T) -> Result<Vec<u8>, PackError> {
        walk::pack(&scheme.layout, &read_values(&scheme.binders, row))
    }

    /// Reads a message whose parity bytes were already checked and dropped.
    fn unpack_clear<T: Default>(scheme: &Scheme<T>, bytes: &[u8]) -> Result<T, UnpackError> {
        let values = walk::unpack_clear(&scheme.layout, bytes)?;
        Ok(build_row(&scheme.binders, &values))
    }

    /// Dispatches on the type byte; a message of schemes with parity bytes is checked, not
    /// repaired (limit 0, see [`BinaryPacker::unpack_with_repair`]).
    pub fn unpack_with(
        bytes: &[u8],
        handlers: &mut [&mut dyn DispatchHandler],
    ) -> Result<(), UnpackError> {
        Self::unpack_with_repair(bytes, handlers, 0).map(|_| ())
    }

    /// Repairs up to `limit` wrong bytes (0 to `n / 2`), then dispatches on the type byte, so a
    /// wrong type byte is repaired too. All handlers must declare the same parity count `n`, else
    /// [`UnpackError::MixedParity`] names two that differ. Returns the number of bytes repaired.
    pub fn unpack_with_repair(
        bytes: &[u8],
        handlers: &mut [&mut dyn DispatchHandler],
        limit: usize,
    ) -> Result<usize, UnpackError> {
        let n = checked_parity(handlers, limit)?;
        let (clear, repaired) = ecc::unprotect(bytes, n, limit)?;
        dispatch(&clear, handlers)?;
        Ok(repaired)
    }
}

/// The parity count of a usable handler list, checked in the order of every package: an empty
/// list, a duplicate type number, a mix of parity counts, then the limit. None reads a byte.
pub(crate) fn checked_parity(
    handlers: &[&mut dyn DispatchHandler],
    limit: usize,
) -> Result<usize, UnpackError> {
    if handlers.is_empty() {
        return Err(UnpackError::NoHandlers);
    }
    check_unique(handlers)?;
    let n = ecc::shared_parity(handlers.iter().map(|handler| handler.parity()))?;
    ecc::check_limit(n, limit)?;
    Ok(n)
}

fn check_unique(handlers: &[&mut dyn DispatchHandler]) -> Result<(), UnpackError> {
    let mut seen = [false; 256];
    for handler in handlers.iter() {
        let n = handler.type_number();
        if std::mem::replace(&mut seen[n as usize], true) {
            return Err(UnpackError::DuplicateType { type_number: n });
        }
    }
    Ok(())
}

/// Hands a clear message (parity bytes dropped) to the handler of its type byte.
pub(crate) fn dispatch(
    bytes: &[u8],
    handlers: &mut [&mut dyn DispatchHandler],
) -> Result<(), UnpackError> {
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
