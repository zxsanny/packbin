# Scenarios — strings-lists-dicts

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | Caller packs an empty string, an empty list, and an empty dictionary | confirmed | The buffer is 6 bytes `000000000000` | AZ-1940 AC-4 | intake |
| S2 | Caller packs the user value twice | confirmed | The two buffers match, 0 mismatched bytes | AZ-1940 AC-1 | intake |
| S3 | Two callers pack the same user value at the same time | confirmed | Each call returns the same 103 bytes | AZ-1940 AC-1 | intake |
| S4 | Unpack stops inside a string whose count is 7 when 2 bytes remain | confirmed | Error, 0 values, needed 7, left 2 | AZ-1938 AC-4 | intake |
| S5 | Caller packs a string of 65536 UTF-8 bytes | confirmed | Pack writes 0 bytes and fails | AZ-1938 AC-3 | intake |
| S6 | Unpack sees the same dictionary key twice | confirmed | Error and 0 values | AZ-1940 AC-5 | intake |
| S7 | Caller packs the existing position record | confirmed | Still 13 bytes `4001000065cd1d00a3e1110100` | AZ-1941 AC-3 | intake |
| S8 | Caller inserts access keys as store, channel, map | confirmed | Same 103 bytes as sorted key order | AZ-1940 AC-2 | intake |
| S9 | Caller packs a counted list and then another field | confirmed | 4 bytes `01000102`; the list does not consume the next field | AZ-1939 AC-3 | intake |
| S10 | All six languages pack the user value | confirmed | 0 mismatched bytes between them | AZ-1940 AC-1 | intake |
| S11 | Caller packs a list whose element is one big-endian 2-byte integer 1 | confirmed | 4 bytes `01000001` | AZ-1939 AC-2 | intake |
| S12 | Caller unpacks the 103-byte user buffer | confirmed | username, two roles, three access keys; wrong fields 0 | AZ-1940 AC-3 | intake |
| S13 | The C# handoff and the position driver build in one folder | confirmed | Each project writes its own output, and the handoff prints the user value | AZ-1941 AC-1 | assess-round-1 |
| S14 | The C++ driver is built on a Mac whose clang needs the SDK headers | confirmed | `PACKBIN_CXX_SYSROOT` supplies the include; the position record stays 13 bytes | AZ-1941 AC-3 | assess-round-1 |

## Not walked

- Permission denied: the library has no accounts or tokens.
- Undo: pack does not store the previous buffer.
- A process killed mid-pack: there is no partial file to recover.

## Fit decisions

The count on a string, list, or dictionary is part of that field. Packets that do not use those fields stay the size they are today. A counted list and a repeat-until-the-buffer-ends group both stay. Repeat is not an element of a list or a dictionary.
