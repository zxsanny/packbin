# Acceptance criteria — scheme field order

Inherited: project acceptance criteria stay in force. This feature exercises the rule that the six languages pack the same bytes. It does not change those bytes.

## Criteria

**AC-1: Value fields are numbered in list order.**
Given a scheme whose value fields are numbered 0 then 1.
When the scheme is built.
Then construction succeeds.
Given a second value field numbered 2, or a repeated 0.
When the scheme is built.
Then construction fails. Schemes built: 0. Bytes written: 0.

**AC-2: A continuing group shows the next value id.**
Given `repeat`, `when`, `times`, `flags`, or a group whose children continue the parent numbers, and an anchor equal to the next value-field id, and a first child with that same id.
When the scheme is built.
Then construction succeeds. The anchor does not insert a number: the child after that first child is the following integer.
Given an anchor that is not that next id.
When the scheme is built.
Then construction fails. Schemes built: 0.

**AC-3: A nested list starts at 0.**
Given a `list`, a `dict`, or a nested group.
When the scheme is built.
Then its element numbers start at 0. A value field after the list uses the next parent number. The list does not consume a parent number.

**AC-4: Every Rust scheme build runs the check.**
Given a Rust scheme built by any public constructor, including a raw field list, with a gap in the numbers.
When it is built.
Then construction fails. Schemes built: 0.
Given a `when` or a borrowed count that names an id not yet walked.
When it is built.
Then construction fails. Schemes built: 0.

**AC-5: The failure rule is written next to the order sentence.**
Given the order sentence that says field order is wire order.
When a reader looks at the next sentence.
Then it states that a gap, a repeated id, or an anchor that is not the next value id fails construction, and that the anchor is not written.

**AC-6: Existing packets keep their bytes.**
Given a scheme that already packed a known hex, updated only so each continuing group passes its anchor.
When it is packed in all six languages.
Then the hex is unchanged. Mismatched bytes: 0.

## Out of scope

- A parent number on `list` or `dict`.
- A count byte in front of `repeat`.
- A second order argument on a value field that already has its id.
