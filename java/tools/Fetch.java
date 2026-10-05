import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.HexFormat;

public final class Fetch {
    private Fetch() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 4 || (args.length - 1) % 3 != 0) {
            System.err.println("usage: Fetch <dir> (<url> <sha256> <name>)...");
            System.exit(2);
        }
        Path dir = Path.of(args[0]);
        Files.createDirectories(dir);
        HttpClient client = HttpClient.newHttpClient();
        for (int i = 1; i < args.length; i += 3) {
            Path file = dir.resolve(args[i + 2]);
            if (Files.exists(file) && sha256(Files.readAllBytes(file)).equals(args[i + 1])) {
                continue;
            }
            HttpResponse<byte[]> response = client.send(
                    HttpRequest.newBuilder(URI.create(args[i])).build(),
                    HttpResponse.BodyHandlers.ofByteArray());
            if (response.statusCode() != 200) {
                throw new IOException(args[i] + " returned HTTP " + response.statusCode());
            }
            String actual = sha256(response.body());
            if (!actual.equals(args[i + 1])) {
                throw new IOException(args[i] + " sha256 " + actual + " != pinned " + args[i + 1]);
            }
            Files.write(file, response.body());
        }
    }

    private static String sha256(byte[] bytes) throws Exception {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
    }
}
