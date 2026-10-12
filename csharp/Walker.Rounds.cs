using System.Collections;

namespace Packbin;

// A repeat or times round is addressed by index. Pack reads each value list at the round's index and gives a value that
// is not a list to every round; unpack gives every value a round can hold one entry per round, null where the round
// skipped it, so a repack gives the same bytes.
internal static partial class Walker
{
    private static void PackRepeat(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        PackOut buffer,
        Scope seen)
    {
        if (RowsOf(field, values) is { } rows)
        {
            PackRowRepeat(field, rows, buffer, seen);
            return;
        }
        var names = RoundNames(field, packing: true);
        RequireRepeatWithinLimit(names, values, seen);
        RequireRoundCollections(field, values);
        RequireNoShortOptionalLists(field, values);
        PackRounds(field, RoundMember(field, names), RoundCount(names, values), i => SliceRound(names, values, i), buffer, seen);
    }

    private static void PackTimes(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        PackOut buffer,
        Scope seen)
    {
        var names = RoundNames(field, packing: true);
        var count = BorrowedCount(field, seen);
        var member = RoundMember(field, names);
        RequireRoundsWithinLimit(member, count, seen);
        if (RowsOf(field, values) is { } rows)
        {
            RequireRowCount(field, rows, count);
            PackRounds(field, member, count, i => rows[i], buffer, seen);
            return;
        }
        RequireRoundCollections(field, values);
        RequireNoExtraRounds(names, count, values);
        PackRounds(field, member, count, i => SliceRound(names, values, i), buffer, seen);
    }

    // The member a round's limit error names: the collection of a round bound to rows, else the first name it holds.
    private static string RoundMember(Field field, List<string> names) =>
        field.Binding is not null ? field.Name
        : names.Count > 0 ? names[0]
        : $"{(field.Type == Field.Kind.Times ? "times" : "repeat")} {field.Id}";

    // Unpack refuses a round above the scheme's `maxRounds`, so pack refuses a count above it before any round is
    // written: a lone scalar is given to every round, and a huge count would otherwise loop and fill the buffer.
    private static void RequireRoundsWithinLimit(string member, int count, Scope seen)
    {
        var limit = seen.Budget.MaxRounds;
        if (count > limit)
            throw new ArgumentException($"'{member}': the times count is {count}, above the limit of {limit} rounds");
    }

    // A repeat takes its rounds from the longest list, so pack refuses a list above the limit before any round is written,
    // naming the first member whose list passes it.
    private static void RequireRepeatWithinLimit(List<string> names, IReadOnlyDictionary<string, object?> values, Scope seen)
    {
        var limit = seen.Budget.MaxRounds;
        foreach (var name in names)
        {
            if (values.TryGetValue(name, out var v) && v is IList list && list.Count > limit)
                throw new ArgumentException($"'{name}': the repeat count is {list.Count}, above the limit of {limit} rounds");
        }
    }

    // A list longer than the count would have its last items dropped. A shorter one runs out in a round that walks
    // the field, and that pack refuses.
    private static void RequireNoExtraRounds(List<string> names, int count, IReadOnlyDictionary<string, object?> values)
    {
        foreach (var name in names)
        {
            if (values.TryGetValue(name, out var v) && v is IList list && list.Count > count)
                throw new ArgumentException($"'{name}' holds {list.Count} items, but the times count is {count}");
        }
    }

    // `roundValues(i)`: the values round i reads, a slice of the per-name lists or the row of a round bound to rows.
    private static void PackRounds(
        Field field,
        string member,
        int count,
        Func<int, IReadOnlyDictionary<string, object?>> roundValues,
        PackOut buffer,
        Scope outer)
    {
        var seen = outer.Fresh();
        var slots = SlotsPerRound(RoundNames(field, packing: false));
        for (var i = 0; i < count; i++)
        {
            RequireSlots(member, slots, seen);
            var slice = roundValues(i);
            seen.Clear();
            foreach (var child in field.Children)
                PackField(child, slice, buffer, seen);
        }
    }

    // A round is admitted before any of its bytes are written, as unpack admits it, so a packet pack writes is one the same
    // scheme unpacks.
    private static void RequireSlots(string member, int slots, Scope seen)
    {
        var budget = seen.Budget;
        if (budget.TryChargeSlots(slots))
            return;
        throw new ArgumentException(
            $"'{member}': the rounds would hold {budget.SlotsUsed + slots} slots, above the limit of {budget.MaxSlots} slots");
    }

    // The names a round can hold: its own fields and the ones under when, flags, flag bits and groups. A list or dict
    // element keeps values of its own, so it is not looked into. A repeat or times cannot be in a round (RoundScopes).
    // `packing`: a group's own member is read on pack (it can turn the group's flag bit on); unpack stores it only for
    // an empty group.
    private static List<string> RoundNames(Field round, bool packing)
    {
        var names = new List<string>();
        foreach (var child in round.Children)
            AddRoundNames(child, packing, names);
        return names;
    }

    // The entries a round adds to the row: one per distinct name, as AppendRound does.
    private static int SlotsPerRound(List<string> names) => names.Distinct().Count();

    private static void AddRoundNames(Field field, bool packing, List<string> names)
    {
        switch (field.Type)
        {
            case Field.Kind.FlagByte:
                break;
            case Field.Kind.When:
            case Field.Kind.Flags:
                foreach (var child in field.Children)
                    AddRoundNames(child, packing, names);
                break;
            case Field.Kind.FlagBit:
                AddRoundNames(field.Inner!, packing, names);
                break;
            case Field.Kind.Group:
                if (packing || field.Children.Length == 0)
                    names.Add(field.Name);
                foreach (var child in field.Children)
                    AddRoundNames(child, packing, names);
                break;
            case Field.Kind.U2:
                names.AddRange(field.Names);
                break;
            default:
                names.Add(field.Name);
                break;
        }
    }

    // A name that holds a byte run, a list or a dictionary per round (bytes, sized, bits, packed, dict) takes a list with
    // one of them per round. One byte run or list alone would be read as the list of rounds, and its items given to the rounds.
    private static void RequireRoundCollections(Field field, IReadOnlyDictionary<string, object?> values)
    {
        switch (field.Type)
        {
            case Field.Kind.Repeat:
            case Field.Kind.Times:
            case Field.Kind.When:
            case Field.Kind.Flags:
            case Field.Kind.Group:
                foreach (var child in field.Children)
                    RequireRoundCollections(child, values);
                break;
            case Field.Kind.FlagBit:
                RequireRoundCollections(field.Inner!, values);
                break;
            case Field.Kind.Dict:
                if (values.TryGetValue(field.Name, out var map) && map is IDictionary)
                    throw new ArgumentException(
                        $"'{field.Name}': a round's value belongs in a list with one entry per round; "
                        + "wrap this dictionary in a list");
                break;
            case Field.Kind.Bytes:
            case Field.Kind.Sized:
            case Field.Kind.Bits:
            case Field.Kind.Packed:
                if (values.TryGetValue(field.Name, out var v) && v is IList list && IsOneCollection(list))
                    throw new ArgumentException(
                        $"'{field.Name}': a round's value belongs in a list with one entry per round; "
                        + "wrap this value in a list");
                break;
        }
    }

    // A list of rounds holds one byte run or list per round (null for a round that skipped the field); a list of plain
    // items, or any byte[], is one round's value. An empty list cannot be told from no rounds.
    private static bool IsOneCollection(IList list)
    {
        foreach (var item in list)
        {
            if (item is not null)
                return item is not IList;
        }
        return list is byte[];
    }

    // The longest list among the round's values; a value that is not a list is one round.
    private static int RoundCount(List<string> names, IReadOnlyDictionary<string, object?> values)
    {
        var count = 0;
        foreach (var name in names)
        {
            if (!values.TryGetValue(name, out var v) || v is null)
                continue;
            count = Math.Max(count, v is IList list ? list.Count : 1);
        }
        return count;
    }

    private static Dictionary<string, object?> SliceRound(
        List<string> names,
        IReadOnlyDictionary<string, object?> values,
        int index)
    {
        var slice = values is RowValues ? new RowValues(names.Count) : new Dictionary<string, object?>();
        foreach (var name in names)
        {
            if (!values.TryGetValue(name, out var v) || v is null)
                continue;
            if (v is IList list)
            {
                if (index < list.Count)
                    slice[name] = list[index];
            }
            else
            {
                slice[name] = v;
            }
        }
        return slice;
    }

    private static void AppendRound(Dictionary<string, object?> into, Scope round, List<string> names)
    {
        foreach (var name in names)
            round.TryAdd(name, null);
        foreach (var pair in round)
            Append(into, pair.Key, pair.Value);
    }
}
