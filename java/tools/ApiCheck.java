import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.util.List;
import java.util.Set;
import org.codehaus.mojo.animal_sniffer.SignatureChecker;
import org.codehaus.mojo.animal_sniffer.logging.PrintWriterLogger;

public final class ApiCheck {
    private ApiCheck() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 3) {
            System.err.println("usage: ApiCheck <signature> <classes-dir> <source-dir>");
            System.exit(2);
        }
        try (InputStream signature = new FileInputStream(args[0])) {
            SignatureChecker checker = new SignatureChecker(
                    signature, Set.of("packbin.*"), new PrintWriterLogger(System.out));
            checker.setSourcePath(List.of(new File(args[2])));
            checker.process(new File(args[1]));
            if (checker.isSignatureBroken()) {
                System.err.println("api-check: main sources reference APIs above Android API 26");
                System.exit(1);
            }
        }
    }
}
