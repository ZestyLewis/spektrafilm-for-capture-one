using System;
using System.Diagnostics;
using System.Linq;

internal static class WorkerEnvironment
{
    internal static void Sanitize(ProcessStartInfo command)
    {
        // The application passes all creative settings over the protocol. Inherited
        // upstream experiment variables can otherwise disable entire film passes.
        foreach (var name in command.Environment.Keys.ToArray())
            if (name.StartsWith("SPEKTRAFILM_", StringComparison.OrdinalIgnoreCase)
                || name.Equals("DOTNET_STARTUP_HOOKS", StringComparison.OrdinalIgnoreCase))
                command.Environment.Remove(name);
    }
}
