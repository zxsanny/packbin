namespace Packbin;

// A round packs item i of each value list, so a repeat or times inside it would read every inner round from the same
// item. A round cannot hold another one, directly or under a when, flags, flag bit or group (a nested row included).
// A list or dict element is a row of its own and starts outside any round.
internal static class RoundScopes
{
    public static void Validate(IReadOnlyList<Field> fields)
    {
        Check(fields, inRound: false);
        CheckBodies(fields);
    }

    // AZ-2390: a round body must hold a member, or a round of it would charge no slot and write nothing, and the limits
    // would not bound the work (F33). Checked once at construction, after the nesting check, so a round costs nothing.
    private static void CheckBodies(IEnumerable<Field> fields)
    {
        foreach (var field in fields)
        {
            if (field.Type is Field.Kind.Repeat or Field.Kind.Times && !HoldsMember(field.Children))
                throw new ArgumentException(
                    $"{field.Type.ToString().ToLowerInvariant()} {field.Id}: the body holds no member; "
                    + "a round of it would charge no slot and write nothing");
            if (field.Type == Field.Kind.FlagBit)
                CheckBodies([field.Inner!]);
            else
                CheckBodies(field.Children);
        }
    }

    // Looking through `when` and groups at any depth, any field that is not a container is a member: a value (a
    // zero-width byte run included), a list, a dict, a u2, a flag byte, a flag bit, and a `flags`, which writes its flag
    // byte even with no member. A `when` or a group with no member holds none.
    private static bool HoldsMember(IEnumerable<Field> fields) =>
        fields.Any(field => field.Type switch
        {
            Field.Kind.When or Field.Kind.Group => HoldsMember(field.Children),
            Field.Kind.Repeat or Field.Kind.Times => false,
            _ => true,
        });

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
