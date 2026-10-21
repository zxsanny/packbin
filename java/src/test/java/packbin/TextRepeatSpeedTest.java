package packbin;

import java.util.List;
import java.util.Map;

/**
 * AZ-2737 AC-1 (CS-D7, TW-5): one text of 65,535 characters written in 200 rounds of a times group packs and unpacks within
 * one second nominal, as the Python and TypeScript HD-2 tests (AZ-2664) hold. Java keeps no encoded text between rounds, so
 * this is the case where a walker that encodes the text again in each round would be slow.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class TextRepeatSpeedTest {
    private static final int ROUNDS = 200;
    private static final int LENGTH = 65_535;

    private TextRepeatSpeedTest() {}

    static void run() {
        aLone65535CharacterTextUnder200RoundsPacksAndUnpacksWithinASecond();
        differentTextsBetweenEqualOnesAreEachEncodedFromTheirOwnBytes();
    }

    // Review of loop 46: the sink keeps the last text's field; a different text after an equal pair must not get it.
    private static void differentTextsBetweenEqualOnesAreEachEncodedFromTheirOwnBytes() {
        // Arrange
        Scheme<Map> scheme = Maps.scheme(1, Packbin.u8(0, Access.get("n"), Access.set("n")),
                Packbin.times(1, 0, Packbin.utf8(1, Access.get("s"), Access.set("s"))));
        List<Object> input = List.of("привіт", "привіт", "hello", "привіт", "", "", "hello!", "hello");
        Map<String, Object> row = Maps.map("n", input.size(), "s", input);

        // Act
        byte[] packet = BinaryPacker.pack(scheme, row);
        TextVectorsTest.Outcome got = TextVectorsTest.unpack(scheme, packet);

        // Assert
        PackbinTest.expectTrue("review46 the packet unpacks (" + got.error + ", " + got.thrown + ")",
                got.error == null && got.thrown == null && got.row != null);
        PackbinTest.expectEq("review46 unpacked rounds", input, got.row == null ? null : got.row.get("s"));
    }

    // AZ-2737 AC-1; the printed label is AZ-3134 (loop 55 headroom table).
    private static void aLone65535CharacterTextUnder200RoundsPacksAndUnpacksWithinASecond() {
        // Arrange
        Scheme<Map> scheme = Maps.scheme(1, Packbin.u8(0, Access.get("n"), Access.set("n")),
                Packbin.times(1, 0, Packbin.utf8(1, Access.get("s"), Access.set("s"))));
        String text = "q".repeat(LENGTH);
        Map<String, Object> row = Maps.map("n", ROUNDS, "s", text);
        Timing.Limit limit = Timing.bound(1.0);

        // Act
        long start = System.nanoTime();
        byte[] packet = BinaryPacker.pack(scheme, row);
        long packed = System.nanoTime();
        TextVectorsTest.Outcome got = TextVectorsTest.unpack(scheme, packet);
        long end = System.nanoTime();

        // Assert
        PackbinTest.expectTrue("AZ-2737 AC-1 the packet holds 200 rounds of the text: " + packet.length, packet.length > ROUNDS * LENGTH);
        PackbinTest.expectTrue("AZ-2737 AC-1 the packet unpacks (" + got.error + ", " + got.thrown + ")",
                got.error == null && got.thrown == null && got.row != null);
        int wrong = 0;
        List<Object> texts = got.row == null ? List.of() : (List<Object>) got.row.get("s");
        for (Object round : texts) {
            if (!text.equals(round)) {
                wrong++;
            }
        }
        PackbinTest.expectEq("AZ-2737 AC-1 unpacked rounds", ROUNDS, texts.size());
        PackbinTest.expectEq("AZ-2737 AC-1 unpacked rounds that differ from the input", 0, wrong);
        System.out.println("AZ-3134 65535 characters x 200 rounds: pack " + (packed - start) / 1e9 + " s, unpack " + (end - packed) / 1e9 + " s");
        limit.expectWithinNanos("AZ-2737 AC-1 pack and unpack of 65535 characters x 200 rounds", end - start);
    }
}
