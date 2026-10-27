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

    private static byte[] bytesOf(String token) {
        return token.equals("-") ? new byte[0] : Handoff.parse(token);
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

    private static FrameDirection direction(int d) {
        return switch (d) {
            case 1 -> FrameDirection.UP;
            case 2 -> FrameDirection.DOWN;
            case 3 -> FrameDirection.GROUP;
            default -> throw new IllegalArgumentException("direction: " + d);
        };
    }

    private static String seal(String[] w) {
        byte[] key = bytesOf(w[0]);
        int epoch = Integer.parseInt(w[1]), d = Integer.parseInt(w[2]), tagLen = Integer.parseInt(w[3]);
        byte[] msgId = bytesOf(w[4]);
        int fkind = Integer.parseInt(w[5]);
        byte[] ad = bytesOf(w[6]), clear = bytesOf(w[7]), plain = bytesOf(w[8]);
        FrameSession session = FrameSession.load(key, epoch,
                new FrameConfig(tagLen, new FrameDirections(1 << (d - 1))));
        if (session == null) return "BadValue";
        byte[] out = new byte[300];
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
        FrameSession session = FrameSession.load(key, epoch,
                new FrameConfig(tagLen, new FrameDirections(1 << (d - 1))));
        if (session == null) return "BadValue";
        byte[] out = new byte[300];
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
            default -> throw new IllegalArgumentException("frame line: " + words[0]);
        };
    }

    static int run(String cmd, String[] args) {
        if (cmd.equals("frame-batch") && args.length == 2) {
            try {
                for (String text : Files.readAllLines(Path.of(args[1]), StandardCharsets.UTF_8)) {
                    if (!text.isBlank()) {
                        System.out.println(line(text.trim().split("\\s+")));
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
