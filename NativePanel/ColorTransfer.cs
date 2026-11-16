using System;

internal enum PreviewInputSpace { Srgb, AdobeRgb, ProPhotoRgb, LinearRec2020 }

// Encoded RGB is retained at the renderer boundary. Spatial resampling must happen
// in linear light, then return to the declared input encoding; alpha is linear.
internal static class ColorTransfer
{
    private const int Steps = 65536;
    private static readonly float[][] DecodeTables = BuildTables(false);
    private static readonly float[][] EncodeTables = BuildTables(true);

    internal static float Decode(float value, PreviewInputSpace space) => Apply(value, space, false);
    internal static float Encode(float value, PreviewInputSpace space) => Apply(value, space, true);

    private static float Apply(float value, PreviewInputSpace space, bool encode)
    {
        if (!float.IsFinite(value)) throw new ArgumentOutOfRangeException(nameof(value));
        if ((uint)space > (uint)PreviewInputSpace.LinearRec2020) throw new ArgumentOutOfRangeException(nameof(space));
        if (space == PreviewInputSpace.LinearRec2020) return value;
        var magnitude = Math.Abs(value);
        // Adobe's pure power curve has an unbounded encode slope at black; a
        // uniformly sampled LUT would crush subtle shadows in this interval.
        if (magnitude > 1 || encode && space == PreviewInputSpace.AdobeRgb && magnitude < 1f / 256)
            return (float)Math.CopySign(Formula(magnitude, space, encode), value);
        var table = (encode ? EncodeTables : DecodeTables)[(int)space];
        var position = magnitude * Steps;
        var lower = Math.Min((int)position, Steps - 1);
        var result = table[lower] + (position - lower) * (table[lower + 1] - table[lower]);
        return MathF.CopySign(result, value);
    }

    private static float[][] BuildTables(bool encode)
    {
        var tables = new float[3][];
        for (var space = 0; space < tables.Length; space++)
        {
            var values = tables[space] = new float[Steps + 1];
            for (var i = 0; i <= Steps; i++)
                values[i] = (float)Formula(i / (double)Steps, (PreviewInputSpace)space, encode);
        }
        return tables;
    }

    private static double Formula(double value, PreviewInputSpace space, bool encode) => (space, encode) switch
    {
        (PreviewInputSpace.Srgb, false) => value <= 0.04045 ? value / 12.92 : Math.Pow((value + 0.055) / 1.055, 2.4),
        (PreviewInputSpace.Srgb, true) => value <= 0.0031308 ? value * 12.92 : 1.055 * Math.Pow(value, 1 / 2.4) - 0.055,
        (PreviewInputSpace.AdobeRgb, false) => Math.Pow(value, 563.0 / 256),
        (PreviewInputSpace.AdobeRgb, true) => Math.Pow(value, 256.0 / 563),
        (PreviewInputSpace.ProPhotoRgb, false) => value <= 1.0 / 32 ? value / 16 : Math.Pow(value, 1.8),
        (PreviewInputSpace.ProPhotoRgb, true) => value <= 1.0 / 512 ? value * 16 : Math.Pow(value, 1 / 1.8),
        _ => value,
    };
}
