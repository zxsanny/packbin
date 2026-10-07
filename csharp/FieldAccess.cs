using System.Globalization;
using System.Linq.Expressions;
using System.Reflection;

namespace Packbin;

// The member an accessor names, read and written through delegates compiled once when the field is built.
internal sealed class MemberAccess
{
    private static readonly MethodInfo ChangeType =
        typeof(Convert).GetMethod(nameof(Convert.ChangeType), [typeof(object), typeof(Type), typeof(IFormatProvider)])!;

    public string Name { get; }
    public Type Type { get; }
    public Func<object, object?> Get { get; }

    // Takes what unpack read: a value of the member's type, or a number Convert.ChangeType can turn into it.
    public Action<object, object?> Set { get; }

    private MemberAccess(string name, Type type, Func<object, object?> get, Action<object, object?> set)
    {
        Name = name;
        Type = type;
        Get = get;
        Set = set;
    }

    public static MemberAccess From<T, TProp>(Expression<Func<T, TProp>> accessor)
    {
        if (accessor.Body is not MemberExpression member
            || member.Expression is not ParameterExpression)
            throw new ArgumentException("accessor must be a member access");

        switch (member.Member)
        {
            case PropertyInfo property:
                if (!property.CanRead)
                    throw new ArgumentException("accessor must be a member access");
                if (!property.CanWrite)
                    throw new ArgumentException("accessor member must be settable");
                break;
            case FieldInfo field:
                if (field.IsInitOnly)
                    throw new ArgumentException("accessor member must be settable");
                break;
            default:
                throw new ArgumentException("accessor must be a member access");
        }

        var row = Expression.Parameter(typeof(object), "row");
        var value = Expression.Parameter(typeof(object), "value");
        var target = Expression.MakeMemberAccess(Expression.Convert(row, typeof(T)), member.Member);
        var get = Expression.Lambda<Func<object, object?>>(Expression.Convert(target, typeof(object)), row).Compile();
        var set = Expression.Lambda<Action<object, object?>>(
            Expression.Assign(target, ConvertTo(value, typeof(TProp))), row, value).Compile();
        return new MemberAccess(member.Member.Name, typeof(TProp), get, set);
    }

    // A value already of the member's type is assigned as it is. Unpack reads the narrower numbers as a double, which
    // holds every value of the member's own width exactly, so it is cast; anything else goes through Convert.ChangeType.
    private static Expression ConvertTo(Expression value, Type target)
    {
        var underlying = Nullable.GetUnderlyingType(target) ?? target;
        if (!typeof(IConvertible).IsAssignableFrom(underlying))
            return Expression.Convert(value, target);
        var converted = Expression.Convert(
            Expression.Call(
                ChangeType,
                value,
                Expression.Constant(underlying, typeof(Type)),
                Expression.Constant(CultureInfo.InvariantCulture, typeof(IFormatProvider))),
            target);
        var own = Expression.Condition(Expression.TypeIs(value, underlying), Expression.Convert(value, target), converted);
        if (!Widths.Contains(underlying) || underlying == typeof(double))
            return own;
        var wide = Expression.Convert(Expression.Convert(Expression.Unbox(value, typeof(double)), underlying), target);
        return Expression.Condition(Expression.TypeIs(value, typeof(double)), wide, own);
    }

    private static readonly HashSet<Type> Widths =
        [typeof(byte), typeof(sbyte), typeof(ushort), typeof(short), typeof(uint), typeof(int), typeof(float), typeof(double)];
}
