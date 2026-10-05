namespace Packbin;

// A round packs item i of each value list, so a repeat or times inside it would read every inner round from the same
// item. A round cannot hold another one, directly or under a when, flags, flag bit or group (a nested row included).
// A list or dict element is a row of its own and starts outside any round.
internal static class RoundScopes
{
    public static void Validate(IReadOnlyList<Field> fields) => Check(fields, inRound: false);

    private static void Check(IEnumerable<Field> fields, bool inRound)
    {
        foreach (var field in fields)
        {
            switch (field.Type)
            {
                case Field.Kind.Repeat:
                case Field.Kind.Times:
                    if (inRound)
                        throw new ArgumentException(
                            $"{field.Type.ToString().ToLowerInvariant()} {field.Id} is inside a repeat or times round; "
                            + "a round cannot hold another repeat or times");
                    Check(field.Children, inRound: true);
                    break;
                case Field.Kind.FlagBit:
                    Check([field.Inner!], inRound);
                    break;
                case Field.Kind.Flags:
                case Field.Kind.When:
                case Field.Kind.Group:
                    Check(field.Children, inRound);
                    break;
                case Field.Kind.List:
                case Field.Kind.Dict:
                    Check(field.Children, inRound: false);
                    break;
            }
        }
    }
}
