# Compact-strings research run (loop 35, 2026-10-18)

`bench.py` measures every candidate on Tatoeba sentences; `extras.py` checks edge cases, 3,000 random Unicode strings and code lengths; `theirs.py` runs the Huffman scheme pasted by the owner unchanged; `usx.js` measures Unishox2 (npm `unishox2.siara.cc`, the JavaScript port). `bench_run.log` is the output of the run in the report.

Rebuild: make a directory `$PACKBIN_BENCH_DIR` with `corpus/{ukr,rus,eng}_sentences.tsv` (unpacked exports from https://downloads.tatoeba.org/exports/per_language/<lang>/<lang>_sentences.tsv.bz2, CC BY 2.0 FR) and `unishox/` (`npm install --ignore-scripts unishox2.siara.cc`), then `python3 bench.py`. Python 3.9 or newer, Node. Seeds are fixed (35), so the numbers repeat.
The corpus and the npm package are not committed.
