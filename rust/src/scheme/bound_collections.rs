use super::BoundField;
use crate::field::{
    dict as field_dict, id_name, list as field_list, u16 as field_u16, utf8 as field_utf8,
};
use crate::value::Value;
use std::collections::BTreeMap;

impl<T: 'static> BoundField<T> {
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
                Some(Value::List(get(row).into_iter().map(Value::U16).collect()))
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

    pub fn list_utf8(
        get: impl Fn(&T) -> Vec<String> + 'static,
        set: impl Fn(&mut T, Vec<String>) + 'static,
    ) -> Self {
        BoundField {
            id: None,
            field: field_list("__list", field_utf8(id_name(0))),
            get: Box::new(move |row| {
                Some(Value::List(get(row).into_iter().map(Value::Str).collect()))
            }),
            set: Box::new(move |row, value| {
                if let Value::List(items) = value {
                    let mut out = Vec::with_capacity(items.len());
                    for item in items {
                        if let Value::Str(text) = item {
                            out.push(text.clone());
                        }
                    }
                    set(row, out);
                }
            }),
            element_ids: Some((0, 1)),
        }
    }

    pub fn dict_list_utf8(
        get: impl Fn(&T) -> BTreeMap<String, Vec<String>> + 'static,
        set: impl Fn(&mut T, BTreeMap<String, Vec<String>>) + 'static,
    ) -> Self {
        BoundField {
            id: None,
            field: field_dict("__dict", field_list("__list", field_utf8(id_name(0)))),
            get: Box::new(move |row| {
                Some(Value::Map(
                    get(row)
                        .into_iter()
                        .map(|(key, items)| {
                            (
                                key,
                                Value::List(items.into_iter().map(Value::Str).collect()),
                            )
                        })
                        .collect(),
                ))
            }),
            set: Box::new(move |row, value| {
                if let Value::Map(map) = value {
                    let mut out = BTreeMap::new();
                    for (key, item) in map {
                        if let Value::List(items) = item {
                            let texts = items
                                .iter()
                                .filter_map(|v| match v {
                                    Value::Str(text) => Some(text.clone()),
                                    _ => None,
                                })
                                .collect();
                            out.insert(key.clone(), texts);
                        }
                    }
                    set(row, out);
                }
            }),
            element_ids: None,
        }
    }

    pub fn dict_list_dict_utf8(
        get: impl Fn(&T) -> BTreeMap<String, Vec<BTreeMap<String, String>>> + 'static,
        set: impl Fn(&mut T, BTreeMap<String, Vec<BTreeMap<String, String>>>) + 'static,
    ) -> Self {
        BoundField {
            id: None,
            field: field_dict(
                "__dict",
                field_list("__list", field_dict("__row", field_utf8(id_name(0)))),
            ),
            get: Box::new(move |row| {
                Some(Value::Map(
                    get(row)
                        .into_iter()
                        .map(|(key, rows)| {
                            (
                                key,
                                Value::List(
                                    rows.into_iter()
                                        .map(|fields| {
                                            Value::Map(
                                                fields
                                                    .into_iter()
                                                    .map(|(name, text)| (name, Value::Str(text)))
                                                    .collect(),
                                            )
                                        })
                                        .collect(),
                                ),
                            )
                        })
                        .collect(),
                ))
            }),
            set: Box::new(move |row, value| {
                if let Value::Map(map) = value {
                    let mut out = BTreeMap::new();
                    for (key, item) in map {
                        if let Value::List(rows) = item {
                            let mut decoded = Vec::with_capacity(rows.len());
                            for row_value in rows {
                                if let Value::Map(fields) = row_value {
                                    let mut one = BTreeMap::new();
                                    for (name, text) in fields {
                                        if let Value::Str(s) = text {
                                            one.insert(name.clone(), s.clone());
                                        }
                                    }
                                    decoded.push(one);
                                }
                            }
                            out.insert(key.clone(), decoded);
                        }
                    }
                    set(row, out);
                }
            }),
            element_ids: None,
        }
    }
}
