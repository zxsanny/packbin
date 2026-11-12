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
        Field? open = null;
        CheckLast(fields, inElement: false, ref open);
    }

    // AZ-4212 (contract repeat-last): a repeat has no count on the wire, so unpack reads its rounds to the end of the
    // packet and would read whatever is written after it as more rounds. A repeat must be the last thing the packet
    // reads: no field that can write a byte stands after it, in its own place or after a when, flags, flag bit, group or
    // nested row that holds it, and it is not inside a list or dict element, where the next element follows it. A repeat
    // inside a round is refused by the nesting check above. Checked once at construction; it never looks at a row.
    // `open`: the first repeat met so far. A round body and an element are places of their own, with none open.
    private static void CheckLast(IEnumerable<Field> fields, bool inElement, ref Field? open)
    {
        foreach (var field in fields)
        {
            if (open is not null && Writer(field) is { } follower)
                throw new ArgumentException(
                    $"repeat {open.Id}: {Named(follower)} follows it; a repeat reads to the end of the packet, "
                    + "so nothing can follow it; use times");
            Field? none = null;
            switch (field.Type)
            {
                case Field.Kind.Repeat when inElement:
                    throw new ArgumentException(
                        $"repeat {field.Id} is inside a list or dict element; a repeat reads to the end of the packet, "
                        + "so another element cannot follow it; use times");
                case Field.Kind.Repeat:
                    open ??= field;
                    CheckLast(field.Children, inElement, ref none);
                    break;
                case Field.Kind.Times:
                    CheckLast(field.Children, inElement, ref none);
                    break;
                case Field.Kind.List:
                case Field.Kind.Dict:
                    CheckLast(field.Children, inElement: true, ref none);
                    break;
                case Field.Kind.FlagBit:
                    CheckLast([field.Inner!], inElement, ref open);
                    break;
                case Field.Kind.Flags:
                case Field.Kind.When:
                case Field.Kind.Group:
                    CheckLast(field.Children, inElement, ref open);
                    break;
            }
        }
    }

    // The first field at or under `field` that can write a byte, or null. A bool is a bit of a flag byte written
    // earlier and a zero-width byte run writes nothing; a when, a group and a flag bit count by what they hold, a round
    // by its body. Everything else writes: a value, a flag byte, a `flags` (its flag byte), a list or dict (its count).
    private static Field? Writer(Field field) =>
        field.Type switch
        {
            Field.Kind.Bool => null,
            Field.Kind.Bytes => field.ByteCount > 0 ? field : null,
            Field.Kind.FlagBit => Writer(field.Inner!),
            Field.Kind.When or Field.Kind.Group => FirstWriter(field.Children),
            Field.Kind.Repeat or Field.Kind.Times => FirstWriter(field.Children) is null ? null : field,
            _ => field,
        };

    private static Field? FirstWriter(Field[] fields)
    {
        foreach (var field in fields)
        {
            if (Writer(field) is { } writer)
                return writer;
        }
        return null;
    }

    // How a refusal names the field that follows a repeat: a container by its kind and anchor, a list or dict by its
    // member, a flag byte (it has neither), a value by its member and field id.
    private static string Named(Field field) =>
        field.Type switch
        {
            Field.Kind.Repeat or Field.Kind.Times or Field.Kind.Flags => $"{field.Type.ToString().ToLowerInvariant()} {field.Id}",
            Field.Kind.FlagByte => "a flag byte",
            Field.Kind.List or Field.Kind.Dict => $"{field.Type.ToString().ToLowerInvariant()} '{field.Name}'",
            _ => $"'{field.Name}' (field id {field.Id})",
        };

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
