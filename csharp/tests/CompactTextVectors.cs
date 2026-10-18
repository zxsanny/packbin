using System.Text;

namespace Packbin.Tests;

// AZ-2650: every string position is written and read with the compact text format (contract compact-text 1.0.0).
// The rows of fixtures/text/vectors.txt are the expected bytes; the reference is scripts/text/textfmt.py.
internal static class TextVectors
{
    internal sealed record Row(string Kind, string Id, string[] Args);

    private static readonly Lazy<List<Row>> Loaded = new(Load);

    internal static IReadOnlyList<Row> All => Loaded.Value;

    internal static IEnumerable<Row> Of(params string[] kinds) => All.Where(r => kinds.Contains(r.Kind));

    internal static Row Find(string id) => All.Single(r => r.Id == id);

    internal static IEnumerable<object[]> Ids(params string[] kinds) => Of(kinds).Select(r => new object[] { r.Id });

    // "-" is the empty text; otherwise the hex of its UTF-8 bytes.
    internal static string TextOf(string hex) => hex == "-" ? "" : Encoding.UTF8.GetString(Convert.FromHexString(hex));

    internal static string RepositoryFile(params string[] parts)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var path = Path.Combine([dir.FullName, .. parts]);
            if (File.Exists(path))
                return path;
            dir = dir.Parent;
        }
        throw new FileNotFoundException(string.Join('/', parts));
    }

    private static List<Row> Load()
    {
        var rows = new List<Row>();
        foreach (var line in File.ReadAllLines(RepositoryFile("fixtures", "text", "vectors.txt")))
        {
            if (line.Length == 0 || line[0] == '#')
                continue;
            var parts = line.Split(' ');
            rows.Add(new Row(parts[0], parts[1], parts[2..]));
        }
        return rows;
    }
}
