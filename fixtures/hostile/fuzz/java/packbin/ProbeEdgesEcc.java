package packbin;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.function.Supplier;

/** AC-2 probe (d): the ECC, dispatch and session edge cases a random run is unlikely to hit (as the C# EdgesEcc). */
@SuppressWarnings({"unchecked", "rawtypes"})
final class ProbeEdgesEcc {
    private ProbeEdgesEcc() {}

    static void run() {
        sweep();
        lengths();
        callerChecks();
        dispatch();
        sessionIndex();
        sessionClearSize();
        signedBytes();
    }

    private static Map<String, Object> row(String s) {
        Map<String, Object> m = new HashMap<>();
        m.put("s", s);
        return m;
    }

    private static void sweep() {
        Random r = new Random(4101);
        long calls = 0;
        long thrown = 0;
        long wrong = 0;
        for (int n = 1; n <= 32; n++) {
            int t = n / 2;
            for (int size = n; size <= Ecc.MAX_BLOCK; size++) {
                byte[] clear = new byte[size - n];
                r.nextBytes(clear);
                byte[] sent = ProbeGf.protect(clear, n);
                List<Object[]> inputs = new ArrayList<>();
                inputs.add(new Object[] {sent, true});
                byte[] d = sent.clone();
                ProbeGf.corrupt(d, t, r);
                inputs.add(new Object[] {d, true});
                d = sent.clone();
                ProbeGf.corrupt(d, t + 1, r);
                inputs.add(new Object[] {d, false});
                byte[] random = new byte[size];
                r.nextBytes(random);
                inputs.add(new Object[] {random, false});
                byte[] lengthByte = ProbeGf.encode(clear.length ^ (1 + r.nextInt(255)), clear, n);
                ProbeGf.corrupt(lengthByte, Math.max(0, t - 1), r);
                inputs.add(new Object[] {lengthByte, false});
                byte[] ones = new byte[size];
                Arrays.fill(ones, (byte) 0xff);
                inputs.add(new Object[] {ones, false});
                inputs.add(new Object[] {new byte[size], false});
                for (Object[] in : inputs) {
                    calls++;
                    try {
                        Object res = EccRepair.repair((byte[]) in[0], n, t);
                        if ((boolean) in[1] && !(res instanceof EccRepair.Fixed f && Arrays.equals(f.clear, clear))) {
                            wrong++;
                        }
                        if (res instanceof EccRepair.Fixed f && !ProbeGf.valid(ProbeGf.protect(f.clear, n), n)) {
                            wrong++;
                        }
                        if (!(res instanceof EccRepair.Fixed || res instanceof Packbin.Uncorrectable)) {
                            wrong++;
                        }
                    } catch (RuntimeException | Error ex) {
                        if (thrown++ < 5) {
                            AuditProbe.fail("sweep n=" + n + " N=" + size + ": " + ex);
                        }
                    }
                }
            }
        }
        AuditProbe.check(thrown == 0 && wrong == 0, "sweep n=1..32, N=n..254: " + calls + " repairs, thrown " + thrown + ", wrong " + wrong);
    }

    private static void lengths() {
        boolean all = true;
        for (int n = 1; n <= 32; n++) {
            byte[] empty = ProbeGf.protect(new byte[0], n);
            Object ok = EccRepair.repair(empty, n, n / 2);
            Object dispatched = BinaryPacker.unpackRepair(empty, n / 2, AuditProbe.SINGLE.withParity(n).on(x -> {}));
            Object shorter = EccRepair.repair(Arrays.copyOf(empty, n - 1), n, n / 2);
            Object none = EccRepair.repair(new byte[0], n, 0);
            boolean pass = ok instanceof EccRepair.Fixed f && f.clear.length == 0
                    && dispatched instanceof Packbin.ShortPacket d && d.field.isEmpty() && d.needed == 1
                    && shorter instanceof Packbin.ShortPacket s && s.field.equals("parity")
                    && none instanceof Packbin.ShortPacket z && z.field.equals("parity") && z.left == 0;
            if (!pass) {
                all = false;
                AuditProbe.fail("lengths n=" + n + ": " + ok + " " + dispatched + " " + shorter + " " + none);
            }
        }
        AuditProbe.check(all, "lengths: N = n (empty clear), N = n - 1 and N = 0 for n = 1..32");
        AuditProbe.check(EccRepair.repair(new byte[255], 32, 16) instanceof Packbin.TooLong t && t.length == 255 && t.limit == 254,
                "length 255: too_long before arithmetic");
        AuditProbe.check(BinaryPacker.unpackRepair(new byte[1 << 20], 1, AuditProbe.SINGLE.withParity(2).on(x -> {}))
                instanceof Packbin.TooLong t && t.length == 1 << 20, "length 1 MiB with parity: too_long");
    }

    private static String thrown(Supplier<Object> call) {
        try {
            call.get();
            return "nothing";
        } catch (RuntimeException ex) {
            return ex.getClass().getSimpleName() + ": " + ex.getMessage();
        }
    }

    private static void callerChecks() {
        Scheme.Handler<?> h4 = AuditProbe.SINGLE.withParity(4).on(x -> {});
        Scheme.Handler<?> h2 = AuditProbe.MAP.withParity(2).on(x -> {});
        Scheme.Handler<?> h4b = AuditProbe.SINGLE.withParity(4).on(x -> {});
        byte[] bytes = new byte[10];
        System.out.println("caller: t = 3 for n = 4 -> " + thrown(() -> BinaryPacker.unpackRepair(bytes, 3, h4)));
        System.out.println("caller: t = -1 -> " + thrown(() -> BinaryPacker.unpackRepair(bytes, -1, h4)));
        System.out.println("caller: mixed 4 and 2 -> " + thrown(() -> BinaryPacker.unpackRepair(bytes, 0, h4, h2)));
        System.out.println("caller: duplicate type and mixed -> " + thrown(() -> BinaryPacker.unpackRepair(bytes, 0, h4, h2, h4b)));
        System.out.println("caller: no handlers -> " + thrown(() -> BinaryPacker.unpackRepair(bytes, 0)));
        System.out.println("caller: mixed and bad limit -> " + thrown(() -> BinaryPacker.unpackRepair(bytes, 9, h4, h2)));
        System.out.println("caller: n = 0, t = 1 -> " + thrown(() -> BinaryPacker.unpackRepair(bytes, 1, AuditProbe.SINGLE.on(x -> {}))));
        AuditProbe.check(thrown(() -> AuditProbe.SINGLE.withParity(33)).startsWith("IllegalArgument"), "caller: parity 33 is not built");
    }

    private static void dispatch() {
        Scheme<Map> single = AuditProbe.SINGLE.withParity(4);
        byte[] clear = BinaryPacker.packClear(AuditProbe.SINGLE, row("abc"));
        byte[] sent = Ecc.protect(clear, 4);
        byte[] wrongType = sent.clone();
        wrongType[0] = 0x63;
        Object[] got = {null};
        Object res = BinaryPacker.unpackRepair(wrongType, 2, single.on(x -> got[0] = ((Map) x).get("s")));
        AuditProbe.check(res instanceof Packbin.Repaired p && p.count == 1 && "abc".equals(got[0]),
                "dispatch: a wrong type byte is repaired before the handler is picked");
        byte[] otherClear = clear.clone();
        otherClear[0] = 0x63;
        Object other = BinaryPacker.unpackRepair(ProbeGf.protect(otherClear, 4), 2, single.on(x -> {}));
        AuditProbe.check(other instanceof Packbin.TypeMismatch m && m.actual == 0x63, "dispatch: an intact message of an unknown type is a type mismatch");
        byte[] copy = wrongType.clone();
        BinaryPacker.unpackRepair(wrongType, 2, single.on(x -> {}));
        AuditProbe.check(Arrays.equals(copy, wrongType), "dispatch: the repaired input buffer is not written");
    }

    private static void sessionIndex() {
        byte[] seed = new byte[32];
        for (int i = 0; i < 32; i++) {
            seed[i] = (byte) i;
        }
        PackSession send = PackSession.load(seed);
        PackSession recv = PackSession.load(seed);
        PackSession unopened = PackSession.load(seed);
        AuditProbe.check(unopened.unpackRepair(new byte[5], -5) instanceof Packbin.ShortPacket s && s.needed == 1 && s.left == 0,
                "session: not open answers first (before the empty handler list and the bad limit)");
        recv.join(send.start());
        Scheme<Map> scheme = AuditProbe.SINGLE.withParity(4);
        byte[][] payloads = new byte[8][];
        for (int i = 0; i < 8; i++) {
            payloads[i] = send.pack(scheme, row("p" + i));
        }
        Object[] got = {null};
        Scheme.Handler<?> h = scheme.on(x -> got[0] = ((Map) x).get("s"));
        List<String> results = new ArrayList<>();
        java.util.function.BiConsumer<String, Supplier<Object>> step = (label, call) -> {
            got[0] = null;
            try {
                Object e = call.get();
                results.add(label + ": " + (e == null || e instanceof Packbin.Repaired ? "ok " + got[0] : e.getClass().getSimpleName()));
            } catch (RuntimeException ex) {
                results.add(label + ": threw " + ex.getClass().getSimpleName());
            }
        };
        byte[] garbage = new byte[payloads[0].length];
        new Random(7).nextBytes(garbage);
        step.accept("0 garbage", () -> recv.unpackRepair(garbage, 2, h));
        step.accept("1 p1", () -> recv.unpackRepair(payloads[1], 2, h));
        step.accept("2 255 bytes", () -> recv.unpackRepair(new byte[255], 2, h));
        step.accept("3 p3 with 2 wrong bytes", () -> {
            byte[] p = payloads[3].clone();
            p[0] ^= 1;
            p[p.length - 1] ^= 2;
            return recv.unpackRepair(p, 2, h);
        });
        step.accept("4 3 bytes", () -> recv.unpackRepair(new byte[3], 2, h));
        step.accept("- bad limit", () -> recv.unpackRepair(payloads[5], 3, h));
        step.accept("- mixed", () -> recv.unpackRepair(payloads[5], 0, h, AuditProbe.MAP.withParity(2).on(x -> {})));
        step.accept("- duplicate", () -> recv.unpackRepair(payloads[5], 0, h, scheme.on(x -> {})));
        step.accept("- empty", () -> recv.unpackRepair(payloads[5], 0));
        step.accept("5 p5", () -> recv.unpackRepair(payloads[5], 2, h));
        step.accept("6 p6 detect-only with 1 wrong byte", () -> {
            byte[] p = payloads[6].clone();
            p[1] ^= 4;
            return recv.unpack(p, h);
        });
        step.accept("7 p7", () -> recv.unpack(payloads[7], h));
        System.out.println("session steps: " + String.join("; ", results));
        AuditProbe.check(results.get(1).equals("1 p1: ok p1") && results.get(3).equals("3 p3 with 2 wrong bytes: ok p3")
                && results.get(9).equals("5 p5: ok p5") && results.get(10).endsWith("Uncorrectable")
                && results.get(11).equals("7 p7: ok p7"),
                "session: refused payloads advance the receive index, refused calls do not");
    }

    private static void sessionClearSize() {
        byte[] seed = new byte[32];
        PackSession send = PackSession.load(seed);
        PackSession recv = PackSession.load(seed);
        recv.join(send.start());
        Map<String, Object> big = row("中".repeat(100));
        byte[] clear = BinaryPacker.pack(AuditProbe.SINGLE, big);
        try {
            byte[] payload = send.pack(AuditProbe.SINGLE, big);
            Object[] got = {null};
            Object error = recv.unpack(payload, AuditProbe.SINGLE.on(x -> got[0] = ((Map) x).get("s")));
            AuditProbe.check(payload.length == clear.length && error == null && big.get("s").equals(got[0]),
                    "session n=0: a " + clear.length + "-byte clear message packs to " + payload.length + " bytes and unpacks");
        } catch (RuntimeException ex) {
            AuditProbe.fail("session n=0: pack of a " + clear.length + "-byte clear message threw " + ex);
        }
        try {
            byte[] p = send.pack(AuditProbe.SINGLE.withParity(4), big);
            AuditProbe.fail("session n=4: a " + clear.length + "-byte clear message packed to " + p.length + " bytes");
        } catch (IllegalArgumentException ex) {
            AuditProbe.check(true, "session n=4: a " + clear.length + "-byte clear message is refused (" + ex.getMessage() + ")");
        }
    }

    /** Every byte value 0x80..0xff (negative in Java) at every position of a short protected message. */
    private static void signedBytes() {
        long calls = 0;
        long thrown = 0;
        for (int n = 1; n <= 32; n += 31) {
            for (int size = n; size <= n + 4; size++) {
                for (int p = 0; p < size; p++) {
                    for (int v = 0x80; v <= 0xff; v++) {
                        byte[] buf = new byte[size];
                        Arrays.fill(buf, (byte) 0x80);
                        buf[p] = (byte) v;
                        calls++;
                        try {
                            EccRepair.repair(buf, n, n / 2);
                        } catch (RuntimeException | Error ex) {
                            if (thrown++ < 3) {
                                AuditProbe.fail("signed bytes n=" + n + ": " + ex);
                            }
                        }
                    }
                }
            }
        }
        AuditProbe.check(thrown == 0, "signed bytes: " + calls + " repairs of buffers of bytes 0x80..0xff, thrown " + thrown);
    }
}
