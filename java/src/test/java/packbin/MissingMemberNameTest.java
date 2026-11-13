package packbin;

import java.util.List;
import java.util.Map;

/**
 * AZ-4257 (hygiene entry missing-member-message-by-name-java-python, note 7 of the loop 116 probe): a required utf8
 * member with no value is refused naming the member, as TypeScript, Go and Swift do ({@code missing text}), where Java
 * said {@code 1: expected string}. Java accessors are lambdas: only a member whose setter is made by
 * {@code Access.set(String)} has a name; any other is named by its kind and id ({@code missing utf8 1}). A value of the
 * wrong type keeps {@code 1: expected string}.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class MissingMemberNameTest {
    private MissingMemberNameTest() {}

    static void run() {
        aNamedMemberWithNoValueIsNamed();
        aTypedMemberWithNoValueIsNamedByKindAndId();
        anElementRowMemberWithNoValueIsNamed();
        aWrongTypeKeepsItsMessage();
        aShortListInARoundKeepsItsMessage();
    }

    public static final class Comment {
        public String id;
        public String text;
    }

    public static final class Top {
        public List<Comment> items;
    }

    private static Scheme<Map> mapScheme() {
        return Maps.scheme(1, Packbin.utf8(0, Access.get("id"), Access.set("id")),
                Packbin.utf8(1, Access.get("text"), Access.set("text")));
    }

    private static void aNamedMemberWithNoValueIsNamed() {
        // Arrange
        Scheme<Map> scheme = mapScheme();

        // Act and Assert
        PackbinTest.expectThrows("AZ-4257 AC-1 a null value", () -> BinaryPacker.pack(scheme, Maps.map("id", "a", "text", null)),
                "missing text");
        PackbinTest.expectThrows("AZ-4257 AC-1 an absent key", () -> BinaryPacker.pack(scheme, Maps.map("id", "a")),
                "missing text");
    }

    private static Field typedMember(int id, boolean text) {
        return text
                ? Packbin.utf8(id, Access.get((Comment c) -> c.text), Access.set((Comment c, Object v) -> c.text = (String) v))
                : Packbin.utf8(id, Access.get((Comment c) -> c.id), Access.set((Comment c, Object v) -> c.id = (String) v));
    }

    private static void aTypedMemberWithNoValueIsNamedByKindAndId() {
        // Arrange
        Scheme<Comment> scheme = new Scheme<>(1, Comment.class, typedMember(0, false), typedMember(1, true));
        Comment row = new Comment();
        row.id = "a";

        // Act and Assert
        PackbinTest.expectThrows("AZ-4257 AC-1 a typed row", () -> BinaryPacker.pack(scheme, row), "missing utf8 1");
    }

    private static void anElementRowMemberWithNoValueIsNamed() {
        // Arrange: the same element row as typed members, and as Map members.
        Scheme<Top> typed = new Scheme<>(1, Top.class, Packbin.list(Access.get((Top t) -> t.items),
                Access.set((Top t, Object v) -> t.items = (List<Comment>) v),
                Packbin.group(Access.identity(), Access.ignore(), Comment::new, typedMember(0, false), typedMember(1, true))));
        Scheme<Map> keyed = Maps.scheme(1, Packbin.list(Access.get("items"), Access.set("items"),
                Packbin.group(Access.identity(), Access.ignore(), Packbin.utf8(0, Access.get("id"), Access.set("id")),
                        Packbin.utf8(1, Access.get("text"), Access.set("text")))));
        Comment noText = new Comment();
        noText.id = "c1";
        Top top = new Top();
        top.items = List.of(noText);

        // Act and Assert
        PackbinTest.expectThrows("AZ-4257 AC-1 element row, typed members", () -> BinaryPacker.pack(typed, top),
                "missing utf8 1");
        PackbinTest.expectThrows("AZ-4257 AC-1 element row, named members",
                () -> BinaryPacker.pack(keyed, Maps.map("items", List.of(Maps.map("id", "c1")))), "missing text");
    }

    private static void aWrongTypeKeepsItsMessage() {
        // Arrange
        Scheme<Map> scheme = mapScheme();

        // Act and Assert
        PackbinTest.expectThrows("AZ-4257 AC-2 an int for text", () -> BinaryPacker.pack(scheme, Maps.map("id", "a", "text", 5)),
                "1: expected string");
    }

    /** A round's list that is shorter than its rounds is not a missing member: its text stays as it was. */
    private static void aShortListInARoundKeepsItsMessage() {
        // Arrange
        Scheme<Map> scheme = Maps.scheme(1, Packbin.u8(0, Access.get("n"), Access.set("n")),
                Packbin.times(1, 0, Packbin.utf8(1, Access.get("s"), Access.set("s"))));

        // Act and Assert
        PackbinTest.expectThrows("AZ-4257 AC-2 a short list in a times round",
                () -> BinaryPacker.pack(scheme, Maps.map("n", 2, "s", List.of("a"))), "1: expected string");
    }
}
