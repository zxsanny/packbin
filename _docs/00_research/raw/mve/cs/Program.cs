using System.Buffers.Binary;
using System.Diagnostics;

string expected = "4001000065cd1d00a3e1110100";
var bytes = new byte[13];
WritePosition(bytes);
var hex = Convert.ToHexString(bytes).ToLowerInvariant();
if (hex != expected)
{
    Console.Error.WriteLine("pack mismatch " + hex);
    return 1;
}

if (bytes[0] != 0x40
    || BinaryPrimitives.ReadUInt16LittleEndian(bytes.AsSpan(1)) != 1
    || BinaryPrimitives.ReadInt32LittleEndian(bytes.AsSpan(3)) != 500_000_000
    || BinaryPrimitives.ReadInt32LittleEndian(bytes.AsSpan(7)) != 300_000_000
    || bytes[11] != 1
    || bytes[12] != 0)
{
    Console.Error.WriteLine("unpack mismatch");
    return 1;
}

var clear = PackOptional(false, 0);
var set = PackOptional(true, 0x1234);
if (clear.Length != 2 || set.Length != 4)
{
    Console.Error.WriteLine("flags width");
    return 1;
}

if (UnpackOptional(new byte[] { 0x40, 0x01, 0x34 }))
{
    Console.Error.WriteLine("short packet returned a value");
    return 1;
}

static byte[] PackWhen(byte profile, byte shape) =>
    profile == 0 ? new byte[] { profile, shape } : new byte[] { profile };

if (PackWhen(1, 9).Length != 1 || PackWhen(0, 9).Length != 2)
{
    Console.Error.WriteLine("when width");
    return 1;
}

static bool UnpackRepeat(ReadOnlySpan<byte> data) => data.Length % 2 == 0;

if (!UnpackRepeat(new byte[] { 1, 2, 3, 4 }) || UnpackRepeat(new byte[] { 1, 2, 3 }))
{
    Console.Error.WriteLine("repeat");
    return 1;
}

var watch = Stopwatch.StartNew();
for (var i = 0; i < 100_000; i++)
{
    WritePosition(bytes);
    _ = bytes[0];
    _ = BinaryPrimitives.ReadUInt16LittleEndian(bytes.AsSpan(1));
    _ = BinaryPrimitives.ReadInt32LittleEndian(bytes.AsSpan(3));
    _ = BinaryPrimitives.ReadInt32LittleEndian(bytes.AsSpan(7));
    _ = bytes[11];
    _ = bytes[12];
}
watch.Stop();
if (watch.Elapsed.TotalSeconds > 1)
{
    Console.Error.WriteLine("speed " + watch.Elapsed.TotalMilliseconds);
    return 1;
}

Console.WriteLine(hex);
Console.WriteLine("elapsed_ms " + watch.Elapsed.TotalMilliseconds.ToString("0.0"));
return 0;

static void WritePosition(byte[] bytes)
{
    bytes[0] = 0x40;
    BinaryPrimitives.WriteUInt16LittleEndian(bytes.AsSpan(1), 1);
    BinaryPrimitives.WriteInt32LittleEndian(bytes.AsSpan(3), 500_000_000);
    BinaryPrimitives.WriteInt32LittleEndian(bytes.AsSpan(7), 300_000_000);
    bytes[11] = 1;
    bytes[12] = 0;
}

static byte[] PackOptional(bool bitSet, ushort value)
{
    var outBytes = new byte[bitSet ? 4 : 2];
    outBytes[0] = 0x40;
    outBytes[1] = bitSet ? (byte)0x01 : (byte)0x00;
    if (bitSet)
        BinaryPrimitives.WriteUInt16LittleEndian(outBytes.AsSpan(2), value);
    return outBytes;
}

static bool UnpackOptional(ReadOnlySpan<byte> bytes)
{
    if (bytes.Length < 2)
        return false;
    if ((bytes[1] & 0x01) == 0)
        return bytes.Length == 2;
    return bytes.Length >= 4;
}
