using System;
using System.Runtime.ExceptionServices;
using System.Threading;
using System.Threading.Tasks;

internal static class PreviewRows
{
    private const int ParallelPixelThreshold = 4_000_000;
    private const int MaximumWorkers = 6;

    internal static void Process(int width, int height, CancellationToken token, Action<int, int> processRange)
    {
        token.ThrowIfCancellationRequested();
        var workers = Math.Min(Math.Min(Environment.ProcessorCount, MaximumWorkers), height);
        if ((long)width * height < ParallelPixelThreshold || workers <= 1)
        {
            processRange(0, height);
            return;
        }

        var options = new ParallelOptions { CancellationToken = token, MaxDegreeOfParallelism = workers };
        try
        {
            Parallel.For(0, workers, options, worker =>
            {
                var start = (int)((long)height * worker / workers);
                var end = (int)((long)height * (worker + 1) / workers);
                processRange(start, end);
            });
        }
        catch (AggregateException error) when (error.InnerExceptions.Count == 1)
        {
            ExceptionDispatchInfo.Capture(error.InnerExceptions[0]).Throw();
        }
    }
}
