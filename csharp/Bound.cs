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
