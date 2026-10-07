using System.Linq.Expressions;

namespace Packbin;

// What a field needs to read its member on pack and write it on unpack, built once with the field.
internal sealed class FieldBinding
{
    public MemberAccess Member { get; }

    // u2: one accessor per slot.
    public MemberAccess[] Slots { get; }

    // Nested row: the row type unpack creates for the member, and its constructor (null when it has none).
    public Type? NestedType { get; }
    public Func<object>? CreateNested { get; }

    // List and dict: how unpack builds the collection.
    public CollectionShape? Shape { get; }

    private FieldBinding(
        MemberAccess member,
        MemberAccess[]? slots = null,
        Type? nestedType = null,
        CollectionShape? shape = null)
    {
        Member = member;
        Slots = slots ?? [];
        NestedType = nestedType;
        CreateNested = nestedType is null ? null : Creator.Of(nestedType);
        Shape = shape;
    }

    public static FieldBinding Of(MemberAccess member) => new(member);

    public static FieldBinding OfSlots(MemberAccess[] slots) => new(slots[0], slots);

    public static FieldBinding OfNestedRow(MemberAccess member, Type rowType) => new(member, nestedType: rowType);

    public static FieldBinding OfCollection(MemberAccess member, Field element, bool dictionary) =>
        new(member, shape: new CollectionShape(member.Type, element, dictionary));
}

// The collection member of a list or dict field. An element is a row of the element field's type when the collection
// is declared for such rows (`List<Role>` for `Utf8<Role>`); otherwise it is the element field's value itself
// (`ushort[]` for `U16<El>`, `List<object?>` for strings).
internal sealed class CollectionShape
{
    public Type ElementType { get; }
    public bool Dictionary { get; }
    public bool RowElements { get; }
    public Func<object>? CreateElement { get; }

    // An empty List<E> or Dictionary<string, E> that fits the member, or null when the member is an array or an
    // unknown type (then only the value unpack read can be assigned, and only if it already fits).
    public Func<object>? Create { get; }
    public bool IsArray { get; }

    public CollectionShape(Type memberType, Field element, bool dictionary)
    {
        Dictionary = dictionary;
        IsArray = memberType.IsArray;
        ElementType = ElementOf(memberType, dictionary);
        var rowType = element.RowType;
        RowElements = rowType is { IsClass: true } && rowType.IsAssignableFrom(ElementType);
        CreateElement = RowElements ? Creator.Of(ElementType) : null;
        if (IsArray)
            return;
        var built = dictionary
            ? typeof(Dictionary<,>).MakeGenericType(typeof(string), ElementType)
            : typeof(List<>).MakeGenericType(ElementType);
        Create = memberType.IsAssignableFrom(built) ? Creator.Of(built) : Creator.Of(memberType);
    }

    private static Type ElementOf(Type member, bool dictionary)
    {
        if (member.IsArray)
            return member.GetElementType()!;
        var args = member.IsGenericType ? member.GetGenericArguments() : [];
        var index = dictionary ? 1 : 0;
        return args.Length > index ? args[index] : typeof(object);
    }
}

internal static class Creator
{
    // A compiled `new type()`, or null when the type is not a class with a public parameterless constructor.
    public static Func<object>? Of(Type type)
    {
        if (!type.IsClass || type.IsAbstract || type.GetConstructor(Type.EmptyTypes) is not { } constructor)
            return null;
        return Expression.Lambda<Func<object>>(Expression.New(constructor)).Compile();
    }
}
