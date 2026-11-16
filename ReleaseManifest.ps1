# Shared build/package integrity checks. Compatible with Windows PowerShell 5.1.
function Get-ReleaseRuntimeFiles {
    $paths = @('panel/NativePanel.dll','renderer/SpektraStillRenderer.exe',
        'renderer/SpektraHanatos2025Spectra.f32','renderer/SpektraOutputGamutCompression.f32',
        'stocks.json','profiles/preview/Linear Rec.2020.icc','profiles/preview/ProPhoto RGB.icc')
    foreach ($shader in @('Copy','CurveDevelop','Diffusion','Dir','FilmExposure','FormatConvert','Grain','Halation','PrintScan','ScannerPost')) {
        $paths += "renderer/shaders/Spektra$shader.comp.spv"
    }
    return $paths
}

function Get-ReleaseFileRecord([string] $Root, [string] $Relative) {
    $base = [IO.Path]::GetFullPath($Root).TrimEnd('\','/')
    if ([IO.Path]::IsPathRooted($Relative) -or $Relative.Contains(':') -or $Relative -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "Invalid manifest path: $Relative"
    }
    $path = [IO.Path]::GetFullPath((Join-Path $base $Relative))
    if (!$path.StartsWith($base + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Manifest path escapes its root: $Relative" }
    $file = Get-Item -LiteralPath $path -Force
    if ($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Expected plain manifest file: $Relative" }
    $parent = $file.Directory
    while ($parent -and ![string]::Equals($parent.FullName,$base,[StringComparison]::OrdinalIgnoreCase)) {
        if ($parent.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked manifest directory: $Relative" }
        $parent = $parent.Parent
    }
    return [ordered]@{ path=$Relative.Replace('\','/'); bytes=$file.Length; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
}

function Get-ReleaseSourceIdentity([string] $Root) {
    $commit = & git -C $Root rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Build provenance requires a Git checkout.' }
    $dirty = [bool](& git -C $Root status --porcelain=v1)
    $paths = @(& git -C $Root -c core.quotepath=false ls-files --cached --others --exclude-standard)
    if ($LASTEXITCODE -ne 0) { throw 'Could not enumerate source files.' }
    $records = @($paths | Sort-Object -Unique | ForEach-Object { Get-ReleaseFileRecord $Root $_ })
    $identityText = ($records | ForEach-Object { $_.path + ':' + $_.sha256 }) -join "`n"
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $digest=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($identityText)))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
    return [ordered]@{ commit=$commit.Trim(); dirty=$dirty; treeDigest=$digest }
}

function Test-ReleaseManifest([string] $Root, [string] $Name = 'build-manifest.json') {
    $record = Get-ReleaseFileRecord $Root $Name
    if ($record.bytes -gt 8MB) { throw 'Release manifest is too large.' }
    $manifest = [IO.File]::ReadAllText((Join-Path $Root $Name)) | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 1 -or @($manifest.files).Count -eq 0) { throw "Unsupported or empty $Name." }
    $seen = @{}
    foreach ($expected in $manifest.files) {
        if ($expected.path -isnot [string] -or $expected.sha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid release file record.' }
        $key = $expected.path.Replace('\','/')
        if ($seen.ContainsKey($key)) { throw "Duplicate manifest path: $key" }
        $seen[$key]=$expected
        $actual=Get-ReleaseFileRecord $Root $expected.path
        if ($actual.bytes -ne $expected.bytes -or $actual.sha256 -ne $expected.sha256) { throw "Release file does not match its build: $($expected.path). Extract or rebuild the complete release." }
    }
    if ($Name -eq 'build-manifest.json') {
        if ($manifest.kind -ne 'build' -or $manifest.rendererProtocol -ne 1 -or $manifest.parameterContract -notmatch '^[a-fA-F0-9]{64}$') {
            throw 'The renderer build contract is missing or incompatible.'
        }
        foreach ($required in Get-ReleaseRuntimeFiles) {
            if (!$seen.ContainsKey($required)) { throw "Build manifest omits $required." }
            if ($seen[$required].bytes -le 0) { throw "Build manifest has an empty runtime file: $required." }
        }
    }
    return $manifest
}

function Write-ReleaseBuildManifest([string] $Root, $SourceIdentity, [string] $CaptureOneDirectory, [string] $SmokeStatus, [string] $PythonPath, [string] $VulkanSdkPath) {
    $hostFiles = @('CaptureOne.dll','P1.AppCore.dll','P1.C1.Core.dll','P1.C1.Framework.dll','P1.C1.ImageCoreWrapper.dll','P1.C1.ModelEntities.dll','P1.C1.ViewModels.dll')
    $hostRecords = @($hostFiles | ForEach-Object { Get-ReleaseFileRecord $CaptureOneDirectory $_ })
    $manifest = [ordered]@{
        schemaVersion=1; kind='build'; createdUtc=[DateTime]::UtcNow.ToString('o'); source=$SourceIdentity
        rendererProtocol=1
        parameterContract=(Get-FileHash -LiteralPath (Join-Path $Root 'upstream-ofx/src/SpektraParameters.h') -Algorithm SHA256).Hash.ToLowerInvariant()
        host=[ordered]@{ version=(Get-Item -LiteralPath (Join-Path $CaptureOneDirectory 'CaptureOne.exe')).VersionInfo.FileVersion; files=$hostRecords }
        tools=[ordered]@{ dotnet=(& dotnet --version); cmake=((& cmake --version | Select-Object -First 1)); python=(& $PythonPath --version); vulkanSdk=$VulkanSdkPath }
        validation=[ordered]@{ rendererSmoke=$SmokeStatus; panelBuild='passed' }
        files=@(Get-ReleaseRuntimeFiles | ForEach-Object { Get-ReleaseFileRecord $Root $_ })
    }
    $destination = Join-Path $Root 'build-manifest.json'
    $temporary = $destination + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    [IO.File]::WriteAllText($temporary,($manifest | ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
    try { Move-Item -LiteralPath $temporary -Destination $destination -Force }
    finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
    [void](Test-ReleaseManifest $Root)
    Write-Output $destination
}
