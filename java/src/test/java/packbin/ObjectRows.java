package packbin;

final class PositionRow {
    public byte type;
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

final class Session {
    public int login;
    public long ts;
}

final class SessionRow {
    public Session session;
}
