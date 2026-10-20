# Compact text: size report

Written by `scripts/text/size_report.py` (AZ-2657 AC-5, AZ-2733 AC-6, AZ-2740 AC-3). Run date: 2026-10-20.

Command: `python3 scripts/text/size_report.py fixtures/text/vectors.txt _docs/02_task_plans/compact-strings/size_report.md`

## Recipe files (sha256)

| file | sha256 |
|------|--------|
| `scripts/text/size_report.py` | `f90f1642fda17d404fb3eefc088e813e43d1e6d6478f330fbf8e0cb617565a4e` |
| `scripts/text/textfmt.py` (reference encoder) | `e32875847cb0441a09de827779e774531c64f1ad627a5452c55216f49242e8a9` |
| `scripts/text/train_tables.py` | `fd0c4ae81f586bb48ac4d33fed655c49060628ea9af2d54e04ea253e59cedd7e` |
| `fixtures/text/tables.json` (same as the sha256 in `compact-text.md`) | `764ad13ee701af908b7c802abe67d0ac8639bc9bce5a3af666695c5f6df1d9c4` |
| `fixtures/text/vectors.txt` | `aa2594d93d21efeb43485d895265c83888eaa2edb46cbd4a2afee850bdc84f07` |
| `fixtures/text/tables.report.md` | `a69352c538d30d36a8911cb9e62e47e646820f6bdfb5c2e8fd469ff1000c6b33` |

The Tatoeba corpus files of the training recipe are not in the repository. Their sha256 are recorded in `scripts/text/train_tables.py` (`CORPUS_SHA256`): eng `ac9f0d48a44c7ac4f3eab724567774487b9841dcfcb3b2bcac48e1cc5636cd96`, rus `db438e855b6b99874c4bef8770cdedbfae3e3ff1d48afa503852d3ec27bc2b92`, ukr `882a6b3976993fba09393926cb21a7e1cc97908cd73598dd9f736f949c853a7e`. They are not hashed by this script.

## CS-13 on every `enc` row

PASS: the script checked all 346 `enc` rows of `vectors.txt` (field never larger than today's 2-byte count plus UTF-8 up to 126 UTF-8 bytes, at most 1 byte larger up to 16,382, at most 2 above). The same 346 rows total 48387 bytes today and 40701 bytes compact (summed from the table below; the `random.*` and `size.*` rows hold texts that do not compress, so the total is not a measure of CS-1, CS-2 or CS-14).

## Held-out sentence sets (CS-1, CS-2, CS-14): copied, not re-run

These sizes need the Tatoeba corpus. The table is copied from `fixtures/text/tables.report.md` (sha256 above, written by `scripts/text/train_tables.py --corpus DIR`); `train_tables.py --corpus DIR --check` and the `OVER` grep are run by the agent with the corpus (`_docs/loops/loop35/smoke35.md` steps 5 and 6), not by CI.

| set | messages | chars | today (bytes) | compact (bytes) | compact / today | bits per char | bound | |
|-----|---------:|------:|--------------:|----------------:|----------------:|--------------:|------:|---|
| lower-ua | 1000 | 27775 | 52300 | 18575 | 35.5 % | 5.35 | 40 % | ok |
| lower-ru | 1000 | 31872 | 59824 | 20656 | 34.5 % | 5.18 | 40 % | ok |
| lower-en | 1000 | 37398 | 39398 | 22477 | 57.1 % | 4.81 | 62 % | ok |
| mixed | 1000 | 40917 | 65678 | 26409 | 40.2 % | 5.16 | 48 % | ok |
| raw-ua | 1000 | 27964 | 52698 | 19861 | 37.7 % | 5.68 | 40 % | ok |
| raw-ru | 1000 | 31457 | 59096 | 21417 | 36.2 % | 5.45 | 40 % | ok |
| raw-en | 1000 | 37340 | 39348 | 23536 | 59.8 % | 5.04 | 62 % | ok |
| numbers | 1000 | 15320 | 20642 | 10456 | 50.7 % | 5.46 | 56 % | ok |
| text+coords | 800 | 34927 | 56820 | 22137 | 39.0 % | 5.07 | 45 % | ok |

## Size of the vectors

Whole string fields; `today` is the 2-byte count plus UTF-8.

| family | rows | today (bytes) | compact (bytes) | compact / today |
|--------|-----:|--------------:|----------------:|----------------:|
| corpus.en | 45 | 1891 | 1095 | 57.9 % |
| corpus.mixed | 25 | 1730 | 689 | 39.8 % |
| corpus.ru | 45 | 2845 | 1019 | 35.8 % |
| corpus.ua | 70 | 4025 | 1462 | 36.3 % |
| hand.accent | 1 | 5 | 5 | 100.0 % |
| hand.apos_after_lock | 1 | 7 | 6 | 85.7 % |
| hand.apos_en | 1 | 7 | 5 | 71.4 % |
| hand.apos_ua | 1 | 9 | 6 | 66.7 % |
| hand.bmp_apostrophe | 1 | 11 | 9 | 81.8 % |
| hand.cap_each | 1 | 41 | 17 | 41.5 % |
| hand.cjk | 1 | 8 | 8 | 100.0 % |
| hand.coords | 1 | 18 | 10 | 55.6 % |
| hand.digits | 1 | 12 | 7 | 58.3 % |
| hand.emoji | 1 | 19 | 12 | 63.2 % |
| hand.empty | 1 | 2 | 1 | 50.0 % |
| hand.en_caps | 1 | 13 | 10 | 76.9 % |
| hand.en_text | 1 | 45 | 29 | 64.4 % |
| hand.en_then_ua | 1 | 22 | 13 | 59.1 % |
| hand.en_title | 1 | 13 | 10 | 76.9 % |
| hand.eng_all_letters | 1 | 29 | 22 | 75.9 % |
| hand.eng_caps_all_letters | 1 | 28 | 23 | 82.1 % |
| hand.extras | 1 | 16 | 16 | 100.0 % |
| hand.german | 1 | 9 | 9 | 100.0 % |
| hand.hello | 1 | 14 | 6 | 42.9 % |
| hand.hello_cap | 1 | 14 | 7 | 50.0 % |
| hand.hello_caps | 1 | 27 | 13 | 48.1 % |
| hand.hello_world | 1 | 14 | 10 | 71.4 % |
| hand.id | 1 | 14 | 9 | 64.3 % |
| hand.lock_all | 1 | 14 | 8 | 57.1 % |
| hand.lock_then_lower | 1 | 23 | 12 | 52.2 % |
| hand.lock_two_modes | 1 | 33 | 18 | 54.5 % |
| hand.minus | 1 | 7 | 5 | 71.4 % |
| hand.mixed_long | 1 | 54 | 24 | 44.4 % |
| hand.mixed_ok | 1 | 23 | 12 | 52.2 % |
| hand.modifier_apostrophe | 1 | 10 | 8 | 80.0 % |
| hand.newline | 1 | 23 | 10 | 43.5 % |
| hand.nul | 1 | 5 | 5 | 100.0 % |
| hand.num_after_text | 1 | 15 | 8 | 53.3 % |
| hand.num_mid | 1 | 10 | 7 | 70.0 % |
| hand.numset_all | 1 | 17 | 10 | 58.8 % |
| hand.one_a | 1 | 3 | 3 | 100.0 % |
| hand.one_ua | 1 | 4 | 3 | 75.0 % |
| hand.polish | 1 | 28 | 28 | 100.0 % |
| hand.punct | 1 | 35 | 17 | 48.6 % |
| hand.quotes_dash | 1 | 34 | 31 | 91.2 % |
| hand.rare_letters | 1 | 14 | 14 | 100.0 % |
| hand.ru_caps | 1 | 22 | 11 | 50.0 % |
| hand.ru_text | 1 | 32 | 12 | 37.5 % |
| hand.ru_yo | 1 | 32 | 13 | 40.6 % |
| hand.rus_all_letters | 1 | 68 | 28 | 41.2 % |
| hand.rus_caps_all_letters | 1 | 68 | 30 | 44.1 % |
| hand.shared_all | 1 | 34 | 34 | 100.0 % |
| hand.sharp_s | 1 | 4 | 4 | 100.0 % |
| hand.space | 1 | 3 | 3 | 100.0 % |
| hand.tab | 1 | 5 | 5 | 100.0 % |
| hand.text_after_num | 1 | 15 | 8 | 53.3 % |
| hand.time | 1 | 7 | 5 | 71.4 % |
| hand.tr_dotted | 1 | 11 | 10 | 90.9 % |
| hand.u10ffff | 1 | 6 | 6 | 100.0 % |
| hand.ua_ru | 1 | 27 | 10 | 37.0 % |
| hand.ua_then_en | 1 | 28 | 14 | 50.0 % |
| hand.ud7ff | 1 | 5 | 5 | 100.0 % |
| hand.ufeff | 1 | 6 | 6 | 100.0 % |
| hand.uffff | 1 | 5 | 5 | 100.0 % |
| hand.ukr_all_letters | 1 | 69 | 29 | 42.0 % |
| hand.ukr_caps_all_letters | 1 | 68 | 29 | 42.6 % |
| hand.zwj | 1 | 20 | 20 | 100.0 % |
| numbers.000 | 1 | 52 | 19 | 36.5 % |
| numbers.001 | 1 | 17 | 9 | 52.9 % |
| numbers.002 | 1 | 18 | 10 | 55.6 % |
| numbers.003 | 1 | 18 | 10 | 55.6 % |
| numbers.004 | 1 | 18 | 10 | 55.6 % |
| numbers.005 | 1 | 17 | 9 | 52.9 % |
| numbers.006 | 1 | 18 | 10 | 55.6 % |
| numbers.007 | 1 | 7 | 5 | 71.4 % |
| numbers.008 | 1 | 14 | 9 | 64.3 % |
| numbers.009 | 1 | 51 | 20 | 39.2 % |
| numbers.010 | 1 | 18 | 10 | 55.6 % |
| numbers.011 | 1 | 7 | 5 | 71.4 % |
| numbers.012 | 1 | 7 | 5 | 71.4 % |
| numbers.013 | 1 | 52 | 20 | 38.5 % |
| numbers.014 | 1 | 14 | 9 | 64.3 % |
| numbers.015 | 1 | 16 | 9 | 56.2 % |
| numbers.016 | 1 | 7 | 5 | 71.4 % |
| numbers.017 | 1 | 18 | 10 | 55.6 % |
| numbers.018 | 1 | 18 | 10 | 55.6 % |
| numbers.019 | 1 | 7 | 5 | 71.4 % |
| numbers.020 | 1 | 7 | 5 | 71.4 % |
| numbers.021 | 1 | 13 | 9 | 69.2 % |
| numbers.022 | 1 | 18 | 10 | 55.6 % |
| numbers.023 | 1 | 7 | 5 | 71.4 % |
| numbers.024 | 1 | 18 | 10 | 55.6 % |
| numbers.025 | 1 | 14 | 9 | 64.3 % |
| numbers.026 | 1 | 51 | 20 | 39.2 % |
| numbers.027 | 1 | 16 | 9 | 56.2 % |
| numbers.028 | 1 | 18 | 10 | 55.6 % |
| numbers.029 | 1 | 18 | 10 | 55.6 % |
| numbers.030 | 1 | 17 | 9 | 52.9 % |
| numbers.031 | 1 | 17 | 9 | 52.9 % |
| numbers.032 | 1 | 7 | 5 | 71.4 % |
| numbers.033 | 1 | 14 | 9 | 64.3 % |
| numbers.034 | 1 | 51 | 20 | 39.2 % |
| numbers.035 | 1 | 18 | 10 | 55.6 % |
| numbers.036 | 1 | 7 | 5 | 71.4 % |
| numbers.037 | 1 | 18 | 10 | 55.6 % |
| numbers.038 | 1 | 52 | 20 | 38.5 % |
| numbers.039 | 1 | 14 | 9 | 64.3 % |
| random.000 | 1 | 94 | 94 | 100.0 % |
| random.001 | 1 | 16 | 16 | 100.0 % |
| random.002 | 1 | 48 | 48 | 100.0 % |
| random.003 | 1 | 49 | 49 | 100.0 % |
| random.004 | 1 | 34 | 32 | 94.1 % |
| random.005 | 1 | 67 | 67 | 100.0 % |
| random.006 | 1 | 84 | 84 | 100.0 % |
| random.007 | 1 | 25 | 25 | 100.0 % |
| random.008 | 1 | 55 | 55 | 100.0 % |
| random.009 | 1 | 72 | 72 | 100.0 % |
| random.010 | 1 | 6 | 6 | 100.0 % |
| random.011 | 1 | 9 | 9 | 100.0 % |
| random.012 | 1 | 28 | 28 | 100.0 % |
| random.013 | 1 | 24 | 24 | 100.0 % |
| random.014 | 1 | 57 | 57 | 100.0 % |
| random.015 | 1 | 49 | 49 | 100.0 % |
| random.016 | 1 | 45 | 45 | 100.0 % |
| random.017 | 1 | 3 | 3 | 100.0 % |
| random.018 | 1 | 46 | 46 | 100.0 % |
| random.019 | 1 | 54 | 54 | 100.0 % |
| random.020 | 1 | 53 | 53 | 100.0 % |
| random.021 | 1 | 74 | 74 | 100.0 % |
| random.022 | 1 | 2 | 1 | 50.0 % |
| random.023 | 1 | 80 | 80 | 100.0 % |
| random.024 | 1 | 42 | 42 | 100.0 % |
| random.025 | 1 | 75 | 75 | 100.0 % |
| random.026 | 1 | 52 | 52 | 100.0 % |
| random.027 | 1 | 66 | 66 | 100.0 % |
| random.028 | 1 | 47 | 47 | 100.0 % |
| random.029 | 1 | 16 | 16 | 100.0 % |
| random.030 | 1 | 87 | 87 | 100.0 % |
| random.031 | 1 | 81 | 81 | 100.0 % |
| random.032 | 1 | 53 | 53 | 100.0 % |
| random.033 | 1 | 45 | 45 | 100.0 % |
| random.034 | 1 | 2 | 1 | 50.0 % |
| random.035 | 1 | 33 | 33 | 100.0 % |
| random.036 | 1 | 45 | 45 | 100.0 % |
| random.037 | 1 | 26 | 26 | 100.0 % |
| random.038 | 1 | 60 | 60 | 100.0 % |
| random.039 | 1 | 23 | 23 | 100.0 % |
| size.compact_127 | 1 | 388 | 128 | 33.0 % |
| size.compact_128 | 1 | 390 | 130 | 33.3 % |
| size.raw_126 | 1 | 128 | 128 | 100.0 % |
| size.raw_127 | 1 | 129 | 130 | 100.8 % |
| size.raw_16382 | 1 | 16384 | 16385 | 100.0 % |
| size.raw_16383 | 1 | 16385 | 16387 | 100.0 % |
| switch.en_num | 1 | 12 | 12 | 100.0 % |
| switch.en_ru | 1 | 15 | 14 | 93.3 % |
| switch.en_ua | 1 | 15 | 15 | 100.0 % |
| switch.num_en | 1 | 12 | 11 | 91.7 % |
| switch.num_ru | 1 | 15 | 10 | 66.7 % |
| switch.num_ua | 1 | 15 | 10 | 66.7 % |
| switch.ru_en | 1 | 17 | 13 | 76.5 % |
| switch.ru_num | 1 | 17 | 11 | 64.7 % |
| switch.ru_ua | 1 | 20 | 14 | 70.0 % |
| switch.ua_en | 1 | 17 | 15 | 88.2 % |
| switch.ua_num | 1 | 17 | 11 | 64.7 % |
| switch.ua_ru | 1 | 20 | 14 | 70.0 % |

CS-13 (never larger than today up to 126 UTF-8 bytes, +1 to 16,382, +2 above): PASS
