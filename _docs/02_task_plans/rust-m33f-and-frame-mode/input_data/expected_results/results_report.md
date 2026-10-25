# Expected results — loop 69 (frame mode)

Source: the worked examples E1 to E5 of PB-01 (`../../input/PB-01_frame_mode_contract_and_adr.md`), computed by meshbell with an independent implementation (Python 3 `hmac`/`hashlib`, `cryptography` 46.0.1 for HKDF and ChaCha20, checked against RFC 8439 §2.4.2). The loop must reproduce them byte for byte; a mismatch means the contract text or the reference is wrong and is settled before any package uses the file. All values hex, no separators; integers little-endian.

| Case | Inputs | Expected |
| --- | --- | --- |
| E1 up | key 32 x `11`, epoch 1, d 1, kind 4, tag 4, msg_id `00301005e8030000`, ad `000100301005e803000004`, plain `0102030405060708090a0b0c` | K_enc `2a26f46689797b89a46c24bb1d7d31876ffd6fe68f86b04bb32a1c62061437ce`; K_mac `8147b3e3c2a5feed9cd4a5167169c48a1fc898e03b9cfa48e4144efd6a5601e3`; N `00301005e803000041010000`; body `53e9dc75fb459d775e6205661cdf37ff` (tag `1cdf37ff`) |
| E2 down | key 32 x `11`, epoch 1, d 2, kind 5, tag 4, msg_id `00022001e9030000`, ad `003000022001e903000005`, plain bytes `40` to `69` (42 B) | K_enc `f421aaa83c48b853e9977379c0958c58f83e2fc72d590a57b1a8910b6802a93e`; K_mac `7f16afe6559313e8a883f384de44370e1b223a6de2a2252427f8da5833236063`; N `00022001e903000052010000`; body `7f711291e9a9ebb93760ac8b851f2a29c46a3b70f6a447b62ddbc159ddfba687109cc6d02d5e509bb9bd00b7da70` |
| E3 group | key 32 x `33`, epoch 7, d 3, kind 6, msg_id `00013002ea030000`, ad `ffff00013002ea03000006`, clear `a1b2c3`, plain bytes `80` to `93` (20 B) | K_enc `0a26995c011a4e87d1a327986b6b086202045544d3ab0a8fbcd681be1286bb05`; K_mac `190bb28d43cdff7805ef628706256badfec84c30fd15f4e426b048768a8431aa`; N `00013002ea03000063070000`; body tag 4 `a1b2c34f51e601a79e78a25a9bf5bb74206019f1d769783cbc82b7`; body tag 16 `a1b2c34f51e601a79e78a25a9bf5bb74206019f1d769783cbc82b7c519c38115025b8cd5b5f82b` |
| E4 MAC-only | key 32 x `22`, epoch 7, label `net`, message `e8030000` then bytes `c0` to `d3`, n 4 | K_label `dc5966ac393a983cec3f48ee16233b4b06b468d720732abdd8e91ae116bd4a93`; tag `56db9bec` |
| E5 MAC-only | key 32 x `22`, epoch 8, label `net`, message `636865636b` (`check`), n 4 | K_label `8faf8eec4c65f8c69dcfb879368d4b6e47580569fb93d175a60fdc351752af80`; tag `3cf8e8c5` |

## Replay window sequence (PB-03)

On an empty window: check 100 Fresh; commit 100 (top 100, bits `0x1`); check 100 Duplicate; check 99 Fresh; commit 99 (bits `0x3`); check 37 Fresh; commit 37 (bits `0x8000000000000003`); check 36 TooOld; check 37 Duplicate; check 163 Fresh; commit 163 (top 163, bits `0x8000000000000001`); check 100 Duplicate; check 99 TooOld; check 200 Fresh; commit 200 (top 200, bits `0x2000000001`); check 163 Duplicate; check 100 TooOld. Full table with the other coverage rows: `../../input/PB-03_frame_golden_vectors.md`.

## Primitive vectors (PB-02)

The published vectors listed in `../../input/PB-02_primitive_reference_vectors.md` (FIPS 180-4, RFC 4231 tc 1 to 7, RFC 5869 A.1 to A.3, RFC 8439 §2.3.2, A.1, §2.4.2, A.2) plus two `derived` edge rows.

## Embedded (PB-04)

| Check | Expected |
| --- | --- |
| Cortex-M4F `frame` feature set, flash | at most 20,480 B, figure recorded in `rust/embedded/limits.txt` (measured plus 5%) |
| Cortex-M4F `frame` feature set, stack | at most 2,048 B |
| `size_of::<MacKey>()` | at most 72 B |
| `size_of::<ReplayWindow>()` | 16 B |
| frame `Session`, two slots, three directions | at most 640 B |
| existing sets base, text, ecc, session | flash and stack unchanged (base 16384 / 512, text 27964 / 2898, ecc 18879 / 798, session 19325 / 1924 are the limits) |
