using System.Collections.Generic;
using System.Text.Json.Serialization;

internal sealed record LookSettings([property: JsonRequired] string Film, [property: JsonRequired] string Paper,
    [property: JsonRequired] double Exposure, [property: JsonRequired] double PrintExposure, [property: JsonRequired] double Strength,
    [property: JsonRequired] string Mode, [property: JsonRequired] string SpectralMethod,
    [property: JsonRequired] bool ScanInvert, [property: JsonRequired] Dictionary<string, double> Development,
    string FilmPushPullMode = "standard");
