namespace Packbin;

// The value one list element or dictionary value read.
internal static partial class Walker
{
    // A leaf element is stored under its own name. A group has no value of its own, so its element is the scope that
    // holds its fields (a row of its members' names), except a typed nested row, which is stored whole under its name,
    // and an empty group, which is a bool.
    private static object? ElementValue(Field element, Scope one) =>
        element.Type == Field.Kind.Group && element.Children.Length > 0 && !(element.NestedRow && one.Scoped)
            ? one
            : one[element.Name];
}
