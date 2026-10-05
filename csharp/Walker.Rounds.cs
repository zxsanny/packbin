using System.Collections;

namespace Packbin;

// A repeat or times round is addressed by index. Pack reads each value list at the round's index; unpack gives every
// value a round can hold one entry per round, null where the round skipped it, so a repack gives the same bytes.
internal static partial class Walker
{
    private static void PackRepeat(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        var names = RoundNames(field, packing: true);
        PackRounds(field, names, RoundCount(names, values), values, buffer);
    }

    private static void PackTimes(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer) =>
        PackRounds(field, RoundNames(field, packing: true), BorrowedCount(field, values), values, buffer);

    private static void PackRounds(
        Field field,
        List<string> names,
        int count,
        IReadOnlyDictionary<string, object?> values,
        List<byte> buffer)
    {
        for (var i = 0; i < count; i++)
        {
            var slice = SliceRound(names, values, i);
            foreach (var child in field.Children)
                PackField(child, slice, buffer);
        }
    }

    // The names a round can hold: its own fields and the ones under when, flags, flag bits and groups. A repeat or times
    // inside the round and a list or dict element keep values of their own, so they are not looked into.
    // `packing`: a group's own member is read on pack (it can turn the group's flag bit on); unpack stores it only for
    // an empty group.
    private static List<string> RoundNames(Field round, bool packing)
    {
        var names = new List<string>();
        foreach (var child in round.Children)
            AddRoundNames(child, packing, names);
        return names;
    }

    private static void AddRoundNames(Field field, bool packing, List<string> names)
    {
        switch (field.Type)
        {
            case Field.Kind.Repeat:
            case Field.Kind.Times:
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
        var slice = new Dictionary<string, object?>();
        foreach (var name in names)
        {
            if (!values.TryGetValue(name, out var v) || v is null)
                continue;
            if (v is IList list)
            {
                if (index < list.Count)
                    slice[name] = list[index];
            }
            else if (index == 0)
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
        foreach (var (key, value) in round)
            Append(into, key, value);
    }
}
