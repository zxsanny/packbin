package packbin;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.InputStream;
import java.util.Arrays;
import java.util.concurrent.TimeUnit;

/**
 * AZ-2354 AC-1: {@code u32 n; times(n) { utf8 s }} with n = 65 535 and a 65 535 byte string that stays raw refuses to pack, naming
 * {@code s}, and keeps its memory near the budget: this class is the main of a child JVM whose heap holds well under
 * the 4.3 GB the packet used to need, so an unbounded buffer would end in an OutOfMemoryError there.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class LoneUtf8Budget {
    private LoneUtf8Budget() {}

    private static final int HEAP_MB = 96;

    public static void main(String[] args) {
        Scheme<java.util.Map> scheme = Maps.scheme(1, Packbin.u32(0, Access.get("n"), Access.set("n")),
                Packbin.times(1, 0, Packbin.utf8(1, Access.get("s"), Access.set("s"))));
        char[] text = new char[65_535];
        Arrays.fill(text, (char) 1);
        try {
            BinaryPacker.pack(scheme, Maps.map("n", 65_535, "s", new String(text)));
            System.out.println("packed");
        } catch (IllegalArgumentException ex) {
            System.out.println(ex.getMessage());
        }
    }

    /** Runs the child with a {@value #HEAP_MB} MB heap, stdin from /dev/null and 30 s to finish. */
    static void expectRefusedInASmallHeap(String expected) {
        String java = System.getProperty("java.home") + File.separator + "bin" + File.separator + "java";
        ProcessBuilder builder = new ProcessBuilder(java, "-Xmx" + HEAP_MB + "m", "-cp",
                System.getProperty("java.class.path"), "packbin.LoneUtf8Budget");
        builder.redirectErrorStream(true);
        builder.redirectInput(ProcessBuilder.Redirect.from(new File("/dev/null")));
        try {
            long start = System.nanoTime();
            Process child = builder.start();
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            InputStream in = child.getInputStream();
            byte[] chunk = new byte[4096];
            Thread drain = new Thread(() -> {
                try {
                    for (int n; (n = in.read(chunk)) > 0; ) {
                        out.write(chunk, 0, n);
                    }
                } catch (java.io.IOException ex) {
                    // The child ended; what it printed so far is what the test compares.
                }
            });
            drain.setDaemon(true);
            drain.start();
            boolean done = child.waitFor(30, TimeUnit.SECONDS);
            if (!done) {
                child.destroyForcibly();
            }
            drain.join(2000);
            long ms = (System.nanoTime() - start) / 1_000_000;
            PackbinTest.expectTrue("AC-1 child JVM finished (" + ms + " ms)", done);
            PackbinTest.expectEq("AC-1 child JVM with a " + HEAP_MB + " MB heap", expected + "\n",
                    out.toString("UTF-8").replace("\r\n", "\n"));
        } catch (java.io.IOException ex) {
            PackbinTest.fail("AC-1 child JVM did not start: " + ex);
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            PackbinTest.fail("AC-1 child JVM wait interrupted");
        }
    }
}
