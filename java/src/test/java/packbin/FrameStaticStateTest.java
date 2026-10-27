package packbin;

import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;

/**
 * AZ-3255 AC-3: the frame classes keep no static state that changes after class load; each session and MAC key counts
 * its own MAC computations in an instance field.
 */
public final class FrameStaticStateTest {
    private static final Class<?>[] GUARDED = {FrameSession.class, MacKey.class, FrameCrypto.class, FrameDirection.class,
        FrameSlot.class, FrameSealed.class, FrameOpened.class, Freshness.class};

    private FrameStaticStateTest() {}

    public static void main(String[] args) {
        run();
        FrameSupport.finish("FrameStaticStateTest");
    }

    static void run() {
        noStaticFieldChangesAfterLoad();
    }

    /** The guarded classes and the classes nested in them (FrameSession's key holder among them). */
    private static List<Class<?>> guardedTypes() {
        List<Class<?>> types = new ArrayList<>();
        for (Class<?> type : GUARDED) {
            types.add(type);
            types.addAll(List.of(type.getDeclaredClasses()));
        }
        return types;
    }

    private static void noStaticFieldChangesAfterLoad() {
        // Arrange
        List<String> mutable = new ArrayList<>();

        // Act
        for (Class<?> type : guardedTypes()) {
            for (Field field : type.getDeclaredFields()) {
                int modifiers = field.getModifiers();
                boolean atomic = field.getType().getName().startsWith("java.util.concurrent.atomic.");
                if (Modifier.isStatic(modifiers) && (!Modifier.isFinal(modifiers) || atomic)) {
                    mutable.add(type.getName() + "." + field.getName());
                }
            }
        }

        // Assert
        PackbinTest.expectEq("static fields that are not final or hold an atomic counter", List.of(), mutable);
    }
}
