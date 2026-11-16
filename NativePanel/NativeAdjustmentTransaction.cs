using System;
using System.Collections.Generic;
using System.Runtime.ExceptionServices;

// Native setters may throw after mutating a value. Include the active step in
// rollback, then attempt every earlier restoration before ending the undo group.
internal static class NativeAdjustmentTransaction
{
    internal sealed record Step(string Name, Action Apply, Action Restore);

    internal static void Execute(IReadOnlyList<Step> steps, Action endScope)
    {
        var errors = new List<Exception>();
        var active = -1;
        try
        {
            for (var index = 0; index < steps.Count; index++)
            {
                active = index;
                steps[index].Apply();
            }
        }
        catch (Exception error)
        {
            errors.Add(error);
            for (var index = active; index >= 0; index--)
            {
                try { steps[index].Restore(); }
                catch (Exception restoreError)
                {
                    errors.Add(new InvalidOperationException($"Could not restore native '{steps[index].Name}'.", restoreError));
                }
            }
        }
        try { endScope(); }
        catch (Exception scopeError) { errors.Add(scopeError); }
        if (errors.Count == 1) ExceptionDispatchInfo.Capture(errors[0]).Throw();
        if (errors.Count > 1)
            throw new AggregateException("The native adjustment failed and additional rollback or undo errors occurred. Check Capture One Grain; Restore remains available when its values can be verified.", errors);
    }
}
