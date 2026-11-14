[CmdletBinding()]
param(
    [string] $CatalogPath,
    [string] $CaptureOnePath,
    [switch] $CheckOnly,
    [switch] $Shortcut
)

$ErrorActionPreference = 'Stop'
$appName = 'Spektrafilm for Capture One'
$appVersion = '16.4.6.2414'
$assemblyHash = '4E17B2AB68CB60CCE18BB92CF0C829A93A62024B15354136FD30A3F9EED2E342'
$userData = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'FilmToolsForCaptureOne'

function Get-CaptureOneExecutable {
    if ($CaptureOnePath) {
        $candidates = @($CaptureOnePath)
    } else {
        $candidates = @(Join-Path $env:ProgramFiles 'Capture One\Capture One\CaptureOne.exe')
        $keys = @(
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\CaptureOne.exe',
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\CaptureOne.exe'
        )
        foreach ($key in $keys) {
            if (Test-Path -LiteralPath $key) {
                $candidate = (Get-Item -LiteralPath $key).GetValue('')
                if ($candidate) { $candidates += $candidate }
            }
        }
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Get-Item -LiteralPath $candidate).FullName
        }
    }
    if ($CaptureOnePath -or $CheckOnly) { throw "Capture One $appVersion could not be found. Pass -CaptureOnePath with the path to CaptureOne.exe." }
    return Select-ExistingFile 'Locate CaptureOne.exe' 'Capture One executable|CaptureOne.exe'
}

function Select-ExistingFile([string] $title, [string] $filter) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    try {
        $dialog.Title = $title
        $dialog.Filter = $filter
        $dialog.RestoreDirectory = $true
        $dialog.CheckFileExists = $true
        $dialog.CheckPathExists = $true
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dialog.FileName }
    } finally {
        $dialog.Dispose()
    }
}

function Confirm-RequiredFile([string] $path) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -eq 0) {
        throw "A release file is missing: $path. Extract the full release ZIP before starting $appName."
    }
}

function Confirm-CatalogIsIdle([string] $path) {
    if (Get-Process -Name CaptureOne -ErrorAction SilentlyContinue) {
        throw "Close every Capture One window before starting $appName."
    }
    foreach ($suffix in @('-wal', '-shm', '-journal')) {
        if (Test-Path -LiteralPath "$path$suffix") {
            throw "Capture One left catalog transaction files. Open the catalog in Capture One normally, close it, then launch $appName again."
        }
    }
}

function Get-CatalogPath([string] $path) {
    $item = Get-Item -LiteralPath $path
    if ($item.PSIsContainer) {
        $databases = @(Get-ChildItem -LiteralPath $item.FullName -File -Filter '*.cocatalogdb')
        if ($databases.Count -ne 1) { throw 'Choose a catalog bundle containing one .cocatalogdb file.' }
        $item = $databases[0]
    }
    if ($item.Extension -ine '.cocatalogdb') { throw 'Choose an existing Capture One .cocatalogdb catalog database.' }
    if (![string]::Equals($item.FullName, (Resolve-Path -LiteralPath $item.FullName).ProviderPath, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Choose the original catalog database path.'
    }
    return $item.FullName
}

function Save-CatalogBackup([string] $path) {
    Confirm-CatalogIsIdle $path
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $encoded = [System.Text.Encoding]::UTF8.GetBytes($path.ToUpperInvariant())
        $key = ([BitConverter]::ToString($sha.ComputeHash($encoded))).Replace('-', '').Substring(0, 20)
    } finally {
        $sha.Dispose()
    }
    $folder = Join-Path (Join-Path $userData 'Catalog backups') $key
    [System.IO.Directory]::CreateDirectory($folder) | Out-Null
    $tempPath = Join-Path $folder ([Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        try {
            $inputDb = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
        } catch [IO.IOException] {
            throw "The catalog is busy. Close the program using it before starting $appName. $($_.Exception.Message)"
        }
        try {
            Confirm-CatalogIsIdle $path
            $header = New-Object byte[] 16
            if ($inputDb.Read($header, 0, $header.Length) -ne $header.Length -or
                [Text.Encoding]::ASCII.GetString($header) -cne "SQLite format 3`0") {
                throw 'The selected catalog database does not have a valid SQLite header.'
            }
            $inputDb.Position = 0
            $outputDb = [IO.File]::Open($tempPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try { $inputDb.CopyTo($outputDb); $outputDb.Flush($true) }
            finally { $outputDb.Dispose() }
            Confirm-CatalogIsIdle $path
        } finally {
            $inputDb.Dispose()
        }
        $name = [IO.Path]::GetFileNameWithoutExtension($path)
        $existing = @(Get-ChildItem -LiteralPath $folder -Filter '*.cocatalogdb' -File | Sort-Object LastWriteTimeUtc -Descending)
        if ($existing.Count -gt 0 -and $existing[0].Length -eq (Get-Item -LiteralPath $tempPath).Length -and
            (Get-FileHash -LiteralPath $tempPath -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $existing[0].FullName -Algorithm SHA256).Hash) {
            return $existing[0].FullName
        }
        $time = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff', [Globalization.CultureInfo]::InvariantCulture)
        $destination = Join-Path $folder "$name-$time.cocatalogdb"
        [IO.File]::Move($tempPath, $destination)
        foreach ($older in @($existing | Select-Object -Skip 4)) {
            try { Remove-Item -LiteralPath $older.FullName -ErrorAction Stop }
            catch { Write-Warning "Could not remove an older backup at $($older.FullName)." }
        }
        return $destination
    } finally {
        if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath }
    }
}

function Confirm-VulkanRenderer([string] $renderer) {
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = $renderer
    $start.Arguments = '1 1'
    $start.WorkingDirectory = Split-Path -LiteralPath $renderer
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    [void] $start.EnvironmentVariables.Remove('DOTNET_STARTUP_HOOKS')
    $process = [Diagnostics.Process]::Start($start)
    try {
        $output = New-Object IO.MemoryStream
        try {
            $stdout = $process.StandardOutput.BaseStream.CopyToAsync($output)
            $stderr = $process.StandardError.ReadToEndAsync()
            $pixel = New-Object byte[] 16
            [Array]::Copy([BitConverter]::GetBytes([single] 1), 0, $pixel, 12, 4)
            $process.StandardInput.BaseStream.Write($pixel, 0, $pixel.Length)
            $process.StandardInput.Close()
            if (!$process.WaitForExit(20000)) { throw 'The Vulkan renderer did not return a test pixel in 20 seconds.' }
            [void] $stdout.GetAwaiter().GetResult()
            $detail = $stderr.GetAwaiter().GetResult().Trim()
            if ($process.ExitCode -ne 0 -or $output.Length -ne 16) {
                throw "The Vulkan renderer could not run on this computer. $detail"
            }
            for ($offset = 0; $offset -lt 16; $offset += 4) {
                $value = [BitConverter]::ToSingle($output.GetBuffer(), $offset)
                if ([single]::IsNaN($value) -or [single]::IsInfinity($value)) { throw 'The Vulkan renderer returned an invalid test pixel.' }
            }
        } finally {
            $output.Dispose()
        }
    } finally {
        if (!$process.HasExited) { $process.Kill() }
        $process.Dispose()
    }
}

try {
    if (![Environment]::Is64BitOperatingSystem) { throw "$appName requires 64-bit Windows." }
    $app = Get-CaptureOneExecutable
    if (!$app) { return }
    if ([IO.Path]::GetFileName($app) -ine 'CaptureOne.exe') { throw 'Select CaptureOne.exe from the Capture One installation.' }
    $appDirectory = Split-Path -LiteralPath $app
    $appAssembly = Join-Path $appDirectory 'CaptureOne.dll'
    if (!(Test-Path -LiteralPath $appAssembly -PathType Leaf) -or
        (Get-FileHash -LiteralPath $appAssembly -Algorithm SHA256).Hash -ne $assemblyHash -or
        (Get-Item -LiteralPath $app).VersionInfo.FileVersion -ne $appVersion) {
        throw "$appName supports Capture One $appVersion (Windows x64). The selected installation does not match the verified build."
    }

    $hook = Join-Path $PSScriptRoot 'panel\NativePanel.dll'
    $renderer = Join-Path $PSScriptRoot 'renderer\SpektraStillRenderer.exe'
    Confirm-RequiredFile $hook
    Confirm-RequiredFile $renderer
    foreach ($file in @('stocks.json', 'profiles\preview\Linear Rec.2020.icc', 'profiles\preview\ProPhoto RGB.icc',
        'renderer\SpektraHanatos2025Spectra.f32', 'renderer\SpektraOutputGamutCompression.f32')) {
        Confirm-RequiredFile (Join-Path $PSScriptRoot $file)
    }
    foreach ($shader in @('Copy','CurveDevelop','Diffusion','Dir','FilmExposure','FormatConvert','Grain','Halation','PrintScan','ScannerPost')) {
        Confirm-RequiredFile (Join-Path $PSScriptRoot "renderer\shaders\Spektra$shader.comp.spv")
    }

    $python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
    if (!(Test-Path -LiteralPath $python -PathType Leaf)) { $python = $null }
    if ($CheckOnly) {
        Confirm-VulkanRenderer $renderer
        Write-Output "Capture One $appVersion matches the supported build. Release files and Vulkan render passed."
        if ($python) { Write-Output "Optional LUT Python found at $python" }
        else { Write-Output 'Optional LUT Python is not installed.' }
        return
    }

    if (Get-Process -Name CaptureOne -ErrorAction SilentlyContinue) { throw "Close every Capture One window before starting $appName." }
    if (!$CatalogPath) { $CatalogPath = Select-ExistingFile 'Choose an existing Capture One catalog database' 'Capture One catalog database|*.cocatalogdb' }
    if (!$CatalogPath) { return }
    $database = Get-CatalogPath $CatalogPath
    $backup = Save-CatalogBackup $database
    Confirm-CatalogIsIdle $database
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = $app
    # Windows file paths cannot contain double quotes and this is always a file, not a trailing directory path.
    $start.Arguments = '"' + $database + '"'
    $start.UseShellExecute = $false
    $start.WorkingDirectory = $appDirectory
    foreach ($name in @($start.EnvironmentVariables.Keys)) {
        if ($name -like 'SPEKTRAFILM_VERIFY_*' -or $name -like 'SPEKTRAFILM_TEST_*') {
            [void] $start.EnvironmentVariables.Remove($name)
        }
    }
    $start.EnvironmentVariables['DOTNET_STARTUP_HOOKS'] = $hook
    $start.EnvironmentVariables['SPEKTRAFILM_ROOT'] = $PSScriptRoot
    $start.EnvironmentVariables['SPEKTRAFILM_CATALOG'] = $database
    $start.EnvironmentVariables['SPEKTRAFILM_PANEL_LOG'] = Join-Path $userData 'panel.log'
    if ($python) { $start.EnvironmentVariables['SPEKTRAFILM_PYTHON'] = $python }
    else { [void] $start.EnvironmentVariables.Remove('SPEKTRAFILM_PYTHON') }
    $process = [Diagnostics.Process]::Start($start)
    try { Write-Output "Started Capture One ($($process.Id)). Catalog backup: $backup" }
    finally { $process.Dispose() }
} catch {
    $message = $_.Exception.Message
    [Console]::Error.WriteLine("${appName}: $message")
    if ($Shortcut) {
        Add-Type -AssemblyName System.Windows.Forms
        [void] [System.Windows.Forms.MessageBox]::Show($message, $appName,
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    exit 1
}
