# Acceptance criteria — loop 55 (when-chain-and-speed-headroom)

Project ACs inherited: AC-W1 to AC-W9 of loop 54 (`when` of a skipped source), AZ-2737 AC-1 (1 s nominal). New ones:

## A: `when` chain stack (AC-A)

**AC-A1: Measured**
Given a Cortex-M4F image that packs and unpacks a row whose consuming `when` has its source 3 `when`s deep (each source inside the previous `when`)
When the arm embedded stage measures the deepest pack and unpack stack
Then the figure is recorded in `_docs/AGENT_GOTCHAS.md` and is at most 512 B.

**AC-A2: Guarded**
Given the all-kinds image of the embedded stage
When it is built after this loop
Then it contains the 3-deep chain, so any later edit that pushes the stack above 512 B fails the stage (flash stays at most 8,192 B).

**AC-A3: Chain of 3 equals the reference**
Given the chain scheme and the rows (all `when`s true, only the outermost true, an inner one false)
When it is packed and unpacked in C++ and in Python
Then packets are byte-equal and unpacked rows are equal; 0 differences.

**AC-A4: Over budget**
Given the measured stack is above 512 B
When the loop closes
Then the check is changed so the stack is at most 512 B with packets unchanged, or the owner has decided a depth limit; the loop does not close with the stage red or the image without the chain.

## B: bool and group-presence source behind a clear `when` (AC-B)

**AC-B1: Source skipped, bool true in the row**
Given `u8 mode; when(mode==1){ flags{ bool on }; u8 a }; when(on==true){ u8 b }` and the row mode 0, on true, a 7, b 5
When it is packed and unpacked
Then pack writes the mode byte only and unpack returns mode 0 with no error.

**AC-B2: Source held**
Given the same scheme and mode 1, on true, a 7, b 5 / mode 1, on false, a 7, b 5
When they are packed and unpacked
Then the packets are `01 01 07 05` and `01 00 07` (after the scheme id) and the rows round-trip (`on` false unpacks absent).

**AC-B3: Group presence bit**
Given the same shape with a group presence bit (a one-member `group`) as the source in place of the bool, in each package that has the kind
When mode is 0 and when mode is 1
Then the outcome follows AC-B1 and AC-B2 and equals the Python packet.

**AC-B4: Eight packages**
Given the shared corpus cases
When the runners of the eight packages run
Then 0 packages fail and 0 skip them; a package that differs is fixed in this loop or ticketed with the owner told.

## D: repeated-text headroom (AC-D)

**AC-D1: The case runs everywhere**
Given one 65,535-character text in 200 rounds of `times`
When Python, TypeScript, Java, Go, Swift, Rust and C++ pack and unpack it
Then every package has a test of exactly this case, the unpacked rounds equal the input, and the test prints the pack and unpack seconds.

**AC-D2: Headroom**
Given the measured time on this Mac (idle, release build) and on the next CI run
When it is compared with the package's nominal bound (1 s; C++ 3 s)
Then pack plus unpack is at most 50% of the bound in all seven packages (at most 500 ms; C++ at most 1,500 ms).

**AC-D3: A package above half**
Given a package above 50%
When the loop closes
Then its walker keeps the encoded text of the last round as in AZ-2815, with packet bytes unchanged (the `enc` rows of `fixtures/text/vectors.txt`), or a ticket for loop 56 is open and the owner told.

**AC-D4: The table**
Given AC-D1 to AC-D3
When the loop closes
Then the seven measured figures (local and CI) are written in the loop record.

## Non-functional

- No wire change; no packet that unpacked before stops unpacking.
- No C++ speed-suite case gets slower; flash at most 8,192 B, stack at most 512 B on the Cortex-M4F, `cpp-avr-uno` and `PACKBIN_NO_TEXT` inside their recorded margins.
