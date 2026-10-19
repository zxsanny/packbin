package packbin;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

/** AC-1 probe (d): the text edge cases a random run is unlikely to hit (as the C# EdgesText of the same audit). */
@SuppressWarnings({"unchecked", "rawtypes"})
final class ProbeEdgesText {
    private static final TextModes.Mode UA = TextModes.MODES[0];
    private static final TextModes.Mode RU = TextModes.MODES[1];
    private static final TextModes.Mode EN = TextModes.MODES[2];

    private ProbeEdgesText() {}

    static void run() {
        varints();
        headers();
        raw();
        escapeSweep();
        codeCut();
        lengths();
        dictKeys();
        exhaustive();
    }

    /** {result (String or error), cursor position, thrown}. */
    private static Object[] read(byte[] field) {
        Cursor cur = new Cursor(0, 65535, 1 << 20);
        try {
            Object got = TextDecoder.read("x", field, cur);
            return new Object[] {got, cur.pos, null};
        } catch (RuntimeException | Error ex) {
            return new Object[] {null, cur.pos, ex};
        }
    }

    private static void expect(String name, byte[] field, String text) {
        Object[] got = read(field);
        if (got[2] != null) {
            AuditProbe.fail(name + ": " + got[2].getClass().getName() + " escaped: " + ((Throwable) got[2]).getMessage());
            return;
        }
        if (text == null) {
            AuditProbe.check(got[0] instanceof Packbin.ShortPacket, name + ": refused");
        } else {
            AuditProbe.check(text.equals(got[0]) && (int) got[1] == field.length, name + ": accepted as expected");
        }
    }

    private static byte[] b(int... values) {
        byte[] out = new byte[values.length];
        for (int i = 0; i < values.length; i++) {
            out[i] = (byte) values[i];
        }
        return out;
    }

    private static byte[] repeat(int value, int count) {
        byte[] out = new byte[count];
        Arrays.fill(out, (byte) value);
        return out;
    }

    private static void varints() {
        read(b(0xff, 0xff, 0x7f)); // class initialisation (the tables) is not counted
        long before = AuditProbe.allocated();
        Object[] got = read(b(0xff, 0xff, 0x7f));
        long alloc = AuditProbe.allocated() - before;
        AuditProbe.check(got[0] instanceof Packbin.ShortPacket s && s.needed == 2_097_151 && s.left == 0 && alloc < 4096,
                "varint ff ff 7f with no payload: short, needed 2,097,151, " + alloc + " B allocated");
        expect("varint 80 00 (not minimal)", b(0x80, 0x00), null);
        expect("varint 81 80 00 (not minimal)", b(0x81, 0x80, 0x00), null);
        expect("varint 80 80 80 01 (four bytes)", b(0x80, 0x80, 0x80, 0x01), null);
        AuditProbe.check(read(new byte[0])[0] instanceof Packbin.ShortPacket s && s.needed == 1, "varint: empty buffer is short, needed 1");
        AuditProbe.check(read(b(0xff))[0] instanceof Packbin.ShortPacket s && s.needed == 2, "varint: ff is short, needed 2");
        AuditProbe.check(read(b(0xff, 0xff))[0] instanceof Packbin.ShortPacket s && s.needed == 3, "varint: ff ff is short, needed 3");
        expect("varint 80 80 01 (16,384, three bytes): raw 16,383 'a'",
                AuditProbe.concat(b(0x80, 0x80, 0x01, 0x10), repeat('a', 16_383)), "a".repeat(16_383));
    }

    private static void headers() {
        expect("payload 00 (two symbol bits)", b(0x01, 0x00), null);
        expect("payload e0 (pad 7 covers the prefix)", b(0x01, 0xe0), null);
        for (int mode = 5; mode <= 7; mode++) {
            expect("start mode " + mode, b(0x01, mode << 2), null);
        }
        expect("raw 10 alone is the empty text", b(0x01, 0x10), "");
        expect("raw prefix 11", b(0x02, 0x11, 0x41), null);
        for (int low = 1; low <= 3; low++) {
            expect("raw prefix with low bits " + low, b(0x02, 0x10 | low, 0x41), null);
        }
        ProbeBits w = new ProbeBits(0);
        w.symbol(UA, 0);
        byte[] p = w.payload();
        int pad = (p[0] & 0xff) >> 5;
        if (pad > 0) {
            p[p.length - 1] |= 1;
            expect("pad bits not zero (pad " + pad + ")", ProbeBits.field(p), null);
        }
    }

    private static void raw() {
        expect("raw 65,535 'a'", AuditProbe.concat(AuditProbe.varint(65_536), b(0x10), repeat('a', 65_535)), "a".repeat(65_535));
        expect("raw 65,536 'a'", AuditProbe.concat(AuditProbe.varint(65_537), b(0x10), repeat('a', 65_536)), null);
        String[] bad = {"eda080", "edbfbf", "c080", "c1bf", "e08080", "e09fbf", "f0808080", "f08fbfbf", "f4908080", "f5808080", "f8", "ff",
            "80", "e282", "f09f98", "e228a1", "c328"};
        for (String hex : bad) {
            byte[] raw = AuditProbe.bytes(hex);
            expect("raw " + hex, AuditProbe.concat(AuditProbe.varint(raw.length + 1), b(0x10), raw), null);
        }
        expect("raw efbbbf61 keeps the BOM", AuditProbe.concat(b(0x05, 0x10), AuditProbe.bytes("efbbbf61")), "﻿a");
        expect("raw 00 is NUL", b(0x02, 0x10, 0x00), "\0");
        expect("raw f48fbfbf is U+10FFFF", AuditProbe.concat(b(0x05, 0x10), AuditProbe.bytes("f48fbfbf")), new String(Character.toChars(0x10FFFF)));
        expect("raw efbfbf is U+FFFF", AuditProbe.concat(b(0x04, 0x10), AuditProbe.bytes("efbfbf")), "￿");
    }

    private static void escapeSweep() {
        int space = UA.sharedBase + ProbeBits.indexOf(UA.shared, ' ');
        List<String> good = List.of("41", "c3a9", "e282ac", "f09f9880", "00", "f48fbfbf");
        List<String> invalid = List.of("eda080", "c181", "e09fbf", "f08fbfbf", "f4908080", "f8888080", "80", "e228a1", "ff");
        List<String> all = new ArrayList<>(good);
        all.addAll(invalid);
        int failures = 0;
        int cases = 0;
        for (int k = 0; k < 8; k++) {
            for (String hex : all) {
                byte[] bytes = AuditProbe.bytes(hex);
                boolean ok = good.contains(hex);
                for (int cut = 0; cut <= (ok ? 1 : 0); cut++) {
                    ProbeBits w = new ProbeBits(0);
                    for (int i = 0; i < k; i++) {
                        w.symbol(UA, space);
                    }
                    w.symbol(UA, UA.esc);
                    for (int i = 0; i < bytes.length - cut; i++) {
                        w.writeByte(bytes[i] & 0xff);
                    }
                    Object[] got = read(w.field());
                    cases++;
                    String expected = ok && cut == 0 ? " ".repeat(k) + new String(bytes, StandardCharsets.UTF_8) : null;
                    boolean pass = got[2] == null && (expected == null ? got[0] instanceof Packbin.ShortPacket : expected.equals(got[0]));
                    if (!pass) {
                        failures++;
                        AuditProbe.fail("esc sweep k=" + k + " " + hex + " cut=" + cut + ": " + (got[2] != null ? got[2] : got[0]));
                    }
                }
            }
        }
        AuditProbe.check(failures == 0, "esc sweep: " + cases + " cases at 8 alignments, valid, cut short and invalid scalars");
    }

    private static void codeCut() {
        int longest = -1;
        for (int s = 0; s < UA.bits.length && longest < 0; s++) {
            if (UA.bits[s] == 16) {
                longest = s;
            }
        }
        int refused = 0;
        for (int drop = 1; drop < 16; drop++) {
            ProbeBits w = new ProbeBits(0);
            int code = UA.codes[longest];
            for (int i = 15; i >= drop; i--) {
                w.raw(((code >> i) & 1) != 0);
            }
            Object[] got = read(w.field());
            if (got[2] != null) {
                AuditProbe.fail("code cut by " + drop + " bits: " + got[2]);
            } else if (got[0] instanceof Packbin.ShortPacket) {
                refused++;
            }
        }
        AuditProbe.check(refused == 15, "code cut at the end of the stream: " + refused + " of 15 cuts refused");
    }

    private static byte[] build(int chars, Consumer<ProbeBits> tail) {
        int o = ProbeBits.indexOf(RU.letters, 'о');
        ProbeBits w = new ProbeBits(1);
        for (int i = 0; i < chars; i++) {
            w.symbol(RU, o);
        }
        if (tail != null) {
            tail.accept(w);
        }
        return w.field();
    }

    private static Consumer<ProbeBits> esc(String hex) {
        return w -> {
            w.symbol(RU, RU.esc);
            for (byte x : AuditProbe.bytes(hex)) {
                w.writeByte(x & 0xff);
            }
        };
    }

    private static void lengths() {
        expect("compact 32,767 'о' + space (65,535 B)", build(32_767, w -> w.symbol(RU, RU.sharedBase)), "о".repeat(32_767) + " ");
        expect("compact 32,768 'о' (65,536 B)", build(32_768, null), null);
        expect("compact 32,766 'о' + ESC 4-byte (65,536 B)", build(32_766, esc("f09f9880")), null);
        expect("compact 32,766 'о' + ESC 3-byte (65,535 B)", build(32_766, esc("e282ac")), "о".repeat(32_766) + "€");
        expect("compact 32,767 'о' + ESC 1-byte (65,535 B)", build(32_767, esc("41")), "о".repeat(32_767) + "A");
        expect("compact 32,767 'о' + ESC 2-byte (65,536 B)", build(32_767, esc("c3a9")), null);
    }

    private static Object unpackDict(byte[]... keys) {
        List<byte[]> parts = new ArrayList<>();
        parts.add(new byte[] {2, (byte) keys.length, 0});
        for (byte[] key : keys) {
            parts.add(key);
            parts.add(new byte[] {7});
        }
        int[] got = {-1};
        Object error = BinaryPacker.unpack(AuditProbe.concat(parts.toArray(new byte[0][])),
                AuditProbe.MAP.on(row -> got[0] = ((Map) ((Map) row).get("m")).size()));
        return error != null ? error : (Object) got[0];
    }

    private static void dictKeys() {
        ProbeBits w = new ProbeBits(2);
        w.symbol(EN, ProbeBits.indexOf(EN.letters, 'a'));
        byte[] compactA = w.field();
        AuditProbe.check(unpackDict(b(0x02, 0x10, 0x61), compactA) instanceof Packbin.ShortPacket,
                "dict: key 'a' raw and 'a' compact (" + AuditProbe.hex(compactA) + ") is a repeated key");
        AuditProbe.check(unpackDict(b(0x02, 0x10, 0x61), b(0x02, 0x10, 0x61)) instanceof Packbin.ShortPacket, "dict: key 'a' twice is refused");
        AuditProbe.check(unpackDict(b(0x00), b(0x00)) instanceof Packbin.ShortPacket, "dict: empty key twice is refused");
        AuditProbe.check(Integer.valueOf(1).equals(unpackDict(b(0x00))), "dict: one empty key is accepted");
        AuditProbe.check(Integer.valueOf(2).equals(unpackDict(AuditProbe.bytes("0310c3a9"), AuditProbe.bytes("041065cc81"))),
                "dict: NFC and NFD forms of é are two keys (strings compared, not normalized)");
    }

    private static void exhaustive() {
        long calls = 0;
        long accepted = 0;
        long thrown = 0;
        long overBound = 0;
        long start = System.nanoTime();
        for (int n = 1; n <= 3; n++) {
            byte[] field = new byte[1 + n];
            field[0] = (byte) n;
            int limit = 1 << (8 * n);
            for (int v = 0; v < limit; v++) {
                for (int i = 0; i < n; i++) {
                    field[1 + i] = (byte) (v >> (8 * (n - 1 - i)));
                }
                Object[] got = read(field);
                calls++;
                if (got[2] != null) {
                    if (thrown++ < 5) {
                        AuditProbe.fail("exhaustive: " + got[2] + " on " + AuditProbe.hex(field));
                    }
                    continue;
                }
                if (!(got[0] instanceof String text)) {
                    continue;
                }
                accepted++;
                if (AuditProbe.utf8Count(text) > 6 * n + 8 || !AuditProbe.wellFormed(text)) {
                    overBound++;
                }
            }
        }
        AuditProbe.check(thrown == 0 && overBound == 0, String.format(
                "exhaustive 1-3 byte payloads: %d calls, %d accepted, thrown %d, over 6N+8 or ill-formed %d, %.1f s",
                calls, accepted, thrown, overBound, (System.nanoTime() - start) / 1e9));
    }
}
