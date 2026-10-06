namespace Packbin;

// State owned by one call: the values read (unpack) or written (pack) so far in one scope (the packet, or one
// repeat/times round, list element or dictionary value) and the flags bytes read there. A `when` is decided on these,
// so pack and unpack agree. FlagScopes guarantees a split flag bit finds its byte in the same scope, so nothing is
// looked up in an outer one.
internal sealed class Scope : Dictionary<string, object?>
{
    private readonly RoundBudget? _budget;
    private Dictionary<FlagGroup, byte>? _flagBytes;

    // Unpack passes the call's budget to every scope it opens (round, list element, dictionary value); pack has none.
    public Scope(RoundBudget? budget = null) => _budget = budget;

    public RoundBudget Budget => _budget ?? throw new InvalidOperationException("this scope has no round budget");

    public void SetFlagByte(FlagGroup group, byte flags) => (_flagBytes ??= [])[group] = flags;

    public byte FlagByte(FlagGroup group) =>
        _flagBytes is not null && _flagBytes.TryGetValue(group, out var flags) ? flags : (byte)0;
}

// What one unpack call may still spend on rounds: shared by every scope of the call, never static, so two calls in
// parallel do not share it. A round is admitted before its bytes are read.
internal sealed class RoundBudget(int maxRounds, long maxSlots)
{
    private long _slotsUsed;

    // `roundsStarted`: the rounds the same repeat or times field has already started in this walk.
    // `slots`: the entries the round adds to the row (one per name it can hold).
    public bool TryStartRound(long roundsStarted, int slots)
    {
        if (roundsStarted >= maxRounds || slots > maxSlots - _slotsUsed)
            return false;
        _slotsUsed += slots;
        return true;
    }
}
