[CmdletBinding()]
param(
    [string]$GodotPath = $env:GODOT_BIN,
    [string]$PythonPath = 'python'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDirectory = Join-Path $ProjectRoot 'builds\logs'
$ToolsDirectory = Join-Path $ProjectRoot '.tools\quality\venv'
$ToolPython = Join-Path $ToolsDirectory 'Scripts\python.exe'
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
if (-not $GodotPath) {
    $GodotPath = "$env:LOCALAPPDATA\Programs\CodexDevTools\godot\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Run scripts/bootstrap.ps1 or set GODOT_BIN.' }
if ((& $GodotPath --version) -notmatch '^4\.7\.2\.stable') { throw 'Quality checks require Godot 4.7.2 stable.' }
if (-not (Get-Command $PythonPath -ErrorAction SilentlyContinue)) {
    $PythonPath = "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe"
}
if (-not (Get-Command $PythonPath -ErrorAction SilentlyContinue)) { throw 'Python 3.13 is required.' }

function Invoke-QualityTool([string]$Executable, [string[]]$Arguments, [string]$LogName) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = @(& $Executable @Arguments 2>&1); $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $previousPreference }
    $output | ForEach-Object { $_.ToString() } | Tee-Object -FilePath (Join-Path $LogDirectory $LogName)
    if ($code -ne 0) { throw "Quality check failed. See builds/logs/$LogName" }
}

if (-not (Test-Path -LiteralPath $ToolPython)) {
    Invoke-QualityTool $PythonPath @('-m', 'venv', $ToolsDirectory) 'quality-bootstrap.log'
}
$install = @('-m', 'pip', 'install', '--disable-pip-version-check', '--no-deps',
    '-r', (Join-Path $PSScriptRoot 'quality-requirements.lock'))
Invoke-QualityTool $ToolPython $install 'quality-tools.log'
Invoke-QualityTool $ToolPython @('-m', 'pip', 'check') 'quality-dependencies.log'
Invoke-QualityTool $ToolPython @((Join-Path $PSScriptRoot 'quality_static.py')) 'quality-static.log'
$previousGodot = $env:GODOT_BIN
try {
    $env:GODOT_BIN = $GodotPath
    Invoke-QualityTool $ToolPython @((Join-Path $PSScriptRoot 'quality_coverage.py'), '--render') 'quality-coverage.log'
}
finally { $env:GODOT_BIN = $previousGodot }
Write-Output 'Source safety, exact-token duplication, rendered source-line and branch coverage gates passed.'
Write-Output 'Function/statement coverage and SonarQube are not provided; see docs/RELEASE.md#quality-gates.'
