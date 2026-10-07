using System.Collections;

namespace Packbin;

// A repeat or times round is addressed by index. Pack reads each value list at the round's index and gives a value that
// is not a list to every round; unpack gives every value a round can hold one entry per round, null where the round
// skipped it, so a repack gives the same bytes.
internal static partial class Walker
{
    private static void PackRepeat(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        var names = RoundNames(field, packing: true);
        RequireRoundCollections(field, values);
        PackRounds(field, names, RoundCount(names, values), values, buffer);
    }

    private static void PackTimes(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        List<byte> buffer,
        Scope seen)
    {
        var names = RoundNames(field, packing: true);
        RequireRoundCollections(field, values);
        var count = BorrowedCount(field, seen);
        RequireNoExtraRounds(names, count, values);
        PackRounds(field, names, count, values, buffer);
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

    private static void PackRounds(
        Field field,
        List<string> names,
        int count,
        IReadOnlyDictionary<string, object?> values,
        List<byte> buffer)
    {
        var seen = new Scope();
        for (var i = 0; i < count; i++)
        {
            var slice = SliceRound(names, values, i);
            seen.Clear();
            foreach (var child in field.Children)
                PackField(child, slice, buffer, seen);
        }
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

    // A name that holds a byte run or a list per round (bytes, sized, bits, packed) takes a list with one of them per
    // round. One byte run or list alone would be read as the list of rounds, and its items given to the rounds.
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
