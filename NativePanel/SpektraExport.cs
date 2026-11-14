using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Threading;
using System.Windows.Media;
using System.Windows.Media.Imaging;

internal static class SpektraExport
{
    internal const string FileFilter = "16-bit TIFF image|*.tif|16-bit PNG image|*.png";

    internal static string ExtensionFor(string? format) => format?.ToUpperInvariant() switch
    {
        "PNG" => ".png",
        _ => ".tif",
    };

    internal static PixelFormat PixelFormatFor(string path) => Path.GetExtension(path).ToLowerInvariant() switch
    {
        ".tif" or ".tiff" => PixelFormats.Rgb48,
        ".png" => PixelFormats.Rgba64,
        _ => throw new InvalidOperationException("Choose 16-bit TIFF or PNG for the SpektraFilm file."),
    };

    internal static void Save(string path, BitmapSource image, CancellationToken stop)
    {
        stop.ThrowIfCancellationRequested();
        var format = PixelFormatFor(path);
        if (image.Format != format)
            throw new InvalidDataException($"SpektraFilm export requires unpremultiplied {format} pixels.");

        BitmapEncoder encoder = format == PixelFormats.Rgba64
            ? new PngBitmapEncoder()
            : new TiffBitmapEncoder { Compression = TiffCompressOption.Zip };
        var profilePath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System),
            "spool", "drivers", "color", "sRGB Color Space Profile.icm");
        var profile = new ReadOnlyCollection<ColorContext>(new[] { new ColorContext(new Uri(profilePath)) });
        encoder.Frames.Add(BitmapFrame.Create(image, null, null, profile));
        PanelFiles.WriteAtomically(path, stream =>
        {
            stop.ThrowIfCancellationRequested();
            encoder.Save(stream);
            stop.ThrowIfCancellationRequested();
        });
    }
}
