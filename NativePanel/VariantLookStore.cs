using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;

internal sealed record GrainControls(int Type, double Impact, double Granularity);
internal sealed record VariantLook(LookSettings Look, SpatialPreview.Settings Optics, bool Enabled, int Version = 1, GrainControls? Grain = null);

internal sealed class VariantLookStore(string root, string catalogDatabase)
{
    private readonly string directory = Path.Combine(root, CatalogKey(catalogDatabase));
    private readonly Dictionary<Guid, VariantLook> pending = new();

    internal VariantLook? Read(Guid variant)
    {
        if (pending.TryGetValue(variant, out var edit))
            return edit;
        try
        {
            var saved = PanelFiles.ReadPreset<VariantLook>(GetPath(variant));
            if (saved.Version != 1 || saved.Look is null || saved.Optics is null)
                throw new InvalidDataException("The saved Film Tools look has an unsupported format.");
            return saved;
        }
        catch (FileNotFoundException) { return null; }
        catch (DirectoryNotFoundException) { return null; }
    }

    internal void Queue(Guid variant, VariantLook look) => pending[variant] = look;

    internal void Flush()
    {
        if (pending.Count == 0)
            return;
        Directory.CreateDirectory(directory);
        foreach (var variant in pending.Keys)
        {
            PanelFiles.WritePreset(GetPath(variant), pending[variant]);
            pending.Remove(variant);
        }
    }

    private string GetPath(Guid variant) => Path.Combine(directory, variant.ToString("N") + ".json");

    private static string CatalogKey(string database)
    {
        var normalized = Path.GetFullPath(database).ToUpperInvariant();
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(normalized)));
    }
}
