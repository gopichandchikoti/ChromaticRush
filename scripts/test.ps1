[CmdletBinding()]
param(
    [string]$GodotPath = $env:GODOT_BIN,
    [string]$PythonPath = 'python'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDirectory = Join-Path $ProjectRoot 'builds\logs'
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
if (-not $GodotPath) {
    $GodotPath = "$env:LOCALAPPDATA\Programs\CodexDevTools\godot\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Run scripts/bootstrap.ps1 or set GODOT_BIN.' }
if ((& $GodotPath --version) -notmatch '^4\.7\.2\.stable') { throw 'Tests require Godot 4.7.2 stable.' }
if (-not (Get-Command $PythonPath -ErrorAction SilentlyContinue)) {
    $PythonPath = "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe"
}
if (-not (Get-Command $PythonPath -ErrorAction SilentlyContinue)) { throw 'Python 3.10+ is required.' }

# Attempts > 1 retries only a non-zero exit with no engine diagnostics: Godot 4.7.2 intermittently
# crashes (access violation) during the first, cold-cache import. Test suites are never retried.
function Invoke-TestTool([string]$Executable, [string[]]$Arguments, [string]$LogName, [int]$Attempts = 1) {
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { $output = @(& $Executable @Arguments 2>&1); $code = $LASTEXITCODE }
        finally { $ErrorActionPreference = $previousPreference }
        $lines = @($output | ForEach-Object { $_.ToString() })
        $lines | Tee-Object -FilePath (Join-Path $LogDirectory $LogName)
        $diagnosed = [bool]($lines -match 'SCRIPT ERROR:|Parse Error:|ERROR:')
        if ($code -eq 0 -and -not $diagnosed) { return }
        if ($diagnosed -or $attempt -eq $Attempts) { throw "Test command failed. See builds/logs/$LogName" }
        Write-Warning "Attempt $attempt exited with code $code and no diagnostics; retrying."
    }
}

Invoke-TestTool $PythonPath @((Join-Path $PSScriptRoot 'validate_levels.py')) 'level-structure.log'
Invoke-TestTool $GodotPath @('--headless', '--editor', '--path', $ProjectRoot, '--import', '--quit') 'test-import.log' 3
$suites = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'tests') -File -Filter 'test_*.gd' | Sort-Object Name)
if ($suites.Count -lt 4) { throw 'Expected gate, run, save and route test suites.' }
foreach ($suite in $suites) {
    $arguments = @(
        '--headless', '--path', $ProjectRoot, '--quit-after', '1800', '--script', "res://tests/$($suite.Name)"
    )
    Invoke-TestTool $GodotPath $arguments "$($suite.BaseName).log"
}
Write-Output "Passed $($suites.Count) native test suites and the independent structural audit."
Write-Output 'Runtime route schedules: docs/evidence/route_audit.json'
