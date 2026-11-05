[CmdletBinding()]
param(
    [string]$InstallDirectory = "$env:LOCALAPPDATA\Programs\CodexDevTools\godot",
    [switch]$SkipTemplates
)

$ErrorActionPreference = 'Stop'
$Version = '4.7.2'
$Release = "$Version-stable"
$BaseUrl = "https://github.com/godotengine/godot-builds/releases/download/$Release"
$EngineName = "Godot_v${Release}_win64.exe.zip"
$TemplateName = "Godot_v${Release}_export_templates.tpz"
$EngineHash = '83DECD58FDF67B9D657958A1AE6BF1929C20785315A81EFFE245874CDC57ACB709' +
    'BF868E00778A96984338C1B29DAFDB453C6847747694621C6ECF5DA2259993'
$TemplateHash = 'CA4D71C4D7B81DFC15D1A98BAA07534AA95B03FDDA78A0075B06672E1648D2E5' +
    'F40980C9ADC28D23E1B92E732EE7BF3461997AA804AF74EC2FCD7A93CCB84079'
$GodotPath = Join-Path $InstallDirectory "Godot_v${Release}_win64_console.exe"

function Get-VerifiedDownload([string]$Name, [string]$ExpectedHash) {
    $destination = Join-Path $InstallDirectory $Name
    if (Test-Path -LiteralPath $destination) {
        $actual = (Get-FileHash -LiteralPath $destination -Algorithm SHA512).Hash
        if ($actual -eq $ExpectedHash) { return $destination }
    }
    $temporary = "$destination.download"
    & curl.exe -L --fail --retry 2 --silent --show-error --output $temporary "$BaseUrl/$Name"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Name" }
    $actual = (Get-FileHash -LiteralPath $temporary -Algorithm SHA512).Hash
    if ($actual -ne $ExpectedHash) { throw "SHA512 mismatch for $Name; file was not installed." }
    Move-Item -LiteralPath $temporary -Destination $destination -Force
    return $destination
}

New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
if (-not (Test-Path -LiteralPath $GodotPath)) {
    $archive = Get-VerifiedDownload $EngineName $EngineHash
    Expand-Archive -LiteralPath $archive -DestinationPath $InstallDirectory -Force
}
$actualVersion = & $GodotPath --version
if ($actualVersion -notmatch '^4\.7\.2\.stable') { throw "Wrong engine version: $actualVersion" }

# This engine installation owns its settings, cache and keys. Existing Godot profiles are untouched.
$selfContained = Join-Path $InstallDirectory '_sc_'
if (-not (Test-Path -LiteralPath $selfContained)) {
    [IO.File]::WriteAllText($selfContained, '', [Text.UTF8Encoding]::new($false))
}
$templateDirectory = Join-Path $InstallDirectory "editor_data\export_templates\$Version.stable"
if (-not $SkipTemplates -and -not (Test-Path -LiteralPath (Join-Path $templateDirectory 'android_debug.apk'))) {
    $archive = Get-VerifiedDownload $TemplateName $TemplateHash
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Path $templateDirectory -Force | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        foreach ($entry in $zip.Entries) {
            $name = [IO.Path]::GetFileName($entry.FullName)
            if ($name -like 'android_*' -or $name -like 'windows_*' -or $name -eq 'version.txt') {
                $target = Join-Path $templateDirectory $name
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
            }
        }
    }
    finally { $zip.Dispose() }
}
Write-Output "Godot: $GodotPath"
Write-Output "Version: $actualVersion"
Write-Output "Templates: $templateDirectory"
Write-Output 'Android export also requires JDK 17+ and Android SDK with platform-tools/build-tools/platform 35.'
