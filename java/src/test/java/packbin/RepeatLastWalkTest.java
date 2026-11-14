package packbin;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Random;
import java.util.function.Supplier;

/**
 * AZ-4257 (hygiene entry walk-first-writer-memo, F79 of the loop 113 audit): the repeat-last walk of a scheme costs the
 * size of the scheme whatever its shape. A chain of nested whens after a repeat that writes nothing made the old walk
 * ask for the first writer of every level again (quadratic); the walk now works each one out once. The decisions and the
 * refusal texts stay the same: a differential over random trees against a copy of the old walk kept in this file.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class RepeatLastWalkTest {
    private static final int CHAIN = 4_000;
    /** The deepest chain a scheme may hold is 256 levels (contract scheme-depth): the whole build runs on this one. */
    private static final int BUILT_CHAIN = 250;
    private static final int BUILD_RUNS = 100;
    /** About 2.5 times the 0.015 to 0.018 s that BUILD_RUNS whole builds take on the arm64 Mac (AZ-4307); with the old quadratic walk added they take 0.064 to 0.069 s. */
    private static final double BUILD_SECONDS = 0.04;
    private static final int SIBLINGS = 16_000;
    private static final int TREES = 30_000;

    private RepeatLastWalkTest() {}

    static void run() {
        aChainOfNestedWhensBuildsInLinearTime();
        aWholeBuildOfTwoHundredFiftyNestedWhensOrGroupsIsLinear();
        sixteenThousandSiblingWhensThatWriteNothingBuildInLinearTime();
        randomTreesGetTheSameDecisionAndTextAsTheOldWalk();
    }

    /** u8 k; repeat(zero-width bytes) leaves a repeat open that no field has followed; then the chain follows it. */
    private static void aChainOfNestedWhensBuildsInLinearTime() {
        // Arrange: the walk is recursive, so the chain runs on a thread whose stack the platform default does not
        // decide. The walk alone takes the chain of CHAIN; a scheme is built only up to the depth limit.
        long[] nanos = new long[2];
        Scheme<Map>[] scheme = new Scheme[1];
        Timing.Limit[] limits = new Timing.Limit[2];

        // Act: the walk alone, then the whole build
        onBigStack(() -> {
            Field inner = empty(2);
            for (int i = 0; i < CHAIN; i++) {
                inner = Packbin.when(2, Packbin.eq(0, 1), inner);
            }
            List<Field> fields = List.of(u8(0), Packbin.repeat(1, empty(1)), inner);
            limits[0] = Timing.bound(0.04);
            long start = System.nanoTime();
            SchemeOrder.checkRepeatLast(fields);
            nanos[0] = System.nanoTime() - start;
            Field built = empty(2);
            for (int i = 0; i < BUILT_CHAIN; i++) {
                built = Packbin.when(2, Packbin.eq(0, 1), built);
            }
            limits[1] = Timing.bound(0.09);
            start = System.nanoTime();
            scheme[0] = Maps.scheme(1, u8(0), Packbin.repeat(1, empty(1)), built);
            nanos[1] = System.nanoTime() - start;
        });

        // Assert
        PackbinTest.expectTrue("AZ-4257 the chain of " + BUILT_CHAIN + " whens builds", scheme[0] != null);
        System.out.println("AZ-4257 chain of " + CHAIN + " nested whens: walk " + nanos[0] / 1e9 + " s; build of "
                + BUILT_CHAIN + ": " + nanos[1] / 1e9 + " s");
        limits[0].expectWithinNanos("AZ-4257 AC-1 the walk of a chain of " + CHAIN + " nested whens after an open repeat",
                nanos[0]);
        limits[1].expectWithinNanos("AZ-4257 AC-1 the build of a chain of " + BUILT_CHAIN + " nested whens after an open repeat",
                nanos[1]);
    }

    /**
     * AZ-4307 item 4: the whole build (not the walk alone) of the deepest chain a scheme may hold, for nested whens and
     * for nested groups, each behind a repeat that writes nothing. One build of 250 levels takes about 0.2 ms, too
     * short to tell from the clock's noise, so {@link #BUILD_RUNS} builds are timed together; the bound is a few times
     * the total measured on an idle host, so a build step that costs the square of the depth (the old repeat-last walk
     * did) fails it.
     */
    private static void aWholeBuildOfTwoHundredFiftyNestedWhensOrGroupsIsLinear() {
        // Arrange
        String[] names = {"whens", "groups"};
        Field[][] chains = new Field[2][BUILD_RUNS];
        for (int kind = 0; kind < 2; kind++) {
            for (int run = 0; run < BUILD_RUNS; run++) {
                Field inner = empty(kind == 0 ? 2 : 0);
                for (int i = 0; i < BUILT_CHAIN; i++) {
                    inner = kind == 0
                            ? Packbin.when(2, Packbin.eq(0, 1), inner)
                            : Packbin.group(Access.get("m"), Access.set("m"), inner);
                }
                chains[kind][run] = inner;
            }
        }
        Timing.Limit[] limits = new Timing.Limit[2];
        long[] nanos = new long[2];

        // Act
        for (int kind = 0; kind < 2; kind++) {
            limits[kind] = Timing.bound(BUILD_SECONDS);
            long start = System.nanoTime();
            for (int run = 0; run < BUILD_RUNS; run++) {
                Scheme<Map> built = Maps.scheme(1, u8(0), Packbin.repeat(1, empty(1)), chains[kind][run]);
                if (built == null) {
                    throw new IllegalStateException("no scheme");
                }
            }
            nanos[kind] = System.nanoTime() - start;
        }

        // Assert
        for (int kind = 0; kind < 2; kind++) {
            System.out.println("AZ-4307 " + BUILD_RUNS + " whole builds of " + BUILT_CHAIN + " nested " + names[kind] + ": "
                    + nanos[kind] / 1e9 + " s");
            limits[kind].expectWithinNanos("AZ-4307 AC-4 " + BUILD_RUNS + " whole builds of " + BUILT_CHAIN + " nested "
                    + names[kind], nanos[kind]);
        }
    }

    private static void onBigStack(Runnable body) {
        Throwable[] failure = new Throwable[1];
        Thread thread = new Thread(null, () -> {
            try {
                body.run();
            } catch (Throwable ex) {
                failure[0] = ex;
            }
        }, "repeat-last-chain", 512L * 1024 * 1024);
        thread.start();
        try {
            thread.join();
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(ex);
        }
        if (failure[0] != null) {
            throw new IllegalStateException(failure[0]);
        }
    }

    private static void sixteenThousandSiblingWhensThatWriteNothingBuildInLinearTime() {
        // Arrange
        Field[] fields = new Field[SIBLINGS + 2];
        fields[0] = u8(0);
        fields[1] = Packbin.repeat(1, empty(1));
        for (int i = 0; i < SIBLINGS; i++) {
            fields[i + 2] = Packbin.when(i + 2, Packbin.eq(0, 1), empty(i + 2));
        }
        Timing.Limit limit = Timing.bound(0.2);

        // Act
        long start = System.nanoTime();
        Scheme<Map> scheme = Maps.scheme(1, fields);
        long elapsed = System.nanoTime() - start;

        // Assert
        PackbinTest.expectTrue("AZ-4257 the " + SIBLINGS + " sibling whens build", scheme != null);
        System.out.println("AZ-4257 " + SIBLINGS + " sibling whens: " + elapsed / 1e9 + " s");
        limit.expectWithinNanos("AZ-4257 AC-1 " + SIBLINGS + " sibling whens that write nothing after an open repeat",
                elapsed);
    }

    /** AC-2: the decision (built or the text of the refusal) of the new walk equals the old one's on every tree. */
    private static void randomTreesGetTheSameDecisionAndTextAsTheOldWalk() {
        // Arrange
        Random random = new Random(4257);
        int refused = 0;
        int built = 0;
        int different = 0;
        String firstDifference = null;

        // Act
        for (int i = 0; i < TREES; i++) {
            List<Field> tree = list(random, 4);
            String before = decide(() -> OldWalk.check(tree));
            String after = decide(() -> SchemeOrder.checkRepeatLast(tree));
            if (before.equals("built")) {
                built++;
            } else {
                refused++;
            }
            if (!before.equals(after)) {
                different++;
                if (firstDifference == null) {
                    firstDifference = "old [" + before + "] new [" + after + "]";
                }
            }
        }

        // Assert
        PackbinTest.expectEq("AZ-4257 AC-2 trees with another decision or text than the old walk (" + firstDifference + ")",
                0, different);
        PackbinTest.expectTrue("AZ-4257 AC-2 the trees hold both outcomes: refused " + refused + ", built " + built,
                refused > TREES / 10 && built > TREES / 10);
    }

    private static String decide(Runnable check) {
        try {
            check.run();
            return "built";
        } catch (IllegalArgumentException ex) {
            return ex.getMessage();
        }
    }

    private static Field u8(int id) {
        return Packbin.u8(id, Access.get("x" + id), Access.set("x" + id));
    }

    private static Field empty(int id) {
        return Packbin.bytes(id, Access.get("z"), Access.ignore(), 0);
    }

    private static List<Field> list(Random random, int depth) {
        int n = random.nextInt(depth > 0 ? 5 : 3);
        List<Field> out = new ArrayList<>();
        Field flagByte = null;
        for (int i = 0; i < n; i++) {
            if (flagByte != null && random.nextInt(3) == 0) {
                out.add(flagByte.bit(leaf(random)));
            } else {
                Field field = field(random, depth);
                if (field.kind == Field.Kind.FLAG_BYTE) {
                    flagByte = field;
                }
                out.add(field);
            }
        }
        return out;
    }

    private static Field leaf(Random random) {
        return switch (random.nextInt(5)) {
            case 0 -> Packbin.boolField(0, Access.get("b"), Access.set("b"));
            case 1 -> empty(0);
            case 2 -> Packbin.bytes(0, Access.get("p"), Access.set("p"), 2);
            case 3 -> Packbin.utf8(0, Access.get("s"), Access.set("s"));
            default -> u8(0);
        };
    }

    private static Field[] children(Random random, int depth) {
        return list(random, depth - 1).toArray(new Field[0]);
    }

    private static Field field(Random random, int depth) {
        int pick = random.nextInt(depth > 0 ? 16 : 6);
        Supplier<Field> element = () -> {
            Field f = field(random, depth - 1);
            return f.kind == Field.Kind.REPEAT || f.kind == Field.Kind.FLAG_BIT ? u8(0) : f;
        };
        return switch (pick) {
            case 0 -> u8(0);
            case 1 -> Packbin.boolField(0, Access.get("b"), Access.set("b"));
            case 2 -> empty(0);
            case 3 -> Packbin.bytes(0, Access.get("p"), Access.set("p"), 2);
            case 4 -> Packbin.flagByte();
            case 5 -> Packbin.utf8(0, Access.get("s"), Access.set("s"));
            case 6, 7, 8 -> Packbin.when(0, Packbin.eq(0, 1), children(random, depth));
            case 9 -> Packbin.group(0, children(random, depth));
            case 10 -> Packbin.group(Access.get("g"), Access.set("g"), children(random, depth));
            case 11 -> Packbin.flags(0, leafs(random));
            case 12, 13 -> Packbin.repeat(0, children(random, depth));
            case 14 -> Packbin.times(0, 0, children(random, depth));
            default -> random.nextBoolean()
                    ? Packbin.list(Access.get("l"), Access.set("l"), element.get())
                    : Packbin.dict(Access.get("d"), Access.set("d"), element.get());
        };
    }

    private static Field[] leafs(Random random) {
        Field[] out = new Field[random.nextInt(3)];
        for (int i = 0; i < out.length; i++) {
            out[i] = leaf(random);
        }
        return out;
    }

    /** The repeat-last walk as it was before AZ-4257, copied from SchemeOrder at HEAD (loop 120). */
    private static final class OldWalk {
        private OldWalk() {}

        static void check(List<Field> fields) {
            repeatLast(fields, null, null);
        }

        private static Field repeatLast(List<Field> fields, Field open, String inside) {
            for (Field field : fields) {
                open = repeatLast(field, open, inside);
            }
            return open;
        }

        private static Field repeatLast(Field field, Field open, String inside) {
            Field follower = open == null ? null : firstWriter(field);
            if (follower != null) {
                throw new IllegalArgumentException("repeat " + open.id + ": " + kindAndId(follower) + RepeatLastTest.FOLLOWS);
            }
            return switch (field.kind) {
                case REPEAT -> {
                    if (inside != null) {
                        throw new IllegalArgumentException("repeat " + field.id + inside);
                    }
                    repeatLast(field.children, null, RepeatLastTest.IN_ROUND);
                    yield open == null ? field : open;
                }
                case TIMES -> {
                    repeatLast(field.children, null, RepeatLastTest.IN_ROUND);
                    yield open;
                }
                case LIST, DICT -> {
                    repeatLast(field.children, null, RepeatLastTest.IN_ELEMENT);
                    yield open;
                }
                case WHEN, GROUP, FLAGS -> repeatLast(field.children, open, inside);
                case FLAG_BIT -> repeatLast(field.inner, open, inside);
                default -> open;
            };
        }

        private static Field firstWriter(Field field) {
            return switch (field.kind) {
                case BOOL -> null;
                case BYTES -> field.size > 0 ? field : null;
                case FLAG_BIT -> firstWriter(field.inner);
                case WHEN, GROUP -> firstWriter(field.children);
                case REPEAT, TIMES -> firstWriter(field.children) == null ? null : field;
                default -> field;
            };
        }

        private static Field firstWriter(List<Field> fields) {
            for (Field field : fields) {
                Field writer = firstWriter(field);
                if (writer != null) {
                    return writer;
                }
            }
            return null;
        }

        private static String kindAndId(Field field) {
            String kind = field.kind == Field.Kind.FLAG_BYTE ? "flagByte" : field.kind.name().toLowerCase(Locale.ROOT);
            return field.id >= 0 ? kind + " " + field.id : kind;
        }
    }
}
