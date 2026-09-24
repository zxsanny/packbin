package packbin;

public final class Scheme<T> {
    final Packbin.Packet packet;
    final Class<T> type;

    private Scheme(Class<T> type, Packbin.Packet packet) {
        this.type = type;
        this.packet = packet;
    }

    @SafeVarargs
    public static <T> Scheme<T> of(Class<T> type, Field... fields) {
        return new Scheme<>(type, Packbin.packet(fields));
    }
}
