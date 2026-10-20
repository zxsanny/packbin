using System.Text;
using Packbin;

namespace Packbin.Tests;

public partial class CompactTextTests
{
    private const int HostilePayloadCount = 30_000;

    private static readonly byte[] InterestingBytes =
        [0x00, 0x01, 0x10, 0x1f, 0x7f, 0x80, 0x81, 0xbf, 0xc0, 0xc2, 0xe0, 0xed, 0xef, 0xf0, 0xf4, 0xf5, 0xff];

    private sealed class HostileTally
    {
        public int Accepted;
        public int Refused;
        public double MostBytesPerPayloadByte;
        public readonly List<string> Violations = [];
    }

    private static byte[] FieldOf(byte[] payload)
    {
        var field = new List<byte>();
        for (var n = payload.Length; ; n >>= 7)
        {
            field.Add((byte)((n & 0x7f) | (n > 0x7f ? 0x80 : 0)));
            if (n <= 0x7f)
                break;
        }
        field.AddRange(payload);
        return [.. field];
    }

    // The header length of a field as the decoder reads it: up to three bytes while the high bit is set.
    private static int HeaderLength(byte[] field)
    {
        var length = 1;
        while (length < 3 && length < field.Length && (field[length - 1] & 0x80) != 0)
            length++;
        return Math.Min(length, field.Length);
    }

    // The packets of fixtures/hostile/fuzz/corpus.txt without their type byte.
    private static List<byte[]> CorpusBodies()
    {
        var bodies = new List<byte[]>();
        foreach (var line in File.ReadAllLines(TextVectors.RepositoryFile("fixtures", "hostile", "fuzz", "corpus.txt")))
        {
            if (line.Length == 0 || line[0] == '#')
                continue;
            var packet = Convert.FromHexString(line.Split(' ', StringSplitOptions.RemoveEmptyEntries)[2]);
            if (packet.Length > 1)
                bodies.Add(packet[1..]);
        }
        return bodies;
    }

    private static byte[] Damage(Random rng, byte[] field)
    {
        var header = HeaderLength(field);
        var head = field[..header].ToList();
        var body = field[header..].ToList();
        for (var steps = 1 + rng.Next(3); steps > 0; steps--)
        {
            var target = body.Count == 0 || rng.Next(8) == 0 ? head : body;
            if (target.Count == 0)
            {
                target.Add((byte)rng.Next(256));
                continue;
            }
            var at = rng.Next(target.Count);
            switch (rng.Next(7))
            {
                case 0:
                    target[at] ^= (byte)(1 << rng.Next(8));
                    break;
                case 1:
                    target[at] = rng.Next(2) == 0 ? InterestingBytes[rng.Next(InterestingBytes.Length)] : (byte)rng.Next(256);
                    break;
                case 2:
                    target.RemoveRange(at, target.Count - at);
                    break;
                case 3:
                    target.Insert(at, (byte)rng.Next(256));
                    break;
                case 4:
                    target.RemoveAt(at);
                    break;
                case 5:
                    target.AddRange(Enumerable.Range(0, 1 + rng.Next(8)).Select(_ => (byte)rng.Next(256)));
                    break;
                default:
                    target[at] = target[rng.Next(target.Count)];
                    break;
            }
        }
        // The count is left as damaged, made right for the damaged payload, or replaced by a random one.
        return rng.Next(3) switch
        {
            0 => [.. head, .. body],
            1 => body.Count == 0 ? [0] : FieldOf([.. body]),
            _ => [(byte)rng.Next(256), .. body],
        };
    }

    // One payload of the loop: the category follows the index, so every category gets about 5,000 of the 30,000.
    private static byte[] HostileField(Random rng, int index, List<byte[]> valid, List<byte[]> vectors, List<byte[]> corpus)
    {
        if (index % 3_000 == 7)
        {
            // The longest run of zeros or ones in every start mode: the amplification case of the decoder.
            var run = new byte[40_000];
            Array.Fill(run, index / 3_000 % 2 == 0 ? (byte)0x00 : (byte)0xff);
            run[0] = (byte)((index / 3_000 % 8) << 2);
            return FieldOf(run);
        }
        switch (index % 6)
        {
            case 0:
            {
                var payload = new byte[1 + rng.Next(80)];
                rng.NextBytes(payload);
                payload[0] = (byte)((payload[0] & (rng.Next(2) == 0 ? 0x03 : 0xe3)) | (index / 6 % 8 << 2));
                return FieldOf(payload);
            }
            case 1:
            {
                var bytes = new byte[rng.Next(97)];
                rng.NextBytes(bytes);
                return bytes;
            }
            case 2:
                return Damage(rng, valid[rng.Next(valid.Count)]);
            case 3:
                return Damage(rng, vectors[rng.Next(vectors.Count)]);
            case 4:
                return Damage(rng, corpus[rng.Next(corpus.Count)]);
            default:
            {
                var payload = new byte[100 + rng.Next(2_901)];
                rng.NextBytes(payload);
                payload[0] = (byte)((payload[0] & 0x03) | (index / 6 % 8 << 2));
                return FieldOf(payload);
            }
        }
    }

    private static bool HasLoneSurrogate(string text)
    {
        for (var i = 0; i < text.Length; i++)
        {
            if (char.IsHighSurrogate(text[i]) && i + 1 < text.Length && char.IsLowSurrogate(text[i + 1]))
                i++;
            else if (char.IsSurrogate(text[i]))
                return true;
        }
        return false;
    }

    // Unpacks one field directly and as the only field of a packet and records what breaks a rule.
    private static void ExamineHostile(byte[] field, Func<NameRow?> unpackPacket, HostileTally tally)
    {
        string text;
        int offset = 0;
        ShortPacket? direct;
        NameRow? row;
        try
        {
            direct = TextDecoder.Read("Name", field, ref offset, out text);
            row = unpackPacket();
        }
        catch (Exception ex)
        {
            tally.Violations.Add($"{ex.GetType().Name} on {ShowField(field)}");
            return;
        }
        var accepted = direct is null && offset == field.Length;
        if (accepted != (row is not null))
        {
            tally.Violations.Add($"direct read {(accepted ? "accepts" : "refuses")} but the packet {(row is not null ? "unpacks" : "is refused")}: {ShowField(field)}");
            return;
        }
        if (row is null)
        {
            tally.Refused++;
            return;
        }
        tally.Accepted++;
        var payload = offset - HeaderLength(field);
        var bytes = Encoding.UTF8.GetByteCount(row.Name);
        if (row.Name != text || bytes > 6 * payload + 8 || bytes > 65_535 || HasLoneSurrogate(row.Name))
            tally.Violations.Add($"accepted {bytes} UTF-8 bytes from a {payload}-byte payload (equal {row.Name == text}): {ShowField(field)}");
        if (payload > 0)
            tally.MostBytesPerPayloadByte = Math.Max(tally.MostBytesPerPayloadByte, (double)bytes / payload);
    }

    private static string ShowField(byte[] field) =>
        Convert.ToHexString(field.AsSpan(0, Math.Min(field.Length, 48))) + (field.Length > 48 ? $"... ({field.Length} bytes)" : "");

    // AZ-2736 (CS-A10, TW-3): the hostile-payload test C# did not have.
    [Fact]
    public void Ac3_HostileTextPayloads_30000RandomAndDamaged_NeverCrashHangOrExceedSixBytesPerByteAndEight()
    {
        // Arrange
        var rng = new Random(2737);
        var valid = Enumerable.Range(0, 400).Select(_ => PackName(RandomText(rng, 120))[1..]).ToList();
        var vectors = TextVectors.Of("enc", "alt", "bad").Select(r => Convert.FromHexString(r.Args[1])).ToList();
        var corpus = CorpusBodies();
        var tally = new HostileTally();
        var guard = Timing.Bound(20.0);

        // Act
        RunGuarded(() =>
        {
            NameRow? got = null;
            var handler = Single.On(row => got = row);
            for (var i = 0; i < HostilePayloadCount; i++)
            {
                var field = HostileField(rng, i, valid, vectors, corpus);
                ExamineHostile(field, () =>
                {
                    got = null;
                    var error = BinaryPacker.Unpack([1, .. field], handler);
                    return error is null ? got : null;
                }, tally);
            }
        }, guard, "30000 hostile payloads");

        // Assert
        output.WriteLine($"AZ-2736 AC-3: {HostilePayloadCount} payloads, {tally.Accepted} accepted, {tally.Refused} refused, {corpus.Count} corpus seeds, most output bytes per payload byte {tally.MostBytesPerPayloadByte:F2}");
        Assert.Empty(tally.Violations.Take(5));
        Assert.Equal(HostilePayloadCount, tally.Accepted + tally.Refused + tally.Violations.Count);
        Assert.True(tally.Accepted >= 1_000, $"only {tally.Accepted} payloads were accepted");
        Assert.True(tally.Refused >= 1_000, $"only {tally.Refused} payloads were refused");
        Assert.True(corpus.Count >= 30, $"only {corpus.Count} corpus seeds");
    }
}
