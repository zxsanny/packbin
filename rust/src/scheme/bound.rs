use crate::field::{
    bits as field_bits, bytes as field_bytes, f32 as field_f32, f64 as field_f64, group,
    i16 as field_i16, i32 as field_i32, i64 as field_i64, i8 as field_i8, id_name,
    list as field_list, sized as field_sized, u16 as field_u16, u32 as field_u32, u64 as field_u64,
    u8 as field_u8, utf8 as field_utf8, Field,
};
use crate::value::Value;

pub struct BoundField<T> {
    pub(super) id: Option<u32>,
    pub(super) field: Field,
    pub(super) get: Box<dyn Fn(&T) -> Option<Value>>,
    pub(super) set: Box<dyn Fn(&mut T, &Value)>,
    pub(super) element_ids: Option<(u32, u32)>,
}

fn required<T: 'static, V: 'static>(
    id: u32,
    field: Field,
    get: impl Fn(&T) -> V + 'static,
    set: impl Fn(&mut T, V) + 'static,
    to_val: impl Fn(V) -> Value + 'static,
    from_val: impl Fn(&Value) -> Option<V> + 'static,
) -> BoundField<T> {
    BoundField {
        id: Some(id),
        field,
        get: Box::new(move |row| Some(to_val(get(row)))),
        set: Box::new(move |row, value| {
            if let Some(v) = from_val(value) {
                set(row, v);
            }
        }),
        element_ids: None,
    }
}

fn optional<T: 'static, V: 'static>(
    id: u32,
    field: Field,
    get: impl Fn(&T) -> Option<V> + 'static,
    set: impl Fn(&mut T, Option<V>) + 'static,
    to_val: impl Fn(V) -> Value + 'static,
    from_val: impl Fn(&Value) -> Option<V> + 'static,
) -> BoundField<T> {
    BoundField {
        id: Some(id),
        field,
        get: Box::new(move |row| get(row).map(&to_val)),
        set: Box::new(move |row, value| set(row, from_val(value))),
        element_ids: None,
    }
}

impl<T: 'static> BoundField<T> {
    pub fn u8(
        id: u32,
        get: impl Fn(&T) -> u8 + 'static,
        set: impl Fn(&mut T, u8) + 'static,
    ) -> Self {
        required(id, field_u8(id_name(id)), get, set, Value::U8, |v| {
            if let Value::U8(x) = v {
                Some(*x)
            } else {
                None
            }
        })
    }

    pub fn opt_u8(
        id: u32,
        get: impl Fn(&T) -> Option<u8> + 'static,
        set: impl Fn(&mut T, Option<u8>) + 'static,
    ) -> Self {
        optional(id, field_u8(id_name(id)), get, set, Value::U8, |v| {
            if let Value::U8(x) = v {
                Some(*x)
            } else {
                None
            }
        })
    }

    pub fn u16(
        id: u32,
        get: impl Fn(&T) -> u16 + 'static,
        set: impl Fn(&mut T, u16) + 'static,
    ) -> Self {
        required(id, field_u16(id_name(id)), get, set, Value::U16, |v| {
            if let Value::U16(x) = v {
                Some(*x)
            } else {
                None
            }
        })
    }

    pub fn opt_u16(
        id: u32,
        get: impl Fn(&T) -> Option<u16> + 'static,
        set: impl Fn(&mut T, Option<u16>) + 'static,
    ) -> Self {
        optional(id, field_u16(id_name(id)), get, set, Value::U16, |v| {
            if let Value::U16(x) = v {
                Some(*x)
            } else {
                None
            }
        })
    }

    pub fn u32(
        id: u32,
        get: impl Fn(&T) -> u32 + 'static,
        set: impl Fn(&mut T, u32) + 'static,
    ) -> Self {
        required(id, field_u32(id_name(id)), get, set, Value::U32, |v| {
            if let Value::U32(x) = v {
                Some(*x)
            } else {
                None
            }
        })
    }

    pub fn u64(
        id: u32,
        get: impl Fn(&T) -> u64 + 'static,
        set: impl Fn(&mut T, u64) + 'static,
    ) -> Self {
        required(id, field_u64(id_name(id)), get, set, Value::U64, |v| {
            if let Value::U64(x) = v {
                Some(*x)
            } else {
                None
            }
        })
    }

    pub fn i8(
        id: u32,
        get: impl Fn(&T) -> i8 + 'static,
        set: impl Fn(&mut T, i8) + 'static,
    ) -> Self {
        required(id, field_i8(id_name(id)), get, set, Value::I8, |v| {
            if let Value::I8(x) = v {
                Some(*x)
            } else {
                None
            }
        })
    }

    pub fn i16(
        id: u32,
        get: impl Fn(&T) -> i16 + 'static,
        set: impl Fn(&mut T, i16) + 'static,
    ) -> Self {
        required(id, field_i16(id_name(id)), get, set, Value::I16, |v| {
            if let Value::I16(x) = v {
                Some(*x)
            } else {
                None
            }
        })
    }

    pub fn i32(
        id: u32,
        get: impl Fn(&T) -> i32 + 'static,
        set: impl Fn(&mut T, i32) + 'static,
    ) -> Self {
        required(id, field_i32(id_name(id)), get, set, Value::I32, |v| {
            if let Value::I32(x) = v {
                Some(*x)
            } else {
                None
            }
        })
    }

    pub fn i64(
        id: u32,
        get: impl Fn(&T) -> i64 + 'static,
        set: impl Fn(&mut T, i64) + 'static,
    ) -> Self {
        required(id, field_i64(id_name(id)), get, set, Value::I64, |v| {
            if let Value::I64(x) = v {
                Some(*x)
            } else {
                None
            }
        })
    }

    pub fn f32(
        id: u32,
        get: impl Fn(&T) -> f32 + 'static,
        set: impl Fn(&mut T, f32) + 'static,
    ) -> Self {
        required(id, field_f32(id_name(id)), get, set, Value::F32, |v| {
            if let Value::F32(x) = v {
                Some(*x)
            } else {
                None
            }
        })
    }

    pub fn f64(
        id: u32,
        get: impl Fn(&T) -> f64 + 'static,
        set: impl Fn(&mut T, f64) + 'static,
    ) -> Self {
        required(id, field_f64(id_name(id)), get, set, Value::F64, |v| {
            if let Value::F64(x) = v {
                Some(*x)
            } else {
                None
            }
        })
    }

    pub fn bytes(
        id: u32,
        len: usize,
        get: impl Fn(&T) -> Vec<u8> + 'static,
        set: impl Fn(&mut T, Vec<u8>) + 'static,
    ) -> Self {
        required(
            id,
            field_bytes(id_name(id), len),
            get,
            set,
            Value::Bytes,
            |v| {
                if let Value::Bytes(x) = v {
                    Some(x.clone())
                } else {
                    None
                }
            },
        )
    }

    pub fn utf8(
        id: u32,
        get: impl Fn(&T) -> String + 'static,
        set: impl Fn(&mut T, String) + 'static,
    ) -> Self {
        required(id, field_utf8(id_name(id)), get, set, Value::Str, |v| {
            if let Value::Str(x) = v {
                Some(x.clone())
            } else {
                None
            }
        })
    }

    pub fn sized(
        id: u32,
        count_id: u32,
        get: impl Fn(&T) -> Vec<u8> + 'static,
        set: impl Fn(&mut T, Vec<u8>) + 'static,
    ) -> Self {
        required(
            id,
            field_sized(id, count_id),
            get,
            set,
            Value::Bytes,
            |v| {
                if let Value::Bytes(x) = v {
                    Some(x.clone())
                } else {
                    None
                }
            },
        )
    }

    pub fn bits(
        id: u32,
        count_id: u32,
        get: impl Fn(&T) -> Vec<u8> + 'static,
        set: impl Fn(&mut T, Vec<u8>) + 'static,
    ) -> Self {
        required(
            id,
            field_bits(id, count_id),
            get,
            set,
            |v| Value::List(v.into_iter().map(Value::U8).collect()),
            |v| {
                if let Value::List(items) = v {
                    let mut out = Vec::with_capacity(items.len());
                    for item in items {
                        if let Value::U8(b) = item {
                            out.push(*b);
                        } else {
                            return None;
                        }
                    }
                    Some(out)
                } else {
                    None
                }
            },
        )
    }

    pub fn bool_flag(
        id: u32,
        get: impl Fn(&T) -> Option<bool> + 'static,
        set: impl Fn(&mut T, Option<bool>) + 'static,
    ) -> Self {
        let name = id_name(id);
        BoundField {
            id: Some(id),
            field: group(name, vec![]),
            get: Box::new(move |row| {
                if get(row) == Some(true) {
                    Some(Value::U8(1))
                } else {
                    None
                }
            }),
            set: Box::new(move |row, _value| set(row, Some(true))),
            element_ids: None,
        }
    }

    pub fn list_u16(
        get: impl Fn(&T) -> Vec<u16> + 'static,
        set: impl Fn(&mut T, Vec<u16>) + 'static,
        element_id: u32,
    ) -> Self {
        let elem_name = id_name(element_id);
        let list_name = format!("__list_{element_id}");
        BoundField {
            id: None,
            field: field_list(list_name.as_str(), field_u16(elem_name)),
            get: Box::new(move |row| {
                Some(Value::List(
                    get(row).into_iter().map(Value::U16).collect(),
                ))
            }),
            set: Box::new(move |row, value| {
                if let Value::List(items) = value {
                    let mut out = Vec::with_capacity(items.len());
                    for item in items {
                        if let Value::U16(n) = item {
                            out.push(*n);
                        }
                    }
                    set(row, out);
                }
            }),
            element_ids: Some((element_id, element_id.saturating_add(1))),
        }
    }
}
