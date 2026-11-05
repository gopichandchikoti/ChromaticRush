[CmdletBinding()]
param(
    [string]$GodotPath = $env:GODOT_BIN,
    [string]$PythonPath = 'python',
    [switch]$Format
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDirectory = Join-Path $ProjectRoot 'builds\logs'
$ToolsDirectory = Join-Path $ProjectRoot '.tools\lint'
$ToolPython = Join-Path $ToolsDirectory 'Scripts\python.exe'
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
if (-not $GodotPath) {
    $GodotPath = "$env:LOCALAPPDATA\Programs\CodexDevTools\godot\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Run scripts/bootstrap.ps1 or set GODOT_BIN.' }
if ((& $GodotPath --version) -notmatch '^4\.7\.2\.stable') { throw 'Checks require Godot 4.7.2 stable.' }
if (-not (Get-Command $PythonPath -ErrorAction SilentlyContinue)) {
    $PythonPath = "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe"
}
if (-not (Get-Command $PythonPath -ErrorAction SilentlyContinue)) { throw 'Python 3.10+ is required.' }

$ToolLock = Join-Path $ProjectRoot 'requirements-dev.lock'

# Attempts > 1 retries only a non-zero exit with no engine diagnostics: Godot 4.7.2 intermittently
# crashes (access violation) during the first, cold-cache import. Reported errors are never retried.
function Invoke-CheckTool([string]$Executable, [string[]]$Arguments, [string]$LogName, [int]$Attempts = 1) {
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { $output = @(& $Executable @Arguments 2>&1); $code = $LASTEXITCODE }
        finally { $ErrorActionPreference = $previousPreference }
        $lines = @($output | ForEach-Object { $_.ToString() })
        $lines | Tee-Object -FilePath (Join-Path $LogDirectory $LogName)
        $diagnosed = [bool]($lines -match 'SCRIPT ERROR:|Parse Error:|ERROR:')
        if ($code -eq 0 -and -not $diagnosed) { return }
        if ($diagnosed -or $attempt -eq $Attempts) { throw "Check failed. See builds/logs/$LogName" }
        Write-Warning "Attempt $attempt exited with code $code and no diagnostics; retrying."
    }
}

if (-not (Test-Path -LiteralPath $ToolPython)) {
    Invoke-CheckTool $PythonPath @('-m', 'venv', $ToolsDirectory) 'lint-bootstrap.log'
}
$installArguments = @('-m', 'pip', 'install', '--disable-pip-version-check', '--no-deps', '-r', $ToolLock)
Invoke-CheckTool $ToolPython $installArguments 'lint-tools.log'
$GdLint = Join-Path $ToolsDirectory 'Scripts\gdlint.exe'
$GdFormat = Join-Path $ToolsDirectory 'Scripts\gdformat.exe'
$SourcePaths = @((Join-Path $ProjectRoot 'src'), (Join-Path $ProjectRoot 'tests'))
Push-Location -LiteralPath $ProjectRoot
try {
    if ($Format) {
        Invoke-CheckTool $GdFormat (@('--line-length', '120') + $SourcePaths) 'format.log'
    }
    Invoke-CheckTool $GdFormat (@('--check', '--line-length', '120') + $SourcePaths) 'format-check.log'
    Invoke-CheckTool $GdLint $SourcePaths 'lint.log'
}
finally { Pop-Location }
$PythonScripts = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter '*.py' |
    Sort-Object Name | Select-Object -ExpandProperty FullName)
Invoke-CheckTool $PythonPath (@('-m', 'py_compile') + $PythonScripts) 'python-check.log'
Invoke-CheckTool $PythonPath @((Join-Path $PSScriptRoot 'validate_levels.py')) 'level-structure.log'
$importArguments = @('--headless', '--editor', '--path', $ProjectRoot, '--import', '--quit')
Invoke-CheckTool $GodotPath $importArguments 'static-import.log' 3
Write-Output 'Formatting, lint, Python validation, level schema and native GDScript import checks passed.'
