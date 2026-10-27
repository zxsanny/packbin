package packbin;

import static packbin.FrameDirection.DOWN;
import static packbin.FrameDirection.GROUP;
import static packbin.FrameDirection.UP;

/** AZ-3322: {@code FrameConfig} and {@code FrameDirections}, the load shape of Rust, C# and Swift (AC-3 refusals). */
public final class FrameConfigTest {
    private static final byte[] KEY = new byte[32];

    private FrameConfigTest() {}

    public static void main(String[] args) {
        run();
        FrameSupport.finish("FrameConfigTest");
    }

    static void run() {
        loadOfABadConfigGivesNull();
        anEmptySetLoadsASessionThatRefusesEveryCall();
        aCallOutsideTheLoadedSetIsBadValue();
        aSetHoldsEachListedDirectionOnce();
        aNullListOrANullDirectionGivesNoSet();
    }

    private static void loadOfABadConfigGivesNull() {
        // Arrange
        String[] labels = {"a null config", "a null direction set", "a tag length of 5"};
        FrameConfig[] configs = {null, new FrameConfig(4, null), new FrameConfig(5, FrameDirections.ALL)};

        for (int i = 0; i < configs.length; i++) {
            // Act
            FrameSession session = FrameSession.load(KEY, 1, configs[i]);

            // Assert
            PackbinTest.expectTrue("load with " + labels[i] + " gives null", session == null);
        }
        try (FrameSession control = FrameSession.load(KEY, 1, new FrameConfig(4, FrameDirections.ALL))) {
            PackbinTest.expectTrue("load with tag length 4 and every direction gives a session", control != null);
        }
    }

    private static void anEmptySetLoadsASessionThatRefusesEveryCall() {
        // Arrange
        MsgContext ctx = new MsgContext(new byte[8], 1);
        byte[] body;
        try (FrameSession all = FrameSession.load(KEY, 1, new FrameConfig(4, FrameDirections.ALL))) {
            byte[] out = new byte[16];
            FrameSealed sealed = (FrameSealed) all.seal(UP, ctx, null, null, new byte[3], out);
            body = java.util.Arrays.copyOf(out, sealed.length); // a valid up body, so open fails on the set alone
        }
        try (FrameSession none = FrameSession.load(KEY, 1, new FrameConfig(4, FrameDirections.of()))) {
            PackbinTest.expectTrue("an empty set loads a session", none != null);
            for (FrameDirection direction : FrameDirection.values()) {
                // Act
                byte[] out = FrameSupport.filled(16);
                Object sealed = none.seal(direction, ctx, null, null, new byte[3], out);
                Object opened = none.open(direction, ctx, null, body, 0, null, 0, out);

                // Assert
                PackbinTest.expectTrue("empty set: seal " + direction + " " + FrameSupport.kind(sealed),
                        sealed instanceof Packbin.BadValue);
                PackbinTest.expectTrue("empty set: open " + direction + " " + FrameSupport.kind(opened),
                        opened instanceof Packbin.BadValue);
                PackbinTest.expectTrue("empty set: nothing written for " + direction, FrameSupport.allSentinel(out));
            }
        }
    }

    private static void aCallOutsideTheLoadedSetIsBadValue() {
        // Arrange
        MsgContext ctx = new MsgContext(new byte[8], 1);
        try (FrameSession up = FrameSession.load(KEY, 1, new FrameConfig(4, FrameDirections.of(UP)))) {
            byte[] body = new byte[16];
            Object sealed = up.seal(UP, ctx, null, null, new byte[3], body);

            // Act
            Object sealDown = up.seal(DOWN, ctx, null, null, new byte[3], new byte[16]);
            Object openGroup = up.open(GROUP, ctx, null, body, 0, 7, 0, null, 0, new byte[3], 0);

            // Assert
            PackbinTest.expectTrue("seal up in the loaded set", sealed instanceof FrameSealed);
            PackbinTest.expectTrue("seal down outside the set: " + FrameSupport.kind(sealDown),
                    sealDown instanceof Packbin.BadValue);
            PackbinTest.expectTrue("open group outside the set: " + FrameSupport.kind(openGroup),
                    openGroup instanceof Packbin.BadValue);
        }
    }

    private static void aSetHoldsEachListedDirectionOnce() {
        // Arrange
        FrameDirections twice = FrameDirections.of(UP, GROUP, UP);

        // Act
        boolean[] held = {twice.contains(UP), twice.contains(DOWN), twice.contains(GROUP), twice.contains(null)};

        // Assert
        PackbinTest.expectEq("up and group listed, up twice", "true false true false",
                held[0] + " " + held[1] + " " + held[2] + " " + held[3]);
        PackbinTest.expectEq("the set names its directions in wire order", "[UP, GROUP]", twice.toString());
        PackbinTest.expectEq("the order of the list does not matter", FrameDirections.of(GROUP, UP), twice);
        PackbinTest.expectEq("equal sets have equal hashes", FrameDirections.of(GROUP, UP).hashCode(), twice.hashCode());
        PackbinTest.expectEq("ALL is up, down and group", FrameDirections.of(UP, DOWN, GROUP), FrameDirections.ALL);
        PackbinTest.expectTrue("ALL is not empty", !FrameDirections.ALL.isEmpty());
        PackbinTest.expectTrue("no direction is the empty set",
                FrameDirections.of().isEmpty() && !FrameDirections.of().contains(UP));
    }

    private static void aNullListOrANullDirectionGivesNoSet() {
        // Act
        FrameDirections nullList = FrameDirections.of((FrameDirection[]) null);
        FrameDirections nullDirection = FrameDirections.of(UP, null);

        // Assert
        PackbinTest.expectTrue("a null list gives null", nullList == null);
        PackbinTest.expectTrue("a null direction in the list gives null", nullDirection == null);
        PackbinTest.expectTrue("a config holding that null loads nothing",
                FrameSession.load(KEY, 1, new FrameConfig(4, nullDirection)) == null);
    }
}
