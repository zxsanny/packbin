import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import packbin.BinaryPacker;
import packbin.Packbin;
import packbin.Scheme;

/**
 * The message ECC commands of {@link Handoff} (AZ-2689; contract message-ecc.md).
 *
 * <pre>
 *   ecc-protect &lt;n&gt; &lt;clear hex&gt;   prints the clear position message packed again with n parity bytes, or the error kind
 *   ecc-repair &lt;n&gt; &lt;t&gt; &lt;hex&gt;      prints the position message repaired (hex, then the repaired count), or the error kind
 *   ecc-batch &lt;file&gt;              one line per line of the file: `protect &lt;n&gt; &lt;hex&gt;` or `repair &lt;n&gt; &lt;t&gt; &lt;hex&gt;`
 * </pre>
 *
 * "-" is the empty buffer. The kind names are the ones of fixtures/ecc/vectors.txt (uncorrectable, short, too_long,
 * bad_parity, bad_limit) plus trailing, type_mismatch and unpack_failed for the walk of the unprotected fields.
 */
final class HandoffEcc {
    private HandoffEcc() {
    }

    private static byte[] bytesOf(String token) {
        return token.equals("-") ? new byte[0] : Handoff.parse(token);
    }

    private static String kindOf(Object error) {
        if (error instanceof Packbin.Uncorrectable) {
            return "uncorrectable";
        }
        if (error instanceof Packbin.TooLong) {
            return "too_long";
        }
        if (error instanceof Packbin.ShortPacket s) {
            return s.field.equals("parity") ? "short" : "unpack_failed";
        }
        if (error instanceof Packbin.TrailingBytes) {
            return "trailing";
        }
        return error instanceof Packbin.TypeMismatch ? "type_mismatch" : "unpack_failed";
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static String protect(Scheme<Map> position, int n, byte[] clear) {
        Map[] row = new Map[1];
        if (BinaryPacker.unpack(clear, position.on(r -> row[0] = r)) != null || row[0] == null) {
            return "unpack_failed";
        }
        Scheme<Map> protectedScheme;
        try {
            protectedScheme = position.withParity(n);
        } catch (IllegalArgumentException e) {
            return "bad_parity";
        }
        return Handoff.hex(BinaryPacker.pack(protectedScheme, row[0]));
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static String repair(Scheme<Map> position, int n, int t, byte[] received) {
        Scheme<Map> protectedScheme;
        try {
            protectedScheme = position.withParity(n);
        } catch (IllegalArgumentException e) {
            return "bad_parity";
        }
        Map[] row = new Map[1];
        Object result;
        try {
            result = BinaryPacker.unpackRepair(received, t, protectedScheme.on(r -> row[0] = r));
        } catch (IllegalArgumentException e) {
            return "bad_limit";
        }
        if (!(result instanceof Packbin.Repaired fixed) || row[0] == null) {
            return kindOf(result);
        }
        return Handoff.hex(BinaryPacker.pack(position, row[0])) + " " + fixed.count;
    }

    private static String line(Scheme<Map> position, String[] words) {
        if (words.length == 3 && words[0].equals("protect")) {
            return protect(position, Integer.parseInt(words[1]), bytesOf(words[2]));
        }
        if (words.length == 4 && words[0].equals("repair")) {
            return repair(position, Integer.parseInt(words[1]), Integer.parseInt(words[2]), bytesOf(words[3]));
        }
        throw new IllegalArgumentException("ecc line: " + String.join(" ", words));
    }

    /** Runs an ecc command; returns the exit status. {@code position} is the unprotected position scheme of Handoff. */
    @SuppressWarnings("rawtypes")
    static int run(String cmd, String[] args, Scheme<Map> position) {
        if (cmd.equals("ecc-protect") && args.length == 3) {
            System.out.println(line(position, new String[] {"protect", args[1], args[2]}));
            return 0;
        }
        if (cmd.equals("ecc-repair") && args.length == 4) {
            System.out.println(line(position, new String[] {"repair", args[1], args[2], args[3]}));
            return 0;
        }
        if (cmd.equals("ecc-batch") && args.length == 2) {
            try {
                for (String text : Files.readAllLines(Path.of(args[1]), StandardCharsets.UTF_8)) {
                    if (!text.isBlank()) {
                        System.out.println(line(position, text.trim().split("\\s+")));
                    }
                }
            } catch (IOException e) {
                System.err.println("ecc-batch: " + e);
                return 1;
            }
            return 0;
        }
        return 2;
    }
}
