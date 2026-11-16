[CmdletBinding()]
param([string] $ResultsDirectory)
$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (!$ResultsDirectory) { $ResultsDirectory = Join-Path $repo '.test-results' }
. (Join-Path $repo 'ReleaseManifest.ps1')
$root=Join-Path $ResultsDirectory ('manifest-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root)
$count=0
function Assert-Rejected([scriptblock] $action,[string] $name) {
    $threw=$false
    try { & $action | Out-Null } catch { $threw=$true }
    if (!$threw) { throw "FAIL: $name was accepted" }
    $script:count++
}
foreach($relative in Get-ReleaseRuntimeFiles) {
    $file=Join-Path $root $relative
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $file))
    [IO.File]::WriteAllText($file,"inert $relative")
}
$manifest=[ordered]@{schemaVersion=1;kind='build';rendererProtocol=1;parameterContract=('a'*64);files=@(Get-ReleaseRuntimeFiles|ForEach-Object {Get-ReleaseFileRecord $root $_})}
$path=Join-Path $root 'build-manifest.json'
function Save-Manifest { [IO.File]::WriteAllText($path,($manifest|ConvertTo-Json -Depth 5)) }
Save-Manifest
[void](Test-ReleaseManifest $root)
$count++
$renderer=Join-Path $root 'renderer/SpektraStillRenderer.exe'
$old=[IO.File]::ReadAllText($renderer)
[IO.File]::WriteAllText($renderer,'mixed runtime')
Assert-Rejected {Test-ReleaseManifest $root} 'Mixed binary'
[IO.File]::WriteAllText($renderer,$old)
$manifest.rendererProtocol=2; Save-Manifest
Assert-Rejected {Test-ReleaseManifest $root} 'Protocol mismatch'
$manifest.rendererProtocol=1
$files=$manifest.files
$manifest.files=@($files|Select-Object -Skip 1); Save-Manifest
Assert-Rejected {Test-ReleaseManifest $root} 'Missing required panel entry'
$manifest.files=@($files)+@($files[0]); Save-Manifest
Assert-Rejected {Test-ReleaseManifest $root} 'Duplicate file record'
$manifest.files=$files; Save-Manifest
Assert-Rejected {Get-ReleaseFileRecord $root '../outside'} 'Parent traversal'
Assert-Rejected {Get-ReleaseFileRecord $root 'C:\Windows\notepad.exe'} 'Absolute path'
Assert-Rejected {Get-ReleaseFileRecord $root 'stocks.json:stream'} 'Alternate data stream'
$manifest.files[0].sha256='not-a-hash'; Save-Manifest
Assert-Rejected {Test-ReleaseManifest $root} 'Invalid hash'
Write-Output "PASS: $count manifest assertions. Evidence: $root"
