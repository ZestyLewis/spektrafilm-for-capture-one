using System;
using System.Collections.Generic;
using System.IO;

internal sealed record FloatingPlacement(double Left, double Top, double Width, double Height)
{
    internal bool IsValid => double.IsFinite(Left) && double.IsFinite(Top) && double.IsFinite(Width)
        && double.IsFinite(Height) && Width is >= 200 and <= 5000 && Height is >= 100 and <= 10000;
}

internal sealed record PanelPreferenceData(int Version = 1, string ViewerSize = "native", int DragSize = 1200,
    bool DraftSynthesis = false, FloatingPlacement? Floating = null, Dictionary<string, bool>? Sections = null);

internal static class PanelPreferences
{
    private static readonly string Pathname = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "FilmToolsForCaptureOne", "Panel preferences.json");
    private static bool writable = true;
    internal static PanelPreferenceData Current { get; private set; } = Read();

    private static PanelPreferenceData Read()
    {
        try
        {
            if (!File.Exists(Pathname)) return new();
            var preferences = PanelFiles.ReadPreset<PanelPreferenceData>(Pathname);
            if (preferences.Version != 1) throw new InvalidDataException("Panel preferences are from a newer version.");
            return preferences;
        }
        catch (Exception error)
        {
            // Keep unknown/corrupt preferences untouched; image state is independent.
            writable = false;
            StartupHook.Log("Panel preferences could not be loaded: " + error.GetBaseException().Message);
            return new();
        }
    }

    internal static void Update(Func<PanelPreferenceData, PanelPreferenceData> edit)
    {
        var next = edit(Current);
        if (next == Current) return;
        Current = next;
        if (!writable) return;
        try
        {
            Directory.CreateDirectory(System.IO.Path.GetDirectoryName(Pathname)!);
            PanelFiles.WritePreset(Pathname, next);
        }
        catch (Exception error) { StartupHook.Log("Panel preferences could not be saved: " + error.GetBaseException().Message); }
    }
}
