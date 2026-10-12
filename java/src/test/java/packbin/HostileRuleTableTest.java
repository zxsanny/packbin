package packbin;

import java.io.IOException;
import java.util.List;
import java.util.Map;

/**
 * AZ-2418 (AC-1): a rule table that is wrong cannot pass. Each test hands the hostile loader one deliberately wrong
 * entry, built here and nowhere on disk, and expects the loader to fail naming that case.
 */
final class HostileRuleTableTest {
    private HostileRuleTableTest() {}

    private static final String PACK_ID = "pack_out_of_range_integer";
    private static final String CONSTRUCT_ID = "nine_flag_bits";

    static void run() throws IOException {
        controlRealTablesPass();
        packEntryWithAnotherMessage();
        packEntryWithAnotherExceptionType();
        packEntryMissing();
        constructEntryWithAnotherMessage();
        constructEntryWithAnotherExceptionType();
        constructEntryMissing();
    }

    /** Without this the tests below would pass against a loader that fails everything. */
    private static void controlRealTablesPass() throws IOException {
        // Act
        List<String> pack = HostileVectorTest.replayRefusal(PACK_ID, HostileRefusals.PACK, HostileRefusals.CONSTRUCT);
        List<String> construct =
                HostileVectorTest.replayRefusal(CONSTRUCT_ID, HostileRefusals.PACK, HostileRefusals.CONSTRUCT);
        // Assert
        PackbinTest.expectEq("rule table control: " + PACK_ID + " passes with its real rule", List.of(), pack);
        PackbinTest.expectEq("rule table control: " + CONSTRUCT_ID + " passes with its real rule", List.of(), construct);
    }

    private static void packEntryWithAnotherMessage() throws IOException {
        expectNamedFailure("wrong pack message", PACK_ID, HostileVectorTest.replayRefusal(PACK_ID,
                Map.of(PACK_ID, new HostileRefusals.Rule(IllegalArgumentException.class, "some other rule")), Map.of()),
                "refused by another rule");
    }

    private static void packEntryWithAnotherExceptionType() throws IOException {
        expectNamedFailure("wrong pack exception type", PACK_ID, HostileVectorTest.replayRefusal(PACK_ID,
                Map.of(PACK_ID, new HostileRefusals.Rule(IllegalStateException.class, "0: 300 does not fit")), Map.of()),
                "threw IllegalArgumentException, expected IllegalStateException");
    }

    private static void packEntryMissing() throws IOException {
        expectNamedFailure("missing pack entry", PACK_ID,
                HostileVectorTest.replayRefusal(PACK_ID, Map.of(), Map.of()), "no refusal rule");
    }

    private static void constructEntryWithAnotherMessage() throws IOException {
        expectNamedFailure("wrong construct message", CONSTRUCT_ID, HostileVectorTest.replayRefusal(CONSTRUCT_ID,
                Map.of(), Map.of(CONSTRUCT_ID, new HostileRefusals.Rule(IllegalArgumentException.class, "some other rule"))),
                "refused by another rule");
    }

    private static void constructEntryWithAnotherExceptionType() throws IOException {
        expectNamedFailure("wrong construct exception type", CONSTRUCT_ID, HostileVectorTest.replayRefusal(CONSTRUCT_ID,
                Map.of(), Map.of(CONSTRUCT_ID, new HostileRefusals.Rule(IllegalStateException.class, "flags already has 8 bits"))),
                "threw IllegalArgumentException, expected IllegalStateException");
    }

    private static void constructEntryMissing() throws IOException {
        expectNamedFailure("missing construct entry", CONSTRUCT_ID,
                HostileVectorTest.replayRefusal(CONSTRUCT_ID, Map.of(), Map.of()), "no refusal rule");
    }

    /** The loader must have failed exactly once, and the failure must name the case and say why. */
    private static void expectNamedFailure(String label, String id, List<String> failures, String reason) {
        PackbinTest.expectEq("rule table " + label + ": loader fails once", 1, failures.size());
        String failure = failures.isEmpty() ? "" : failures.get(0);
        PackbinTest.expectTrue("rule table " + label + ": failure names " + id + ": " + failure,
                failure.contains(id));
        PackbinTest.expectTrue("rule table " + label + ": failure says why (" + reason + "): " + failure,
                failure.contains(reason));
    }
}
