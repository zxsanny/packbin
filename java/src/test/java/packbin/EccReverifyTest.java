package packbin;

/**
 * AZ-2695 AC-1: the repaired bytes are checked once more against the parity before they are returned. Each word is
 * the position fixture (n = 4) with 3 or 4 wrong bytes whose locator has fewer places than the syndrome sequence
 * needs: a repair without that check finds the right number of roots, changes bytes and hands over a word that is
 * not a code word.
 */
final class EccReverifyTest {
    private static final Object[][] WORDS = {
        {1, "4001008865cd1da5a3e1118a00d4856682"},
        {1, "4001000065cd7a00a3de110100cad26682"},
        {1, "4001000065cde000a3e111010074676628"},
        {2, "400100af65cd1d00a3e111bf90ca856682"},
        {2, "4001000065d31d0037e111d600ca856682"},
        {2, "4001001c65cdee00a3e1116f00ca856682"},
    };

    private EccReverifyTest() {}

    static void run() {
        for (Object[] word : WORDS) {
            aRepairThatLeavesNoCodeWordIsRefused((Integer) word[0], (String) word[1]);
        }
    }

    private static void aRepairThatLeavesNoCodeWordIsRefused(int limit, String hex) {
        // Arrange
        byte[] received = EccSupport.bytesOf(hex);

        // Act
        EccSupport.Run run = EccSupport.unpackPosition(received, 4, limit);

        // Assert
        String label = "AZ-2695 limit " + limit + " word " + hex;
        PackbinTest.expectTrue(label + " is refused as uncorrectable", run.uncorrectable());
        PackbinTest.expectEq(label + " rows handed over", 0, run.rows.size());
    }
}
