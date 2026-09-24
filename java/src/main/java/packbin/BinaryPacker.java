package packbin;

public final class BinaryPacker {
    private BinaryPacker() {}

    public static <T> byte[] pack(Scheme<T> scheme, T row) {
        return Packbin.pack(scheme.packet, row);
    }

    public static <T> Packbin.Bound<T> unpack(Scheme<T> scheme, byte[] bytes) {
        return Packbin.unpack(scheme.packet, bytes, scheme.type);
    }
}
