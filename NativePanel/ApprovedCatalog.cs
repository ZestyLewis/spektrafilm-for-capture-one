using System;
using System.IO;
using System.Linq;

internal static class ApprovedCatalog
{
    internal static string? SelectedDatabase { get; } = GetSelectedDatabase();

    internal static bool HasSelection => SelectedDatabase is not null;

    internal static bool IsApproved(string? activePath)
    {
        if (SelectedDatabase is null || string.IsNullOrWhiteSpace(activePath) || !Path.IsPathFullyQualified(activePath))
            return false;

        try
        {
            var active = Path.TrimEndingDirectorySeparator(Path.GetFullPath(activePath));
            if (Matches(active, SelectedDatabase))
                return true;
            if (!Matches(active, Path.GetDirectoryName(SelectedDatabase)))
                return false;

            // Capture One can return a catalog's directory instead of its database.
            // Match that form only when it identifies the one opted-in database.
            var databases = Directory.EnumerateFiles(active, "*.cocatalogdb")
                .Where(IsCatalogDatabase).Take(2).ToArray();
            return databases.Length == 1 && Matches(databases[0], SelectedDatabase);
        }
        catch (Exception error) when (error is ArgumentException or IOException or UnauthorizedAccessException or NotSupportedException)
        {
            return false;
        }
    }

    private static string? GetSelectedDatabase()
    {
        var configured = Environment.GetEnvironmentVariable("SPEKTRAFILM_CATALOG");
        if (string.IsNullOrWhiteSpace(configured) || !Path.IsPathFullyQualified(configured))
            return null;
        try
        {
            var path = Path.GetFullPath(configured);
            return IsCatalogDatabase(path) && File.Exists(path) ? path : null;
        }
        catch (Exception error) when (error is ArgumentException or IOException or UnauthorizedAccessException or NotSupportedException)
        {
            return null;
        }
    }

    private static bool IsCatalogDatabase(string path) => Matches(Path.GetExtension(path), ".cocatalogdb");
    private static bool Matches(string? first, string? second) =>
        string.Equals(first, second, StringComparison.OrdinalIgnoreCase);
}
