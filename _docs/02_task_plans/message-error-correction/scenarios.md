# Scenarios — message-error-correction

Source of rows: `intake` (new-task Step 4.7, loop 38). Status: confirmed / out-of-scope / deferred. 12-row cap (13 points).

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | A caller keeps a scheme with 0 parity bytes | confirmed | bytes and errors exactly as before | EC-1 | intake |
| S2 | The same row is packed twice under a protected scheme | confirmed | the same bytes both times (parity is a function of the message) | EC-2 | intake |
| S3 | A receiver reads a message with 1 to `t` wrong bytes, including the type byte or a parity byte | confirmed | the row is returned and the repaired count is reported | EC-5 | intake |
| S4 | A receiver reads a message with more wrong bytes than it may repair but up to `n - t` | confirmed | an error naming the kind, 0 values | EC-6 | intake |
| S5 | A receiver reads random garbage | confirmed | refused except for the stated chance; the contract lists that chance for each `n` and `t` | EC-7, EC-15 | intake |
| S6 | The tail of the message is lost, or bytes are added | confirmed | an error, 0 values (with `t` = 0) | EC-14 | intake |
| S7 | The scheme starts to declare parity after bytes were sent without it, or the reverse | confirmed | a protected scheme refuses unprotected bytes (error, 0 values); an unprotected scheme given protected bytes returns the trailing-bytes error | EC-14, AC-9 | intake |
| S8 | Parity count 0, 1, 32, 33 | confirmed | 0 unchanged; 1 and 32 pack; 33 refused when the scheme is built | EC-2, EC-3 | intake |
| S9 | A clear message of 254 − `n` bytes and one byte more | confirmed | the first packs, the second is refused with a typed error, 0 bytes written | EC-4 | intake |
| S10 | Several schemes dispatched by the type byte, the type byte is among the wrong ones | confirmed | all handlers of one dispatch declare the same parity count; the message is repaired, then dispatched; a mix is refused when the dispatch is built (card 1) | EC-16 | intake |
| S11 | A session carries a protected message; a payload is lost or arrives with wrong bytes | confirmed | up to `t` wrong bytes are repaired before the pad is removed; beyond that an error, and the next payload from the same sender is still read | EC-10 | intake |
| S12 | A compact-text field in a protected message has wrong bytes | confirmed | the original string or an error, never a different string at or below the correction limit | EC-11 | intake |

## Owning tasks

| scenario | task(s) |
|----------|---------|
| S1, S2, S3, S4, S5, S6, S7, S8, S9 | AZ-2678 (rules), AZ-2679 (reference and vectors), AZ-2680 to AZ-2688 (each package) |
| S10 | AZ-2678 (rule), each package task and AZ-2688 (EC-16) |
| S11 | AZ-2678, each package task, AZ-2688 (EC-10) |
| S12 | each package task, AZ-2688 (EC-11) |
| all | AZ-2689 (ring, EC-9) |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | scheme chosen by the type byte, which may be among the wrong bytes | A — one shared parity count per dispatch | yes (EC-16) |
| 2 | C++ receive buffer is read-only today | A — repair in place, a writable buffer for protected schemes only | yes (EC-17) |
| 3 | "the bytes are only the fields" (architecture principle, ADR 001) | opt-in per scheme, off by default; a new ADR 007 records the exception | yes (EC-1, ADR deliverable) |
| 4 | session payload is "the same length as clear pack" | protected schemes only: clear length + `n` | yes (EC-10) |
| 5 | Cortex-M4F flash margin is 60 B | feature behind flags, M4F measured unchanged with it off | yes (EC-12) |

## Not walked

- Erasures (known bad positions, such as a lost byte at a known place).
- A message longer than 254 bytes split into blocks.
- Two protected messages sharing one parity.
