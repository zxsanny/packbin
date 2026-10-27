package packbin;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/**
 * The frame-mode example of the README, kept here so that it compiles and runs with the suite. The text between the
 * README-BEGIN and README-END markers is what the README shows.
 */
public final class FrameReadmeExample {
    private FrameReadmeExample() {}

    public static void main(String[] args) {
        run();
        FrameSupport.finish("FrameReadmeExample");
    }

    static void run() {
        String[] shown = example();
        PackbinTest.expectEq("example: opened plaintext", "hello, relay", shown[0]);
        PackbinTest.expectEq("example: the same frame again", "Duplicate", shown[1]);
        PackbinTest.expectEq("example: MAC-only check", "true", shown[2]);
    }

    static String[] example() {
        // README-BEGIN
        byte[] key = new byte[32]; // the shared 32-byte key, from your key store
        byte[] msgId = {0, 0x30, 0x10, 0x05, (byte) 0xe8, 3, 0, 0}; // unique per (key, epoch, direction), never reused
        byte[] header = {0, 1, 0, 0x30, 0x10, 0x05, (byte) 0xe8, 3, 0, 0, 4}; // authenticated, not sent

        FrameConfig config = new FrameConfig(4, FrameDirections.of(FrameDirection.UP)); // 4-byte tag; up frames only

        try (FrameSession node = FrameSession.load(key, 1, config)) { // epoch 1; null if out of range
            MsgContext ctx = new MsgContext(msgId, 4);
            byte[] body = new byte[255];
            FrameSealed sealed = (FrameSealed) node.seal(FrameDirection.UP, ctx, header, null,
                    "hello, relay".getBytes(StandardCharsets.US_ASCII), body); // body = ciphertext + 4-byte tag

            ReplayWindow window = new ReplayWindow(); // one per sender, yours to keep
            byte[] plain = new byte[255];
            long counter = 7; // from bytes the tag covers, e.g. the message id
            Object opened = node.open(FrameDirection.UP, ctx, header, Arrays.copyOf(body, sealed.length), 0, window, counter, plain);
            int plainLength = ((FrameOpened) opened).plainLength; // plain[0, plainLength) holds the message
            Object again = node.open(FrameDirection.UP, ctx, header, Arrays.copyOf(body, sealed.length), 0, window, counter, plain);
            boolean duplicate = again instanceof Packbin.Duplicate; // refused before any MAC; also TagMismatch, TooOld, ...

            try (MacKey net = MacKey.derive(key, 1, "net".getBytes(StandardCharsets.US_ASCII))) { // MAC-only call
                byte[] tag = new byte[4];
                net.tag(tag, new byte[] {1, 0, 0, 0}, body); // the message may be passed in parts
                boolean valid = net.verify(tag, new byte[] {1, 0, 0, 0}, body); // best-effort constant-time compare
                // README-END
                return new String[] {new String(plain, 0, plainLength, StandardCharsets.US_ASCII),
                        duplicate ? "Duplicate" : FrameSupport.kind(again), Boolean.toString(valid)};
            }
        }
    }
}
