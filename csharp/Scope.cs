namespace Packbin;

// Unpack state owned by one call: the values read so far in one scope (the packet, or one repeat/times round, list
// element or dictionary value) and the flags bytes read there. FlagScopes guarantees a split flag bit finds its byte
// in the same scope, so nothing is looked up in an outer one.
internal sealed class Scope : Dictionary<string, object?>
{
    private Dictionary<FlagGroup, byte>? _flagBytes;

    public void SetFlagByte(FlagGroup group, byte flags) => (_flagBytes ??= [])[group] = flags;

    public byte FlagByte(FlagGroup group) =>
        _flagBytes is not null && _flagBytes.TryGetValue(group, out var flags) ? flags : (byte)0;
}
