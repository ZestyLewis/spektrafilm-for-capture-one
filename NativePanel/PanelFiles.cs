using System;
using System.IO;
using System.Text.Json;

internal static class PanelFiles
{
    private const int MaxPresetBytes = 65536;
    private static readonly JsonSerializerOptions WriteOptions = new() { WriteIndented = true };

    internal static T ReadPreset<T>(string path)
    {
        using var file = File.OpenRead(path);
        if (file.Length > MaxPresetBytes)
            throw new InvalidDataException("The preset is larger than 64 KB.");
        var bytes = new byte[checked((int)file.Length)];
        file.ReadExactly(bytes);
        ReadOnlySpan<byte> json = bytes;
        if (json.StartsWith("\uFEFF"u8))
            json = json[3..];
        return JsonSerializer.Deserialize<T>(json) ?? throw new InvalidDataException("The preset contains no look settings.");
    }

    internal static void WritePreset<T>(string path, T preset) =>
        WriteAtomically(path, stream => JsonSerializer.Serialize(stream, preset, WriteOptions));

    internal static void WriteAtomically(string path, Action<Stream> write)
    {
        var destination = Path.GetFullPath(path);
        var temp = Path.Combine(Path.GetDirectoryName(destination)!, $".spektra-{Guid.NewGuid():N}.tmp");
        try
        {
            using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                write(stream);
                stream.Flush(flushToDisk: true);
            }
            File.Move(temp, destination, overwrite: true);
        }
        finally
        {
            if (File.Exists(temp))
                File.Delete(temp);
        }
    }
}
