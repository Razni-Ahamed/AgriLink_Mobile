# Creates the key that signs AgriLink's release builds, and android/key.properties pointing at it.
# Run it once, on the machine that builds releases:
#
#   powershell -ExecutionPolicy Bypass -File tool\create_release_key.ps1
#
# It asks for a password (typed hidden, never shown or logged). The key goes in your user folder,
# outside every repository, and key.properties is ignored by git. Back up both, with the password:
# every future update has to be signed with this same key, and a lost key can't be recovered.

$ErrorActionPreference = 'Stop'

$keyDir = Join-Path $env:USERPROFILE '.agrilink'
$keyFile = Join-Path $keyDir 'agrilink-release.jks'
$alias = 'agrilink'
$propertiesFile = Join-Path $PSScriptRoot '..\android\key.properties'

if (Test-Path $keyFile) {
    throw "A release key already exists at $keyFile. Refusing to replace it: apps signed with it could no longer be updated."
}

# keytool ships with Java; Android Studio bundles one.
$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not $keytool) {
    foreach ($candidate in @("$env:JAVA_HOME\bin\keytool.exe", "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe")) {
        if (Test-Path $candidate) { $keytool = $candidate; break }
    }
}
if (-not $keytool) {
    throw 'keytool was not found. Install Android Studio, or set JAVA_HOME to a JDK.'
}

function Read-Secret([string]$prompt) {
    $secure = Read-Host -Prompt $prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$password = Read-Secret 'Choose a password for the release key (at least 12 characters)'
if ($password.Length -lt 12) { throw 'The password must be at least 12 characters.' }
# key.properties is ASCII, so other characters would be saved wrongly and the build couldn't open the key.
if ($password -notmatch '^[\x21-\x7E]+$') { throw 'Use only English letters, digits and symbols, with no spaces.' }
if ($password -ne (Read-Secret 'Type it again')) { throw 'The two passwords did not match.' }

New-Item -ItemType Directory -Force $keyDir | Out-Null

# Handed to keytool through an environment variable, so it never appears in a command line.
$env:AGRILINK_KEY_PASSWORD = $password
try {
    & $keytool -genkeypair -v `
        -keystore $keyFile -storetype PKCS12 `
        -alias $alias -keyalg RSA -keysize 4096 -validity 10000 `
        -dname 'CN=AgriLink Sri Lanka, O=AgriLink, L=Colombo, C=LK' `
        -storepass:env AGRILINK_KEY_PASSWORD -keypass:env AGRILINK_KEY_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw "keytool failed (exit code $LASTEXITCODE)." }
}
finally {
    Remove-Item Env:\AGRILINK_KEY_PASSWORD -ErrorAction SilentlyContinue
}

# Gradle reads this; forward slashes keep the Windows path valid in a .properties file, where a
# backslash is an escape character (so one in the password is written doubled).
$escaped = $password -replace '\\', '\\'
@(
    "storeFile=$($keyFile -replace '\\', '/')"
    "storePassword=$escaped"
    "keyAlias=$alias"
    "keyPassword=$escaped"
) | Set-Content -Encoding ascii $propertiesFile

Write-Host ''
Write-Host "Release key created: $keyFile"
Write-Host "Build settings written: $((Resolve-Path $propertiesFile).Path)"
Write-Host 'Back up the key file and the password now (a password manager is ideal).'
