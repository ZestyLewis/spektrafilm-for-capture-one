[CmdletBinding()]
param([string] $ResultsDirectory)
$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (!$ResultsDirectory) { $ResultsDirectory=Join-Path $repo '.test-results' }
$ResultsDirectory=[IO.Path]::GetFullPath($ResultsDirectory)
$fixture=Join-Path $ResultsDirectory ('runner-environment-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$probe=Join-Path $fixture 'Probe.ps1'
$output=Join-Path $fixture 'environment.json'
$marker=Join-Path $fixture 'inherited-PS7-module-path'
# Load the real launcher function, not a copy of the environment policy.
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'Test-Windows.ps1'),[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw 'Test runner syntax failed.' }
$definition=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-Test'},$true)
if (!$definition) { throw 'Production test process launcher is missing.' }
. ([scriptblock]::Create($definition.Extent.Text))
$results=New-Object 'System.Collections.Generic.List[object]'
[IO.File]::WriteAllText($probe,@'
param([string] $OutputPath,[string] $Marker)
$ErrorActionPreference='Stop'
$hash=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
$data=[ordered]@{major=$PSVersionTable.PSVersion.Major;hashLength=$hash.Length;poisonInherited=$env:PSModulePath.Contains($Marker)}
[IO.File]::WriteAllText($OutputPath,($data|ConvertTo-Json -Compress))
'@)
$parentPath=$env:PSModulePath
$poisonedPath=$marker+';'+$parentPath
try {
    $env:PSModulePath=$poisonedPath
    $powershell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    Invoke-Test 'runner-environment-probe' $powershell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$probe,'-OutputPath',$output,'-Marker',$marker)
    if ($env:PSModulePath -cne $poisonedPath) { throw 'Production child launch changed its parent module path.' }
    $observed=[IO.File]::ReadAllText($output)|ConvertFrom-Json
    if ($observed.major -ne 5) { throw 'Probe did not use Windows PowerShell5.' }
    if ($observed.hashLength -ne 64) { throw 'Windows PowerShell built-in Get-FileHash is unavailable.' }
    if ($observed.poisonInherited) { throw 'Windows PowerShell inherited the parent module-path override.' }
    if ($results.Count -ne 1 -or $results[0].exitCode -ne 0) { throw 'Production runner did not record successful probe completion.' }
} finally { $env:PSModulePath=$parentPath }
if ($env:PSModulePath -cne $parentPath) { throw 'Fixture did not restore its parent environment.' }
Write-Output "PASS: 6 runner environment assertions. Evidence: $fixture"
