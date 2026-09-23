using System.Collections;
using System.Globalization;
using System.Reflection;

namespace Packbin;

public sealed class Bound<T>
{
    public T? Value { get; }
    public object? Error { get; }
    public bool Ok => Error is null;

    public Bound(T? value, object? error)
    {
        Value = value;
        Error = error;
    }
}

internal static class ObjectValues
{
    public static Dictionary<string, object?> From(object? value)
    {
        var dict = new Dictionary<string, object?>();
        if (value is not null)
            Collect(value, dict);
        return dict;
    }

    public static T To<T>(IReadOnlyDictionary<string, object?> values) where T : new()
    {
        var target = new T();
        Apply(target, values);
        return target;
    }

    private static void Collect(object value, Dictionary<string, object?> dict)
    {
        foreach (var member in Members(value.GetType()))
        {
            var raw = member.Read(value);
            if (raw is null)
                continue;
            var type = Nullable.GetUnderlyingType(member.Type) ?? member.Type;
            if (IsNested(type))
                Collect(raw, dict);
            else
                dict[member.Name] = raw;
        }
    }

    private static void Apply(object target, IReadOnlyDictionary<string, object?> values)
    {
        foreach (var member in Members(target.GetType()))
        {
            if (member.Write is null)
                continue;
            var type = Nullable.GetUnderlyingType(member.Type) ?? member.Type;
            if (IsNested(type))
            {
                if (!ContainsAny(type, values))
                    continue;
                var child = Activator.CreateInstance(type)
                    ?? throw new InvalidOperationException($"Cannot create {type.Name}.");
                Apply(child, values);
                member.Write(target, child);
                continue;
            }
            if (!values.TryGetValue(member.Name, out var raw) || raw is null)
                continue;
            member.Write(target, ConvertValue(raw, type));
        }
    }

    private static bool ContainsAny(Type type, IReadOnlyDictionary<string, object?> values)
    {
        foreach (var member in Members(type))
        {
            var inner = Nullable.GetUnderlyingType(member.Type) ?? member.Type;
            if (IsNested(inner))
            {
                if (ContainsAny(inner, values))
                    return true;
            }
            else if (values.TryGetValue(member.Name, out var raw) && raw is not null)
            {
                return true;
            }
        }
        return false;
    }

    private static bool IsNested(Type type) =>
        type.IsClass
        && type != typeof(string)
        && type != typeof(byte[])
        && !typeof(IEnumerable).IsAssignableFrom(type);

    private static object ConvertValue(object raw, Type type)
    {
        if (type.IsInstanceOfType(raw))
            return raw;
        if (raw is IList list && typeof(IList).IsAssignableFrom(type) && type != typeof(byte[]))
        {
            var element = type.IsArray ? type.GetElementType()! : type.GetGenericArguments()[0];
            if (type.IsArray)
            {
                var array = Array.CreateInstance(element, list.Count);
                for (var i = 0; i < list.Count; i++)
                    array.SetValue(ConvertValue(list[i]!, element), i);
                return array;
            }
            var created = (IList)Activator.CreateInstance(type)!;
            foreach (var item in list)
                created.Add(item is null ? null : ConvertValue(item, element));
            return created;
        }
        return Convert.ChangeType(raw, type, CultureInfo.InvariantCulture);
    }

    private static List<Member> Members(Type type)
    {
        const BindingFlags flags = BindingFlags.Instance | BindingFlags.Public;
        var members = new List<Member>();
        foreach (var property in type.GetProperties(flags))
        {
            if (property.GetIndexParameters().Length > 0 || !property.CanRead)
                continue;
            var write = property.CanWrite
                ? new Action<object, object?>((target, value) => property.SetValue(target, value))
                : null;
            members.Add(new Member(property.Name, property.PropertyType, property.GetValue, write));
        }
        foreach (var field in type.GetFields(flags))
        {
            if (field.IsStatic)
                continue;
            members.Add(new Member(
                field.Name,
                field.FieldType,
                field.GetValue,
                (target, value) => field.SetValue(target, value)));
        }
        return members;
    }

    private sealed class Member
    {
        public string Name { get; }
        public Type Type { get; }
        public Func<object, object?> Read { get; }
        public Action<object, object?>? Write { get; }

        public Member(string name, Type type, Func<object, object?> read, Action<object, object?>? write)
        {
            Name = name;
            Type = type;
            Read = read;
            Write = write;
        }
    }
}
