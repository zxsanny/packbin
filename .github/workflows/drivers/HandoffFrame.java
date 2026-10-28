import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import packbin.FrameConfig;
import packbin.FrameDirection;
import packbin.FrameDirections;
import packbin.FrameOpened;
import packbin.FrameSealed;
import packbin.FrameSession;
import packbin.MacKey;
import packbin.MsgContext;
import packbin.Packbin;

/**
 * The frame commands of {@link Handoff} (AZ-3338; contract pack-session 3.0.0, frame mode).
 *
 * <pre>
 *   frame-batch &lt;file&gt;   one line per line of the file: seal, open, mac, verify
 * </pre>
 */
final class HandoffFrame {
    private HandoffFrame() {
    }

    // A token that is not hex (a bad digit, an odd length) is an error of the line, never a byte of another value.
    private static byte[] bytesOf(String token) {
        if (token.equals("-")) return new byte[0];
        if (!token.matches("([0-9a-fA-F]{2})*")) throw new IllegalArgumentException("bad hex: " + token);
        return Handoff.parse(token);
    }

    private static String hexOf(byte[] data) {
        return data.length == 0 ? "-" : Handoff.hex(data);
    }

    private static String kind(Object error) {
        if (error instanceof Packbin.BadValue) return "BadValue";
        if (error instanceof Packbin.TooLong) return "TooLong";
        if (error instanceof Packbin.BufferFull) return "BufferFull";
        if (error instanceof Packbin.ShortPacket) return "ShortPacket";
        if (error instanceof Packbin.TagMismatch) return "TagMismatch";
        return "error";
    }

    // The enum holds no direction outside 1 to 3: null is what the package refuses as BadValue ("a call in another
    // direction is BadValue"), as its own vector test does.
    private static FrameDirection direction(int d) {
        return switch (d) {
            case 1 -> FrameDirection.UP;
            case 2 -> FrameDirection.DOWN;
            case 3 -> FrameDirection.GROUP;
            default -> null;
        };
    }

    // The optional trailing fields of a seal or open line: the directions loaded (digits 1 to 3) and the output buffer size.
    private static FrameDirections directions(String[] w) {
        String digits = w.length > 9 ? w[9] : "123";
        if (!digits.matches("[123]+")) throw new IllegalArgumentException("bad dirs: " + digits);
        FrameDirection[] set = new FrameDirection[digits.length()];
        for (int i = 0; i < set.length; i++) {
            set[i] = direction(digits.charAt(i) - '0');
        }
        return FrameDirections.of(set);
    }

    private static int size(String[] w) {
        return w.length > 10 ? Integer.parseInt(w[10]) : 300;
    }

    private static String seal(String[] w) {
        byte[] key = bytesOf(w[0]);
        int epoch = Integer.parseInt(w[1]), d = Integer.parseInt(w[2]), tagLen = Integer.parseInt(w[3]);
        byte[] msgId = bytesOf(w[4]);
        int fkind = Integer.parseInt(w[5]);
        byte[] ad = bytesOf(w[6]), clear = bytesOf(w[7]), plain = bytesOf(w[8]);
        FrameSession session = FrameSession.load(key, epoch, new FrameConfig(tagLen, directions(w)));
        if (session == null) return "BadValue";
        byte[] out = new byte[size(w)];
        Object result = session.seal(direction(d), new MsgContext(msgId, fkind), ad, clear, plain, out);
        if (result instanceof FrameSealed sealed) return hexOf(java.util.Arrays.copyOf(out, sealed.length));
        return kind(result);
    }

    private static String open(String[] w) {
        byte[] key = bytesOf(w[0]);
        int epoch = Integer.parseInt(w[1]), d = Integer.parseInt(w[2]), tagLen = Integer.parseInt(w[3]);
        byte[] msgId = bytesOf(w[4]);
        int fkind = Integer.parseInt(w[5]);
        byte[] ad = bytesOf(w[6]);
        int clearLen = Integer.parseInt(w[7]);
        byte[] body = bytesOf(w[8]);
        FrameSession session = FrameSession.load(key, epoch, new FrameConfig(tagLen, directions(w)));
        if (session == null) return "BadValue";
        byte[] out = new byte[size(w)];
        Object result = session.open(direction(d), new MsgContext(msgId, fkind), ad, body, clearLen, null, 0, out);
        if (result instanceof FrameOpened opened) return hexOf(java.util.Arrays.copyOf(out, opened.plainLength));
        return kind(result);
    }

    private static String mac(String[] w) {
        byte[] key = bytesOf(w[0]);
        int epoch = Integer.parseInt(w[1]);
        byte[] label = bytesOf(w[2]);
        int n = Integer.parseInt(w[3]);
        byte[] message = bytesOf(w[4]);
        MacKey mk = MacKey.derive(key, epoch, label);
        if (mk == null) return "BadValue";
        byte[] out = new byte[n];
        Object result = mk.tag(out, message);
        return result == null ? hexOf(out) : kind(result);
    }

    private static String verify(String[] w) {
        byte[] key = bytesOf(w[0]);
        int epoch = Integer.parseInt(w[1]);
        byte[] label = bytesOf(w[2]);
        int n = Integer.parseInt(w[3]);
        byte[] message = bytesOf(w[4]), tag = bytesOf(w[5]);
        MacKey mk = MacKey.derive(key, epoch, label);
        if (mk == null) return "BadValue";
        return mk.verify(tag, message) ? "valid" : "invalid";
    }

    private static String line(String[] words) {
        return switch (words[0]) {
            case "seal" -> seal(java.util.Arrays.copyOfRange(words, 1, words.length));
            case "open" -> open(java.util.Arrays.copyOfRange(words, 1, words.length));
            case "mac" -> mac(java.util.Arrays.copyOfRange(words, 1, words.length));
            case "verify" -> verify(java.util.Arrays.copyOfRange(words, 1, words.length));
            case "open-skip", "verify-skip" -> "skip";
            default -> throw new IllegalArgumentException("unknown word " + words[0]);
        };
    }

    static int run(String cmd, String[] args) {
        if (cmd.equals("frame-batch") && args.length == 2) {
            try {
                int number = 0;
                for (String text : Files.readAllLines(Path.of(args[1]), StandardCharsets.UTF_8)) {
                    number++;
                    if (!text.isBlank()) {
                        try {
                            System.out.println(line(text.trim().split("\\s+")));
                        } catch (IllegalArgumentException | ArrayIndexOutOfBoundsException e) {
                            System.err.println("frame line " + number + ": " + e.getMessage());
                            return 1;
                        }
                    }
                }
            } catch (IOException e) {
                System.err.println("frame-batch: " + e);
                return 1;
            }
            return 0;
        }
        return 2;
    }
}
