# Scenarios: frame ring, MAC rows over a message in several parts (loop 96)

Source: new-task Step 4.7 (loop 96). Status values: confirmed, out-of-scope, deferred. Fit walk: the ring line format is read by the eight drivers, `ring_frame.py`, `ring-frame.test.sh` and `ring-frame-drivers.test.sh`; no collision, no problem card (single-piece lines keep their meaning).

| id | scenario | status | AC ref | note |
|----|----------|--------|--------|------|
| M1 | A message in two, three, four or five pieces, tag lengths 4, 8, 16, 32: all eight languages give the reference tag | confirmed | AZ-3495 AC-1, AC-3 | first use |
| M2 | A single-piece line, written and read as before the change | confirmed | AZ-3495 AC-6 | repeat |
| M3 | Empty piece first, in the middle, last, or all pieces empty | confirmed | AZ-3495 AC-1 | boundary |
| M4 | Pieces cut at the hash block edges (56 and 64 bytes) and a 255-byte message in four pieces | confirmed | AZ-3495 AC-1 | boundary |
| M5 | Verify over pieces: a flipped tag bit and pieces in the wrong order give `invalid` in every language | confirmed | AZ-3495 AC-2 | invalid input |
| M6 | Refusals with pieces: a tag length of 5 and an empty label give `BadValue` | confirmed | AZ-3495 AC-2 | invalid input |
| M7 | A piece that is not hex or `-`, or an empty piece spelled as nothing: malformed line in all eight drivers | confirmed | AZ-3495 AC-4 | invalid input |
| M8 | A driver that uses only the first piece, joins pieces, or drops empty ones turns the ring red and the rows are named | confirmed | AZ-3495 AC-5 | partial failure |
| O1 | An empty list of pieces (zero pieces) | out-of-scope | - | one empty piece is `-` and is row `msg0` |
| O2 | `ring-ecc` and the packages' own tests | out-of-scope | - | other files, untouched |
