# Feature assessment — loop 8

loop: 8
feature: scheme-field-order
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-09-29
**Implement pass**: batch 01, `_docs/03_implementation/batch_01_loop8_report.md`, `_docs/03_implementation/implementation_completeness_loop8_report.md`
**Verdict**: COMPLETE — 8 covered / 3 out-of-scope / 0 gap-clear / 0 gap-unclear

`scenarios.md` absent (no file under `_docs/02_task_plans/scheme-field-order/`). Intent is `problem.md` and `acceptance_criteria.md`. Discoveries on the batch report are both `clear` and match the built check.

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | Value fields numbered 0, 1, 2; a gap or a repeated id fails construction and writes nothing | covered | Feature AC-1; `FieldIdBindingTests.Ac5_OrderMustMatchTheNumber`, `test_ac5_order_must_match_the_number`, binding test "AC-5 order must match the number", `field_id_ac5_order_must_match`, `FieldIdBindingTest.ac5OrderMustMatchTheNumber`, cpp `field_id_binding_tests` "AC-5 order fails"; `SchemeOrder.Validate` / `check_order` / `validateFieldIds` | spec |
| S2 | `repeat`, `when`, `times`, `flags`, or a continuing group takes an anchor equal to the next value id and does not insert a slot; a bad anchor fails | covered | Feature AC-2; `LayoutTests.Repeat_WrongAnchor_FailsConstruction`, `test_bad_anchor_raises_and_matching_packs`, "bad container anchor throws before any byte is written", `repeat_anchor_order`, `repeatAnchorMustMatchNextId`; `RequireAnchor` / `check_anchor` / `fields.ts` anchor compare | spec |
| S3 | A list, a dict, or a nested group numbers from 0, and the next parent field keeps the next parent id | covered | Feature AC-3; `test_ac4_nested_row_type_has_own_ids`, "AC-4 nested row type has its own ids", `FieldIdBindingTest.ac4NestedRowTypeHasOwnIds`; list/dict branch in `order.rs` and `validateFieldIds` restarts at 0 and does not advance the parent counter | spec |
| S4 | Every public Rust constructor, including a raw field list, rejects a gap, and a `when` or borrowed count that names an id not yet walked | covered | Feature AC-4; `raw_field_list_gap_fails_closed`, `field_id_ac5_order_must_match`, `when_unknown_id_fails_at_build`, `packed_unknown_count_fails_at_build`; `Scheme::new` compiles into `MapScheme::new`, which calls `check_order`; `require_walked` | spec |
| S5 | The sentence after "Field order is wire order" names the gap, the repeated id, and the bad anchor, and says the anchor is not written | covered | Feature AC-5; sentence in `_docs/01_solution/schema.md` and `README.md` "Field numbers are the order in the scheme"; completeness report row AZ-2016 PASS | spec |
| S6 | A known packet, with continuing groups given only their anchor, keeps the same hex in each language | covered | Feature AC-6; `Repeat_MatchingAnchor_SameBytes` (`010102`), `repeat_anchor_keeps_prior_hex`, `repeatAnchorMustMatchNextId`, `repeat_anchor_order`, `test_bad_anchor_raises_and_matching_packs`; pack walks the same list the constructor checked | spec |
| D1 | A nested group restarts at 0 and takes no parent anchor; a group whose children continue the parent counter takes the anchor | covered | `problem.md` "list, dict, and a nested group keep a separate numbering"; batch discovery 1 `clear`; `Field.Group` overloads (nested throws "does not take an anchor", continuing requires one); TypeScript `group` overload; Python/C++/Rust `group(anchor, …)` | batch_01 discoveries |
| D2 | An empty Rust group is the flag bool, so the anchor equals that slot and the slot is consumed once | covered | Feature AC-2 plus the existing flag-bool group; `empty_group_flag` packs `0101` / `0100`; `order.rs` empty `Group` calls `take_value_slot` after `check_anchor` | batch_01 discoveries |
| S7 | A parent number on `list` or `dict` | out-of-scope | acceptance criteria `## Out of scope`: "A parent number on `list` or `dict`." | spec |
| S8 | A count byte in front of `repeat` | out-of-scope | acceptance criteria `## Out of scope`: "A count byte in front of `repeat`." | spec |
| S9 | A second order argument on a value field that already has its id | out-of-scope | acceptance criteria `## Out of scope`: "A second order argument on a value field that already has its id." | spec |

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

None.

### Not walked

Concurrent callers, permission, and undo have no plausible row: construction is a pure function of the field list.

### Harness gaps

None.
