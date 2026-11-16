using System;
using System.Threading;

// Accepted output jobs are independent of later UI selection / enable state.
internal sealed class ExportOperation(Guid variantId) : IDisposable
{
    private readonly CancellationTokenSource stop = new();
    internal Guid VariantId { get; } = variantId;
    internal CancellationToken Token => stop.Token;
    internal void Cancel() => stop.Cancel();
    public void Dispose() => stop.Dispose();
}
