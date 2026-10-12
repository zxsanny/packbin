using System.Collections;

namespace Packbin;

// A repeat or times bound to a collection of rows (AZ-2388): the member is an E[], List<E> or IList<E> of a row class E
// with a public parameterless constructor, and the round's fields are declared for E. The scheme build asks `Binds`, and
// typed Unpack builds its collection through this same object, so a scheme builds if and only if its member binds.
internal sealed class RowRounds
{
    private readonly Func<object>? _createElement;
    private readonly Func<object>? _createList;

    // The row type E, or null when the member is not an E[], List<E> or IList<E>.
    public Type? ElementType { get; }

    public bool IsArray { get; }

    public RowRounds(Type member)
    {
        IsArray = member.IsArray && member.GetArrayRank() == 1;
        ElementType = ElementOf(member, IsArray);
        if (ElementType is null || !IsCollection)
            return;
        _createElement = Creator.Of(ElementType);
        _createList = IsArray ? null : Creator.Of(typeof(List<>).MakeGenericType(ElementType));
    }

    // An E[], List<E> or IList<E> of a row class: a class that is not a string or an array.
    public bool IsCollection => ElementType is { IsClass: true, IsArray: false } && ElementType != typeof(string);

    public bool Binds => _createElement is not null;

    private static Type? ElementOf(Type member, bool isArray)
    {
        if (isArray)
            return member.GetElementType();
        if (!member.IsGenericType)
            return null;
        var definition = member.GetGenericTypeDefinition();
        return definition == typeof(List<>) || definition == typeof(IList<>) ? member.GetGenericArguments()[0] : null;
    }

    public object CreateElement() => _createElement!();

    // The collection the member takes: an array, or a List<E> (which an IList<E> member holds).
    public object Collect(IList<object> elements)
    {
        if (IsArray)
        {
            var array = Array.CreateInstance(ElementType!, elements.Count);
            for (var i = 0; i < elements.Count; i++)
                array.SetValue(elements[i], i);
            return array;
        }
        var list = (IList)_createList!();
        foreach (var element in elements)
            list.Add(element);
        return list;
    }
}
