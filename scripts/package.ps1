[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OutputPath = Join-Path $ProjectRoot 'builds\ChromaticRush-1.0.0-source.zip'
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
$RootFiles = @('project.godot', 'main.tscn', 'export_presets.cfg', 'README.md', 'LICENSE',
    '.gitignore', '.gdlintrc', '.env.example', 'requirements-dev.lock')
$Folders = @('src', 'data', 'assets', 'tests', 'scripts', 'docs', '.github')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = $null
$archive = $null
$completed = $false
try {
    $stream = [IO.File]::Open($OutputPath, [IO.FileMode]::Create)
    $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
    $files = @($RootFiles | ForEach-Object { Get-Item -LiteralPath (Join-Path $ProjectRoot $_) })
    foreach ($folder in $Folders) {
        $files += Get-ChildItem -LiteralPath (Join-Path $ProjectRoot $folder) -File -Recurse |
            Where-Object {
                $_.FullName -notmatch '__pycache__' -and $_.Name -notlike 'tmp_*' -and
                $_.Extension -notin @('.pyc', '.tmp', '.log')
            }
    }
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($ProjectRoot.Length + 1).Replace('\', '/')
        $entry = 'ChromaticRush/' + $relative
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, $file.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
    $completed = $true
}
finally {
    if ($archive) { $archive.Dispose() }
    if ($stream) { $stream.Dispose() }
    if (-not $completed -and (Test-Path -LiteralPath $OutputPath)) { Remove-Item -LiteralPath $OutputPath -Force }
}
$hash = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$OutputPath.sha256", "$hash *$([IO.Path]::GetFileName($OutputPath))`n")
Write-Output "Source package: $OutputPath"
Write-Output "SHA256: $hash"
