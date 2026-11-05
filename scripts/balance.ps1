[CmdletBinding()]
param(
    [string]$GodotPath = $env:GODOT_BIN,
    [switch]$RenderBenchmark,
    [switch]$Stress
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDirectory = Join-Path $ProjectRoot 'builds\logs'
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
if (-not $GodotPath) {
    $GodotPath = "$env:LOCALAPPDATA\Programs\CodexDevTools\godot\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Run scripts/bootstrap.ps1 or set GODOT_BIN.' }

function Invoke-BalanceTool([string[]]$Arguments, [string]$LogName) {
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = @(& $GodotPath @Arguments 2>&1); $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $savedPreference }
    $lines = @($output | ForEach-Object { $_.ToString() })
    $lines | Tee-Object -FilePath (Join-Path $LogDirectory $LogName)
    if ($code -ne 0 -or ($lines -match 'SCRIPT ERROR:|Parse Error:|ERROR:')) {
        throw "Balance command failed. See builds/logs/$LogName"
    }
}

Invoke-BalanceTool @('--headless', '--path', $ProjectRoot, '--script', 'res://tests/balance_routes.gd') 'balance-routes.log'
Invoke-BalanceTool @('--headless', '--path', $ProjectRoot, '--script', 'res://tests/balance_precision.gd') 'balance-precision.log'
if ($RenderBenchmark) {
    $arguments = @('--path', $ProjectRoot, '--script', 'res://tests/benchmark_render.gd')
    if ($Stress) { $arguments += @('--', '--stress') }
    Invoke-BalanceTool $arguments 'balance-render.log'
}
