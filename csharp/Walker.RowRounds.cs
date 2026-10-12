namespace Packbin;

// A repeat or times bound to a collection of rows (AZ-2388), packed from a typed row. RowBinding.Read puts the rounds of
// such a field under its member's name, one RowValues each, so a round reads the members of its own row and never the
// names of the row around it. The dictionary form of a row has no rows to give: it keeps the per-name lists.
internal static partial class Walker
{
    // The rows of a round bound to a collection; null for any other round or row. A null collection is no rounds.
    private static List<RowValues>? RowsOf(Field round, IReadOnlyDictionary<string, object?> values) =>
        round.Binding is null || values is not RowValues ? null
        : values.TryGetValue(round.Name, out var rows) && rows is List<RowValues> list ? list
        : [];

    // Typed unpack of a round bound to rows keeps each round as the scope it read, under the field's name, for RowBinding to
    // turn into rows; the dictionary result keeps the per-name lists. Null when the rounds go to the lists.
    private static List<Scope>? RoundRowsFor(Field round, Scope values) =>
        round.Binding is not null && values.Scoped ? [] : null;

    private static void PackRowRepeat(Field field, List<RowValues> rows, PackOut buffer, Scope seen)
    {
        var limit = seen.Budget.MaxRounds;
        if (rows.Count > limit)
            throw new ArgumentException($"'{field.Name}': the repeat count is {rows.Count}, above the limit of {limit} rounds");
        PackRounds(field, field.Name, rows.Count, i => rows[i], buffer, seen);
    }

    private static void RequireRowCount(Field times, List<RowValues> rows, int count)
    {
        if (rows.Count != count)
            throw new ArgumentException($"'{times.Name}': the times count is {count}, but it holds {rows.Count} rounds");
    }

    // Whether a round is given anything, and the name to report: the collection of a round bound to rows when it holds
    // a row, else the first member name with a value that `given` accepts.
    private static string? GivenInRound(Field round, IReadOnlyDictionary<string, object?> values, Func<object, bool>? given = null)
    {
        if (RowsOf(round, values) is { } rows)
            return rows.Count > 0 ? round.Name : null;
        return RoundNames(round, packing: true)
            .FirstOrDefault(name => IsPresent(values, name) && (given is null || given(values[name]!)));
    }
}
