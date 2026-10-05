namespace Packbin;

internal sealed class FlagGroup
{
    public string Name { get; }
    public List<Field> BitInners { get; } = [];

    public FlagGroup(string name) => Name = name;

    public Field AddBit(Field inner)
    {
        var index = BitInners.Count;
        BitInners.Add(inner);
        return Field.CreateFlagBit(this, index, inner);
    }

    public byte Compute(IReadOnlyDictionary<string, object?> values)
    {
        byte flags = 0;
        for (var i = 0; i < BitInners.Count; i++)
        {
            var inner = BitInners[i];
            var on = inner.Type == Field.Kind.Group
                ? Walker.GroupOn(values, inner)
                : Walker.IsPresent(values, inner.Name);
            if (on)
                flags |= (byte)(1 << i);
        }
        return flags;
    }
}
