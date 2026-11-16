using System;
using System.Threading;
using System.Threading.Tasks;

internal static class RenderCoordination
{
    // A provisional frame is never a prerequisite for the ready final source.
    internal static async Task<T> PreferFinalAsync<T>(Task<T> final, Func<CancellationToken, Task> preview, CancellationToken stop)
    {
        if (final.IsCompleted) return await final.WaitAsync(stop);
        var provisional = CancellationTokenSource.CreateLinkedTokenSource(stop);
        Task work;
        try { work = preview(provisional.Token); }
        catch
        {
            // A failed provisional renderer must not discard an already accepted
            // final development task or leave its eventual error unobserved.
            work = Task.CompletedTask;
        }
        try { return await final.WaitAsync(stop); }
        finally
        {
            provisional.Cancel();
            _ = ObserveAndDisposeAsync(work, provisional);
        }
    }

    private static async Task ObserveAndDisposeAsync(Task work, CancellationTokenSource lifetime)
    {
        try { await work.ConfigureAwait(false); }
        catch (Exception) { /* Provisional errors are reported by the preview route. */ }
        finally { lifetime.Dispose(); }
    }
}
