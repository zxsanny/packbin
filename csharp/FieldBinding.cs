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
        var rowType = element.ElementRowType;
        RowElements = rowType is { IsClass: true } && rowType.IsAssignableFrom(ElementType);
        CreateElement = RowElements ? Creator.Of(ElementType) : null;
        if (IsArray)
            return;
        var built = dictionary
            ? typeof(Dictionary<,>).MakeGenericType(typeof(string), ElementType)
            : typeof(List<>).MakeGenericType(ElementType);
        Create = memberType.IsAssignableFrom(built) ? Creator.Of(built) : Creator.Of(memberType);
    }

    // The members Packbin accepts, on purpose: an array, List<E>, IList<E> or IList; for a dict Dictionary<string, E>,
    // IDictionary<string, E> or IDictionary. Everything else is refused when the scheme is built, including types that
    // would work (ICollection<E>, IReadOnlyList<E>, Collection<E>, IEnumerable<E>, a subclass of List<E>). A refusal can
    // be relaxed later; an accepted type cannot be withdrawn without breaking schemes that use it, so the accepted set
    // grows only when the owner decides it.
    public static bool IsSupported(Type member, bool dictionary)
    {
        if (!dictionary && member.IsArray)
            return member.GetArrayRank() == 1;
        if (!member.IsGenericType)
            return member == (dictionary ? typeof(System.Collections.IDictionary) : typeof(System.Collections.IList));
        var definition = member.GetGenericTypeDefinition();
        var args = member.GetGenericArguments();
        if (!dictionary)
            return definition == typeof(List<>) || definition == typeof(IList<>);
        return (definition == typeof(Dictionary<,>) || definition == typeof(IDictionary<,>)) && args[0] == typeof(string);
    }

    // The elements unpack hands over are a number of the element field's own width, a string, a byte run, or for a
    // group, flags or dict element a Dictionary<string, object?>, for a list element a List<object?>: the element type
    // must be object or hold the whole range of the field or be assignable from what is handed over, or a
    // Convert.ChangeType of a hostile packet value would throw out of Unpack. A row element is read through typed
    // accessors and is not checked here.
    public bool Holds(Field element)
    {
        if (RowElements || ElementType == typeof(object))
            return true;
        var type = Nullable.GetUnderlyingType(ElementType) ?? ElementType;
        return element.Type switch
        {
            Field.Kind.Utf8 => type == typeof(string),
            Field.Kind.Bytes or Field.Kind.Sized => type == typeof(byte[]),
            Field.Kind.Bool => type == typeof(bool),
            Field.Kind.F32 => type == typeof(float) || type == typeof(double),
            Field.Kind.F64 => type == typeof(double),
            >= Field.Kind.U8 and <= Field.Kind.I64 => HoldsRange(Walker.Range(element.Type), type),
            Field.Kind.U2 => HoldsRange((0, 3), type),
            Field.Kind.Group or Field.Kind.Flags or Field.Kind.Dict => type.IsAssignableFrom(typeof(Dictionary<string, object?>)),
            Field.Kind.List => type.IsAssignableFrom(typeof(List<object?>)),
            _ => true,
        };
    }

    private static bool HoldsRange((decimal Min, decimal Max) own, Type type)
    {
        if (type == typeof(float) || type == typeof(double) || type == typeof(decimal))
            return true;
        if (IntegerKind(type) is not { } kind)
            return false;
        var member = Walker.Range(kind);
        return member.Min <= own.Min && member.Max >= own.Max;
    }

    private static Field.Kind? IntegerKind(Type type) =>
        type == typeof(byte) ? Field.Kind.U8
        : type == typeof(sbyte) ? Field.Kind.I8
        : type == typeof(ushort) ? Field.Kind.U16
        : type == typeof(short) ? Field.Kind.I16
        : type == typeof(uint) ? Field.Kind.U32
        : type == typeof(int) ? Field.Kind.I32
        : type == typeof(ulong) ? Field.Kind.U64
        : type == typeof(long) ? Field.Kind.I64
        : null;

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
