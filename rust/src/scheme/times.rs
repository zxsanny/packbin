use super::{build_row, compile_items, read_values, Binder, SchemeItem};
use crate::field::{id_name, times_name, Field};
use crate::value::{Name, Value};
use std::rc::Rc;

type Compile<T> = Box<dyn FnOnce(&mut u32) -> Compiled<T>>;

/// A typed `times`, held as built until the scheme compiles it with its own name counter.
pub struct TimesItem<T> {
    pub(super) anchor: u32,
    pub(super) count: Name,
    /// Compiles the element items with the scheme's counter of generated names, so no element
    /// reuses a name of the row or of another element.
    pub(super) compile: Compile<T>,
}

pub(super) struct Compiled<T> {
    pub(super) fields: Vec<Field>,
    /// The id after the last element item.
    pub(super) end: u32,
    /// Carries the rounds as `Value::Groups`, one `Values` per element.
    pub(super) binder: Binder<T>,
}

impl<T: 'static> TimesItem<T> {
    pub(super) fn new<E: Default + 'static>(
        anchor: u32,
        count_id: u32,
        get: impl Fn(&T) -> &[E] + 'static,
        set: impl Fn(&mut T, Vec<E>) + 'static,
        members: Vec<SchemeItem<E>>,
    ) -> Self {
        TimesItem {
            anchor,
            count: id_name(count_id),
            compile: Box::new(move |name_seq| {
                let mut end = anchor;
                let (fields, element_binders) = compile_items(members, &mut end, name_seq);
                let element_binders = Rc::new(element_binders);
                let unpack_binders = Rc::clone(&element_binders);
                let binder = Binder {
                    name: times_name(anchor),
                    get: Box::new(move |row| {
                        let rounds = get(row)
                            .iter()
                            .map(|element| read_values(&element_binders, element))
                            .collect();
                        Some(Value::Groups(rounds))
                    }),
                    set: Box::new(move |row, value| {
                        if let Value::Groups(rounds) = value {
                            set(
                                row,
                                rounds
                                    .iter()
                                    .map(|round| build_row(&unpack_binders, round))
                                    .collect(),
                            );
                        }
                    }),
                };
                Compiled {
                    fields,
                    end,
                    binder,
                }
            }),
        }
    }
}
