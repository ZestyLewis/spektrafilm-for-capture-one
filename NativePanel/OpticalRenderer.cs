using System;
using System.Buffers.Binary;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

internal sealed class OpticalRenderer(bool export = false, bool nativePreview = false) : IDisposable
{
    private Process? process;
    private WeakReference<byte[]>? source;

    internal async Task<byte[]> RenderAsync(int width, int height, byte[] rgba, string[] arguments, CancellationToken stop,
        bool displayPixels = false)
    {
        if (displayPixels && !nativePreview)
            throw new InvalidOperationException("Packed display pixels require the native Viewer renderer.");
        var renderer = GetProcess();
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(stop);
        deadline.CancelAfter(export || nativePreview ? TimeSpan.FromMinutes(8) : TimeSpan.FromSeconds(20));
        var token = deadline.Token;
        var input = renderer.StandardInput.BaseStream;
        var output = renderer.StandardOutput.BaseStream;
        var newSource = source is null || !source.TryGetTarget(out var previous) || !ReferenceEquals(previous, rgba);
        var verb = newSource ? (displayPixels ? "FRAME8" : "FRAME") : (displayPixels ? "REUSE8" : "REUSE");
        var command = newSource ? FormattableString.Invariant($"{verb} {width} {height}") : verb;
        var header = Encoding.ASCII.GetBytes(command + " " + string.Join(' ', arguments) + "\n");
        var reply = new byte[8];
        try
        {
            await input.WriteAsync(header, token).ConfigureAwait(false);
            if (newSource)
                await input.WriteAsync(rgba, token).ConfigureAwait(false);
            await input.FlushAsync(token).ConfigureAwait(false);
            await output.ReadExactlyAsync(reply, token).ConfigureAwait(false);
            var code = BinaryPrimitives.ReadInt32LittleEndian(reply);
            var size = BinaryPrimitives.ReadInt32LittleEndian(reply.AsSpan(4));
            if (code == 1 && size is >= 1 and <= 16384)
            {
                var error = new byte[size];
                await output.ReadExactlyAsync(error, token).ConfigureAwait(false);
                source = null;
                throw new InvalidOperationException(Encoding.UTF8.GetString(error));
            }
            if (code != 0 || size != (displayPixels ? rgba.Length / sizeof(float) : rgba.Length))
                throw new InvalidDataException("The optical renderer returned an invalid frame.");

            var pixels = GC.AllocateUninitializedArray<byte>(size);
            await output.ReadExactlyAsync(pixels, token).ConfigureAwait(false);
            if (newSource)
                source = new WeakReference<byte[]>(rgba);
            return pixels;
        }
        catch (OperationCanceledException) when (!stop.IsCancellationRequested)
        {
            Stop(abort: true);
            var target = export ? "export" : nativePreview ? "native Viewer preview" : "preview";
            throw new TimeoutException($"Spektrafilm did not finish the {target} in time.");
        }
        catch (Exception error) when (error is IOException or OperationCanceledException or ObjectDisposedException)
        {
            Stop(abort: true);
            throw;
        }
    }

    private Process GetProcess()
    {
        if (process is { HasExited: false })
            return process;
        Dispose();
        var root = Environment.GetEnvironmentVariable("SPEKTRAFILM_ROOT")
            ?? throw new InvalidOperationException("Start Capture One using the Spektrafilm launcher.");
        var exe = Path.Combine(root, "renderer", "SpektraStillRenderer.exe");
        if (!File.Exists(exe))
            throw new IOException("The Spektrafilm Vulkan renderer is missing. See the project README.");
        var start = new ProcessStartInfo(exe)
        {
            WorkingDirectory = Path.GetDirectoryName(exe)!, UseShellExecute = false, CreateNoWindow = true,
            RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true,
        };
        start.Environment.Remove("DOTNET_STARTUP_HOOKS");
        start.ArgumentList.Add(export ? "--export-stream" : nativePreview ? "--native-preview-stream" : "--stream");
        var child = Process.Start(start) ?? throw new IOException("Could not start the optical renderer.");
        child.ErrorDataReceived += (_, args) =>
        {
            if (!string.IsNullOrEmpty(args.Data))
                StartupHook.Log("Optical renderer: " + args.Data);
        };
        child.BeginErrorReadLine();
        process = child;
        return child;
    }

    public void Dispose() => Stop(abort: false);

    private void Stop(bool abort)
    {
        var child = process;
        process = null;
        source = null;
        if (child is null)
            return;
        if (abort)
            CloseWorker(child, abort: true);
        else
            _ = Task.Run(() => CloseWorker(child, abort: false));
    }

    private static void CloseWorker(Process child, bool abort)
    {
        try
        {
            if (child.HasExited)
                return;
            if (!abort)
            {
                child.StandardInput.Close();
                if (child.WaitForExit(300))
                    return;
            }
            if (!child.HasExited)
                child.Kill();
        }
        catch (IOException)
        {
            try { if (!child.HasExited) child.Kill(); }
            catch (InvalidOperationException) { }
        }
        catch (InvalidOperationException) { }
        catch (System.ComponentModel.Win32Exception error) { StartupHook.Log($"Optical renderer shutdown: {error.Message}"); }
        finally
        {
            child.Dispose();
        }
    }
}
