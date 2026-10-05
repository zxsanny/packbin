namespace Packbin;

internal sealed class FlagGroup
{
    private const int MaxBits = 8;

    public string Name { get; }
    public List<Field> BitInners { get; } = [];

    public FlagGroup(string name) => Name = name;

    public Field AddBit(Field inner)
    {
        var index = BitInners.Count;
        if (index == MaxBits)
            throw new ArgumentException($"flag bit '{inner.Name}': one flags byte holds at most {MaxBits} bits");
        BitInners.Add(inner);
        return Field.CreateFlagBit(this, index, inner);
    }

    public byte Compute(IReadOnlyDictionary<string, object?> values)
    {
        byte flags = 0;
        for (var i = 0; i < BitInners.Count; i++)
        {
            if (Walker.BitOn(values, BitInners[i]))
                flags |= (byte)(1 << i);
        }
        return flags;
    }
}
