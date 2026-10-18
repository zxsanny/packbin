// reads {texts:[...], flips:[bitPositionFraction...]} JSON on argv[2] file; prints {lens:[...], bad:n, dmg:[decoded or null]}
const fs = require('fs');
const usx = require(process.argv[2] + '/node_modules/unishox2.siara.cc/unishox2.js');
const input = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));
const out = new Uint8Array(65536);
const lens = [];
let bad = 0;
const damaged = [];
input.texts.forEach((s, i) => {
  const b = Buffer.from(s, 'utf8');
  const n = usx.unishox2_compress_simple(b, b.length, out);
  lens.push(n);
  let back = null;
  try { back = usx.unishox2_decompress_simple(out.slice(0, Math.ceil(n)), Math.ceil(n)); } catch (e) { back = null; }
  if (back !== s) bad++;
  if (input.flips) {
    const c = out.slice(0, Math.ceil(n));
    const bit = Math.floor(input.flips[i] * Math.ceil(n) * 8);
    c[bit >> 3] ^= (0x80 >> (bit & 7));
    let d = null;
    try { d = usx.unishox2_decompress_simple(c, Math.ceil(n)); } catch (e) { d = null; }
    damaged.push(d);
  }
});
fs.writeFileSync(process.argv[4], JSON.stringify({ lens, bad, damaged }));
