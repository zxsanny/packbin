using System.Reflection;

namespace Packbin.Tests;

// The session's private key and counter fields, for tests that build or check packets by hand.
internal static class SessionPrivates
{
    public static object Get(PackSession session, string name) =>
        typeof(PackSession).GetField(name, BindingFlags.Instance | BindingFlags.NonPublic)!.GetValue(session)!;
}
