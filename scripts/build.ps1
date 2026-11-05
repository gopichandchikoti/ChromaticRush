[CmdletBinding()]
param(
    [ValidateSet('All', 'Android', 'Windows')][string]$Target = 'All',
    [string]$GodotPath = $env:GODOT_BIN,
    [string]$AndroidSdkPath = $env:ANDROID_HOME,
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$SigningDirectory = "$env:USERPROFILE\Documents\Codex\signing\ChromaticRush",
    [switch]$SignedAndroidRelease
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildDirectory = Join-Path $ProjectRoot 'builds'
$LogDirectory = Join-Path $BuildDirectory 'logs'
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
if (-not $GodotPath) {
    $GodotPath = "$env:LOCALAPPDATA\Programs\CodexDevTools\godot\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Run scripts/bootstrap.ps1 or set GODOT_BIN.' }
if ((& $GodotPath --version) -notmatch '^4\.7\.2\.stable') { throw 'Builds are pinned to Godot 4.7.2 stable.' }

# Attempts > 1 retries only a non-zero exit with no engine diagnostics: Godot 4.7.2 intermittently
# crashes (access violation) during the first, cold-cache import. Exports are never retried.
function Invoke-Godot([string[]]$Arguments, [string]$LogName, [int]$Attempts = 1) {
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { $output = @(& $GodotPath @Arguments 2>&1); $code = $LASTEXITCODE }
        finally { $ErrorActionPreference = $previousPreference }
        $lines = @($output | ForEach-Object { $_.ToString() })
        $lines | Tee-Object -FilePath (Join-Path $LogDirectory $LogName)
        $diagnosed = [bool]($lines -match 'SCRIPT ERROR:|Parse Error:|ERROR:')
        if ($code -eq 0 -and -not $diagnosed) { return }
        if ($diagnosed -or $attempt -eq $Attempts) { throw "Godot failed. See builds/logs/$LogName" }
        Write-Warning "Attempt $attempt exited with code $code and no diagnostics; retrying."
    }
}

function Set-AndroidEnvironment {
    if (-not $script:AndroidSdkPath) {
        $candidates = @("$env:LOCALAPPDATA\Android\Sdk", "$env:USERPROFILE\Documents\Codex\android-sdk")
        $script:AndroidSdkPath = $candidates | Where-Object {
            Test-Path -LiteralPath (Join-Path $_ 'platform-tools\adb.exe')
        } | Select-Object -First 1
    }
    if (-not $script:JavaHome) {
        $jdkRoot = "$env:USERPROFILE\Documents\Codex\tools\jdk"
        if (Test-Path -LiteralPath $jdkRoot) {
            $script:JavaHome = Get-ChildItem -LiteralPath $jdkRoot -Directory -Filter 'jdk-17*' |
                Select-Object -First 1 -ExpandProperty FullName
        }
    }
    if (-not $script:AndroidSdkPath -or -not (Test-Path -LiteralPath "$script:AndroidSdkPath\platform-tools\adb.exe")) {
        throw 'Set ANDROID_HOME or pass -AndroidSdkPath (directory containing platform-tools/adb.exe).'
    }
    if (-not $script:JavaHome -or -not (Test-Path -LiteralPath "$script:JavaHome\bin\java.exe")) {
        throw 'Set JAVA_HOME or pass -JavaHome (JDK 17 recommended).'
    }
    $engineDirectory = Split-Path -Parent $GodotPath
    if (-not (Test-Path -LiteralPath (Join-Path $engineDirectory '_sc_'))) {
        throw 'Run bootstrap.ps1 first: export uses an isolated self-contained Godot profile.'
    }
    $settingsDirectory = Join-Path $engineDirectory 'editor_data'
    New-Item -ItemType Directory -Path $settingsDirectory -Force | Out-Null
    $java = $script:JavaHome.Replace('\', '/')
    $sdk = $script:AndroidSdkPath.Replace('\', '/')
    $settings = @"
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "$java"
export/android/android_sdk_path = "$sdk"
"@
    [IO.File]::WriteAllText((Join-Path $settingsDirectory 'editor_settings-4.7.tres'), $settings)
    $env:JAVA_HOME = $script:JavaHome
    $env:ANDROID_HOME = $script:AndroidSdkPath
}

function Write-ArtifactHash([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing expected artifact: $Path" }
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText("$Path.sha256", "$hash *$([IO.Path]::GetFileName($Path))`n")
    Write-Output "Artifact: $Path"
    Write-Output "SHA256: $hash"
}

if ($Target -in @('All', 'Android')) { Set-AndroidEnvironment }
Invoke-Godot @('--headless', '--path', $ProjectRoot, '--import') 'import.log' 3
if ($Target -in @('All', 'Windows')) {
    $path = Join-Path $BuildDirectory 'ChromaticRush-1.0.0.exe'
    Invoke-Godot @('--headless', '--path', $ProjectRoot, '--export-release', 'Windows Desktop', $path) 'windows.log'
    Write-ArtifactHash $path
}
if ($Target -in @('All', 'Android')) {
    $mode = '--export-debug'
    $name = 'chromatic-rush-1.0.0-debug.apk'
    if ($SignedAndroidRelease) {
        $keystore = Join-Path $SigningDirectory 'chromatic-rush-release.jks'
        $passwordFile = Join-Path $SigningDirectory 'release-password.txt'
        if (-not $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH -and
            (Test-Path -LiteralPath $keystore) -and (Test-Path -LiteralPath $passwordFile)) {
            $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $keystore
            $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = 'chromaticrush'
            $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = [IO.File]::ReadAllText($passwordFile).Trim()
        }
        if (-not $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH -or -not $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER -or
            -not $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD) {
            throw 'Set all GODOT_ANDROID_KEYSTORE_RELEASE_* variables using your private keystore.'
        }
        $mode = '--export-release'
        $name = 'chromatic-rush-1.0.0-release.apk'
    }
    $path = Join-Path $BuildDirectory $name
    Invoke-Godot @('--headless', '--path', $ProjectRoot, $mode, 'Android', $path) 'android.log'
    Write-ArtifactHash $path
}
