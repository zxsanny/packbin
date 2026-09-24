using System.Linq.Expressions;
using System.Reflection;

namespace Packbin;

internal sealed class MemberAccess
{
    public string Name { get; }
    public Func<object, object?> Get { get; }
    public Action<object, object?> Set { get; }

    private MemberAccess(string name, Func<object, object?> get, Action<object, object?> set)
    {
        Name = name;
        Get = get;
        Set = set;
    }

    public static MemberAccess From<T, TProp>(Expression<Func<T, TProp>> accessor)
    {
        if (accessor.Body is not MemberExpression member
            || member.Expression is not ParameterExpression)
            throw new ArgumentException("accessor must be a member access");

        return member.Member switch
        {
            PropertyInfo property => FromProperty(property),
            FieldInfo field => FromField(field),
            _ => throw new ArgumentException("accessor must be a member access"),
        };
    }

    private static MemberAccess FromProperty(PropertyInfo property)
    {
        if (!property.CanRead)
            throw new ArgumentException("accessor must be a member access");
        if (!property.CanWrite)
            throw new ArgumentException("accessor member must be settable");
        return new MemberAccess(
            property.Name,
            target => property.GetValue(target),
            (target, value) => property.SetValue(target, value));
    }

    private static MemberAccess FromField(FieldInfo field)
    {
        if (field.IsInitOnly)
            throw new ArgumentException("accessor member must be settable");
        return new MemberAccess(
            field.Name,
            field.GetValue,
            field.SetValue);
    }
}
