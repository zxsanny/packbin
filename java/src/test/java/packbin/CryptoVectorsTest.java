package packbin;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * AZ-3233 AC-2 and AC-3: the SHA-256, HMAC-SHA256, HKDF-SHA256, ChaCha20 block and ChaCha20 cipher rows of
 * fixtures/crypto/vectors.txt through the primitives the package uses (the platform digest under HMAC, the HMAC and HKDF
 * of {@code SessionPad}/{@code FrameCrypto}, and the ChaCha20 block and cipher of {@code SessionPad}), and the loader on a
 * copy with one expected byte changed.
 */
public final class CryptoVectorsTest {
    private static final int ROWS = 27;

    private CryptoVectorsTest() {}

    public static void main(String[] args) throws IOException {
        run();
        FrameSupport.finish("CryptoVectorsTest");
    }

    static void run() throws IOException {
        everyRowMatches();
        loaderFailsOnACorruptedCopyOfEachPrimitive();
    }

    private static void everyRowMatches() throws IOException {
        // Arrange
        List<String> lines = Files.readAllLines(FrameSupport.fixture("crypto/vectors.txt"));

        // Act
        List<String> mismatches = new ArrayList<>();
        int checked = check(lines, mismatches);

        // Assert
        PackbinTest.expectTrue("crypto vectors: mismatches " + mismatches, mismatches.isEmpty());
        PackbinTest.expectEq("crypto vectors: rows checked", ROWS, checked);
    }

    private static void loaderFailsOnACorruptedCopyOfEachPrimitive() throws IOException {
        List<String> original = Files.readAllLines(FrameSupport.fixture("crypto/vectors.txt"));
        String[][] targets = {
            {"sha256", "digest"}, {"hmac256", "mac"}, {"hkdf256", "okm"}, {"chacha-block", "block"}, {"chacha-xor", "cipher"}};
        for (String[] target : targets) {
            // Arrange
            List<String> copy = new ArrayList<>(original);
            String id = corruptFirst(copy, target[0], target[1]);
            Path temp = Files.createTempFile("crypto-vectors", ".txt");
            try {
                Files.write(temp, copy);

                // Act
                List<String> mismatches = new ArrayList<>();
                check(Files.readAllLines(temp), mismatches);

                // Assert
                PackbinTest.expectTrue("corrupted " + id + " is reported by name: " + mismatches,
                        mismatches.size() == 1 && mismatches.get(0).startsWith(id + " "));
            } finally {
                Files.deleteIfExists(temp);
            }
        }
    }

    private static String corruptFirst(List<String> lines, String primitive, String field) {
        for (int i = 0; i < lines.size(); i++) {
            String line = lines.get(i);
            int at = line.indexOf(" " + field + "=");
            if (!line.startsWith(primitive + " ") || at < 0) {
                continue;
            }
            int end = line.indexOf(' ', at + 1);
            end = end < 0 ? line.length() : end;
            char last = line.charAt(end - 1);
            lines.set(i, line.substring(0, end - 1) + (last == '0' ? '1' : '0') + line.substring(end));
            String[] tokens = line.split(" ");
            return tokens[0] + " " + tokens[1];
        }
        throw new IllegalStateException("no " + primitive + " row");
    }

    /** Runs every row; appends "primitive source: ..." per mismatch; returns the number of rows run. */
    static int check(List<String> lines, List<String> mismatches) {
        int checked = 0;
        for (Map<String, String> row : FrameSupport.parseRows(lines)) {
            String id = row.get("#0") + " " + row.get("#1");
            try {
                String problem = run(row);
                if (problem != null) {
                    mismatches.add(id + " " + problem);
                }
            } catch (RuntimeException | NoSuchAlgorithmException ex) {
                mismatches.add(id + " exception: " + ex);
            }
            checked++;
        }
        return checked;
    }

    private static String run(Map<String, String> row) throws NoSuchAlgorithmException {
        switch (row.get("#0")) {
            case "sha256": return sha256(row);
            case "hmac256": return hmac(row);
            case "hkdf256": return hkdf(row);
            case "chacha-block": return block(row);
            case "chacha-xor": return cipher(row);
            default: return "unknown primitive";
        }
    }

    private static String compare(String what, byte[] expected, byte[] got) {
        return Arrays.equals(expected, got) ? null
                : what + ": expected " + FrameSupport.unhex(expected) + ", got " + FrameSupport.unhex(got);
    }

    private static String sha256(Map<String, String> row) throws NoSuchAlgorithmException {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        if (row.containsKey("repeat")) {
            byte[] chunk = new byte[1000];
            Arrays.fill(chunk, FrameSupport.hex(row.get("byte"))[0]);
            int left = Integer.parseInt(row.get("repeat"));
            while (left > 0) {
                int n = Math.min(left, chunk.length);
                digest.update(chunk, 0, n);
                left -= n;
            }
        } else {
            digest.update(FrameSupport.hex(row.get("msg")));
        }
        return compare("digest", FrameSupport.hex(row.get("digest")), digest.digest());
    }

    private static String hmac(Map<String, String> row) {
        byte[] full = FrameCrypto.mac(FrameSupport.hex(row.get("key"))).doFinal(FrameSupport.hex(row.get("data")));
        byte[] expected = FrameSupport.hex(row.get("mac"));
        int n = row.containsKey("truncate") ? Integer.parseInt(row.get("truncate")) : full.length;
        return compare("mac", expected, Arrays.copyOf(full, n));
    }

    private static String hkdf(Map<String, String> row) {
        byte[] ikm = FrameSupport.hex(row.get("ikm"));
        byte[] salt = FrameSupport.hex(row.get("salt"));
        byte[] info = FrameSupport.hex(row.get("info"));
        int len = Integer.parseInt(row.get("len"));
        byte[] prk = SessionPad.hkdfExtract(salt, ikm);
        String problem = compare("prk", FrameSupport.hex(row.get("prk")), prk);
        if (problem != null) {
            return problem;
        }
        problem = compare("okm", FrameSupport.hex(row.get("okm")), SessionPad.hkdfExpand(prk, info, len));
        return problem != null ? problem : compare("okm one call", FrameSupport.hex(row.get("okm")),
                SessionPad.hkdfSha256(ikm, salt, info, len));
    }

    private static String block(Map<String, String> row) {
        byte[] out = new byte[64];
        SessionPad.block(FrameSupport.hex(row.get("key")), FrameSupport.hex(row.get("nonce")),
                Integer.parseInt(row.get("counter")), out);
        return compare("block", FrameSupport.hex(row.get("block")), out);
    }

    private static String cipher(Map<String, String> row) {
        byte[] key = FrameSupport.hex(row.get("key"));
        byte[] nonce = FrameSupport.hex(row.get("nonce"));
        int counter = Integer.parseInt(row.get("counter"));
        byte[] plain = FrameSupport.hex(row.get("plain"));
        byte[] expected = FrameSupport.hex(row.get("cipher"));
        byte[] whole = plain.clone();
        SessionPad.xor(key, nonce, counter, whole);
        String problem = compare("cipher", expected, whole);
        if (problem != null) {
            return problem;
        }
        byte[] framed = new byte[plain.length + 7];
        System.arraycopy(plain, 0, framed, 3, plain.length);
        SessionPad.xor(key, nonce, counter, framed, 3, plain.length);
        return compare("cipher in a range", expected, Arrays.copyOfRange(framed, 3, 3 + plain.length));
    }
}
