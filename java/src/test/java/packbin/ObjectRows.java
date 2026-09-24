package packbin;

final class PositionRow {
    public int sid;
    public int lat;
    public int lon;
    public byte profile;
    public Integer heading;
    public Integer speed;
    public Integer altitude;
}

final class WideRow {
    public Integer b5;
}

final class SessionRow {
    public Integer login;
    public Long ts;
}

final class MapRow {}
