[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+([.-][a-zA-Z0-9.]+)?$')]
    [string] $Version
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dist = Join-Path $root 'dist'
$archiveName = "Film-Tools-for-Capture-One-v$Version-windows-x64.zip"
$archive = Join-Path $dist $archiveName
$stage = Join-Path $dist ('stage-' + [Guid]::NewGuid().ToString('N'))
$package = Join-Path $stage 'Film Tools for Capture One'
$files = @(
    'Install Film Tools.cmd', 'Install-FilmTools.ps1', 'Start Film Tools.cmd', 'Start-FilmTools.ps1',
    'Setup LUT Export.cmd', 'Setup-LutExport.ps1', 'lut_worker.py', 'requirements-lut.txt',
    'README.md', 'LICENSE', 'THIRD-PARTY.md', 'UPSTREAM-CHANGES.md', 'stocks.json',
    'assets\FilmTools.ico', 'assets\FilmTools.png', 'panel\NativePanel.dll',
    'profiles\preview\Linear Rec.2020.icc', 'profiles\preview\ProPhoto RGB.icc',
    'renderer\SpektraStillRenderer.exe', 'renderer\SpektraHanatos2025Spectra.f32',
    'renderer\SpektraOutputGamutCompression.f32', 'upstream-ofx\LICENSE.txt',
    'upstream-ofx\Legal\THIRD_PARTY_NOTICES.txt', 'upstream-ofx\Legal\SPEKTRAFILM_OFX_LICENSE.txt',
    'upstream-ofx\Legal\SPEKTRAFILM_OFX_LUT_LICENSE.txt'
)
$shaders = 'Copy', 'CurveDevelop', 'Diffusion', 'Dir', 'FilmExposure', 'FormatConvert', 'Grain', 'Halation', 'PrintScan', 'ScannerPost'
$files += $shaders | ForEach-Object { "renderer\shaders\Spektra$_.comp.spv" }
$files += 'upstream-spektrafilm\LICENSE', 'upstream-spektrafilm\SPEKTRAFILM_LICENSE.txt',
    'upstream-spektrafilm\CITATION.cff', 'upstream-spektrafilm\README.md'
$pythonSource = Join-Path $root 'upstream-spektrafilm\src\spektrafilm'
$pythonFiles = Get-ChildItem -LiteralPath $pythonSource -Recurse -File |
    Where-Object { $_.Extension -in '.py', '.json', '.npy', '.csv', '.lut', '.txt', '.md' -and $_.FullName -notmatch '[\\/]__pycache__[\\/]' }
$files += $pythonFiles | ForEach-Object { $_.FullName.Substring($root.Length + 1) }

try {
    foreach ($relative in $files) {
        $source = Get-Item -LiteralPath (Join-Path $root $relative)
        if ($source.PSIsContainer -or ($source.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Expected an ordinary file at $relative"
        }
        $destination = Join-Path $package $relative
        [void] [IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        [IO.File]::Copy($source.FullName, $destination)
    }
    $sourceUrl = "https://github.com/nothing-complex/film-tools-for-capture-one/tree/v$Version"
    @(
        "Film Tools for Capture One v$Version"
        "Corresponding source and build instructions"
        $sourceUrl
    ) | Set-Content -LiteralPath (Join-Path $package 'SOURCE.txt') -Encoding ascii
    $temporaryArchive = Join-Path $stage $archiveName
    Compress-Archive -LiteralPath $package -DestinationPath $temporaryArchive -CompressionLevel Optimal
    Move-Item -LiteralPath $temporaryArchive -Destination $archive -Force
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $archiveName" | Set-Content -LiteralPath "$archive.sha256" -Encoding ascii
    Write-Output $archive
} finally {
    if (Test-Path -LiteralPath $stage -PathType Container) {
        $stageItem = Get-Item -LiteralPath $stage
        $distItem = Get-Item -LiteralPath $dist
        if ($stageItem.Parent.FullName -eq $distItem.FullName -and
            $stageItem.Name -match '^stage-[a-f0-9]{32}$' -and
            !(($stageItem.Attributes -bor $distItem.Attributes) -band [IO.FileAttributes]::ReparsePoint)) {
            Remove-Item -LiteralPath $stageItem.FullName -Recurse -Force
        }
    }
}
