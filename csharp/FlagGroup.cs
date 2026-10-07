namespace Packbin;

// The bits of one flag byte. A FlagByte() handle is a FlagGroup that holds no bit: it only names the byte, so many
// schemes can share it. Each scheme gets a FlagGroup of its own for every read of the byte (FlagScopes.Bind), and that
// group holds the bits placed after the read, numbered by their order there. `Flags(...)` owns one group for its members.
internal sealed class FlagGroup
{
    private const int MaxBits = 8;

    public string Name { get; }
    public List<Field> BitInners { get; } = [];

    public FlagGroup(string name) => Name = name;

    public Field AddBit(Field inner) => Field.CreateFlagBit(this, Reserve(inner), inner);

    // The next bit number of this read. `inner` may still be replaced by its bound copy (Place).
    public int Reserve(Field inner)
    {
        var index = BitInners.Count;
        if (index == MaxBits)
            throw new ArgumentException($"flag bit '{inner.Name}': one flags byte holds at most {MaxBits} bits");
        BitInners.Add(inner);
        return index;
    }

    public void Place(int index, Field inner) => BitInners[index] = inner;

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
