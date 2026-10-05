namespace Packbin;

// Unpack state owned by one call: the values read so far in one scope (the packet, or one repeat/times round, list
// element or dictionary value) and the flags bytes read there. A flag bit finds its byte here or in an outer scope.
internal sealed class Scope : Dictionary<string, object?>
{
    private readonly Scope? _parent;
    private Dictionary<FlagGroup, byte>? _flagBytes;

    public Scope(Scope? parent = null) => _parent = parent;

    public void SetFlagByte(FlagGroup group, byte flags) => (_flagBytes ??= [])[group] = flags;

    public byte FlagByte(FlagGroup group)
    {
        for (var scope = this; scope is not null; scope = scope._parent)
        {
            if (scope._flagBytes is not null && scope._flagBytes.TryGetValue(group, out var flags))
                return flags;
        }
        return 0;
    }
}
