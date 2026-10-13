namespace Packbin;

// The value one list element or dictionary value read.
internal static partial class Walker
{
    // A leaf element is stored under its own name. A flags container or an anchored group with members has no value of
    // its own, so its element is the scope that holds its fields (a row of its members' names, only those a set bit
    // read). A nested-row group's inner scope sits under its name (U26 A, loop 25), as it does for a top-level
    // nested-row group; an empty group is a bool.
    private static object? ElementValue(Field element, Scope one) =>
        element.Type == Field.Kind.Flags
        || (element.Type == Field.Kind.Group && element.Children.Length > 0 && !element.NestedRow)
            ? one
            : one[element.Name];
}
