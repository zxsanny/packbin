package packbin;

/** The worked examples E1 to E3 of the contract as sealable inputs. */
final class FrameExamples {
    final byte[] key;
    final int epoch;
    final FrameDirection dir;
    final MsgContext ctx;
    final byte[] ad;
    final byte[] clear;
    final byte[] plain;
    final String body4;

    private FrameExamples(byte fill, int epoch, FrameDirection dir, String id, int kind, String ad, String clear, byte[] plain,
            String body4) {
        this.key = new byte[32];
        java.util.Arrays.fill(key, fill);
        this.epoch = epoch;
        this.dir = dir;
        this.ctx = new MsgContext(FrameSupport.hex(id), kind);
        this.ad = FrameSupport.hex(ad);
        this.clear = FrameSupport.hex(clear);
        this.plain = plain;
        this.body4 = body4;
    }

    static byte[] range(int from, int to) {
        byte[] out = new byte[to - from];
        for (int i = 0; i < out.length; i++) {
            out[i] = (byte) (from + i);
        }
        return out;
    }

    static FrameExamples[] all() {
        return new FrameExamples[] {
            new FrameExamples((byte) 0x11, 1, FrameDirection.UP, "00301005e8030000", 4, "000100301005e803000004", "-",
                    FrameSupport.hex("0102030405060708090a0b0c"), "53e9dc75fb459d775e6205661cdf37ff"),
            new FrameExamples((byte) 0x11, 1, FrameDirection.DOWN, "00022001e9030000", 5, "003000022001e903000005", "-",
                    range(0x40, 0x6a),
                    "7f711291e9a9ebb93760ac8b851f2a29c46a3b70f6a447b62ddbc159ddfba687109cc6d02d5e509bb9bd00b7da70"),
            new FrameExamples((byte) 0x33, 7, FrameDirection.GROUP, "00013002ea030000", 6, "ffff00013002ea03000006", "a1b2c3",
                    range(0x80, 0x94), "a1b2c34f51e601a79e78a25a9bf5bb74206019f1d769783cbc82b7"),
        };
    }

    FrameSession session(int tagLen) {
        return FrameSession.load(key, epoch, tagLen, FrameDirection.values());
    }

    byte[] sealed(FrameSession session) {
        byte[] out = new byte[300];
        FrameSealed sealed = (FrameSealed) session.seal(dir, ctx, ad, clear, plain, out);
        return java.util.Arrays.copyOf(out, sealed.length);
    }
}
