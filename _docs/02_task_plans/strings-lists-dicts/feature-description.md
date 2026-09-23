# Strings, lists, and dictionaries

packbin grows three fields on the list the six languages already walk: a UTF-8 string, a counted list, and a counted dictionary. The caller still writes the list. The C# object and the TypeScript object are values, not the schema. A string, list, or dictionary carries a 2-byte little-endian count of at most 65535. Dictionary pairs are ordered by the key's UTF-8 bytes. List and dictionary elements may be any existing field except `repeat`. The position record stays 13 bytes. All six languages produce the same bytes.

## Scenarios

| id | scenario | status | behavior (confirmed) | AC ref |
|----|----------|--------|----------------------|--------|
| S1 | Empty string, empty list, empty dictionary | confirmed | 6 bytes `000000000000` | F-AC-4 |
| S2 | Pack the user value twice | confirmed | The two buffers match | F-AC-1 |
| S3 | Two callers pack at once | confirmed | Each call returns the same 103 bytes | F-AC-1 |
| S4 | String count 7 with 2 bytes left | confirmed | Error, 0 values, needed 7, left 2 | F-AC-8 |
| S5 | String of 65536 bytes | confirmed | Pack writes 0 bytes and fails | F-AC-7 |
| S6 | Same dictionary key twice | confirmed | Error and 0 values | F-AC-9 |
| S7 | Existing position record | confirmed | Still 13 bytes `4001000065cd1d00a3e1110100` | AC-1 |
| S8 | Access keys inserted as store, channel, map | confirmed | Same 103 bytes as sorted order | F-AC-3 |
| S9 | Counted list then another field | confirmed | 4 bytes `01000102`; the next field survives | F-AC-10 |
| S10 | Six languages pack the user value | confirmed | 0 mismatched bytes | F-AC-1 |
| S11 | List of one big-endian 2-byte integer 1 | confirmed | 4 bytes `01000001` | F-AC-6 |
| S12 | Unpack the 103-byte user buffer | confirmed | username, two roles, three access keys | F-AC-2 |

## Fit decisions

The 2-byte count is part of the string, list, or dictionary field. Other packets gain 0 bytes. A counted list and a repeat-until-the-end group both stay. Repeat is not a list or dictionary element. An application table from an integer id to display text stays out of scope.
