[CmdletBinding()]
param(
    [string]$SigningDirectory = "$env:USERPROFILE\Documents\Codex\signing\ChromaticRush",
    [string]$JavaHome = $env:JAVA_HOME
)

$ErrorActionPreference = 'Stop'
if (-not $JavaHome) { $JavaHome = "$env:USERPROFILE\Documents\Codex\tools\jdk\jdk-17.0.19+10" }
$Keytool = Join-Path $JavaHome 'bin\keytool.exe'
if (-not (Test-Path -LiteralPath $Keytool)) { throw 'Set JAVA_HOME or pass -JavaHome with JDK 17+.' }
$ProjectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
$SigningDirectory = [IO.Path]::GetFullPath($SigningDirectory).TrimEnd('\')
if ($SigningDirectory.StartsWith($ProjectRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
    $SigningDirectory -eq $ProjectRoot) { throw 'Signing material must be stored outside the repository.' }
New-Item -ItemType Directory -Path $SigningDirectory -Force | Out-Null
$CurrentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$Permissions = [Security.AccessControl.DirectorySecurity]::new()
$Permissions.SetAccessRuleProtection($true, $false)
$Permissions.SetOwner($CurrentSid)
$Inheritance = [Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
$Propagation = [Security.AccessControl.PropagationFlags]::None
$Allow = [Security.AccessControl.AccessControlType]::Allow
$Permissions.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
    $CurrentSid, [Security.AccessControl.FileSystemRights]::FullControl, $Inheritance, $Propagation, $Allow))
$SystemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
$Permissions.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
    $SystemSid, [Security.AccessControl.FileSystemRights]::FullControl, $Inheritance, $Propagation, $Allow))
Set-Acl -LiteralPath $SigningDirectory -AclObject $Permissions
$Keystore = Join-Path $SigningDirectory 'chromatic-rush-release.jks'
$PasswordPath = Join-Path $SigningDirectory 'release-password.txt'
if ((Test-Path -LiteralPath $Keystore) -xor (Test-Path -LiteralPath $PasswordPath)) {
    throw 'Incomplete signing material: restore the missing file from backup before continuing.'
}
if (-not (Test-Path -LiteralPath $Keystore)) {
    $RandomBytes = New-Object byte[] 48
    $Generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $Generator.GetBytes($RandomBytes) } finally { $Generator.Dispose() }
    $Password = [Convert]::ToBase64String($RandomBytes)
    [IO.File]::WriteAllText($PasswordPath, $Password, [Text.UTF8Encoding]::new($false))
    $env:CHROMATIC_RUSH_KEY_PASSWORD = $Password
    try {
        & $Keytool -genkeypair -noprompt -keystore $Keystore -storetype JKS -alias chromaticrush `
            -keyalg RSA -keysize 3072 -sigalg SHA256withRSA -validity 10000 `
            -dname 'CN=Chromatic Rush, OU=Application Release, O=Chromatic Rush' `
            -storepass:env CHROMATIC_RUSH_KEY_PASSWORD -keypass:env CHROMATIC_RUSH_KEY_PASSWORD
        if ($LASTEXITCODE -ne 0) { throw 'Release-key generation failed. Existing files were preserved.' }
    }
    finally { Remove-Item Env:\CHROMATIC_RUSH_KEY_PASSWORD -ErrorAction SilentlyContinue }
}
$env:CHROMATIC_RUSH_KEY_PASSWORD = [IO.File]::ReadAllText($PasswordPath).Trim()
try {
    & $Keytool -list -keystore $Keystore -alias chromaticrush -storepass:env CHROMATIC_RUSH_KEY_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Release-key validation failed.' }
}
finally { Remove-Item Env:\CHROMATIC_RUSH_KEY_PASSWORD -ErrorAction SilentlyContinue }
Write-Output "Private signing directory: $SigningDirectory"
Write-Output 'Back up both the keystore and password file privately. They are excluded from app/source packages.'
