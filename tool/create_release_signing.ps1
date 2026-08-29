param(
    [string]$KeystorePath = (Join-Path $env:USERPROFILE '.android/bitacora-rpg-release.jks')
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SigningPropertiesPath = Join-Path $ProjectRoot 'android/signing.properties'
$KeystoreDirectory = Split-Path -Parent $KeystorePath
$KeystoreName = Split-Path -Leaf $KeystorePath

if (Test-Path -LiteralPath $KeystorePath) {
    throw "Refusing to overwrite the existing production keystore: $KeystorePath"
}
if (Test-Path -LiteralPath $SigningPropertiesPath) {
    throw "Refusing to overwrite the existing signing configuration: $SigningPropertiesPath"
}

New-Item -ItemType Directory -Force -Path $KeystoreDirectory | Out-Null
$ResolvedKeystoreDirectory = (Resolve-Path -LiteralPath $KeystoreDirectory).Path
$FinalKeystorePath = Join-Path $ResolvedKeystoreDirectory $KeystoreName
$TemporaryKeystorePath = "$FinalKeystorePath.tmp-$PID"
$TemporaryPropertiesPath = "$SigningPropertiesPath.tmp-$PID"

$FlutterConfig = & flutter config --list
if ($LASTEXITCODE -ne 0) {
    throw "flutter config failed with exit code $LASTEXITCODE."
}
$JdkLine = $FlutterConfig |
    Where-Object { $_ -match '^\s+jdk-dir:\s+' } |
    Select-Object -First 1
if (-not $JdkLine) {
    throw 'Flutter does not expose a configured JDK directory.'
}
$JdkDirectory = ($JdkLine -replace '^\s+jdk-dir:\s+', '').Trim()
$Keytool = Join-Path $JdkDirectory 'bin/keytool.exe'
if (-not (Test-Path -LiteralPath $Keytool -PathType Leaf)) {
    throw "keytool was not found at $Keytool."
}

$RandomBytes = New-Object byte[] 48
$RandomNumberGenerator = [Security.Cryptography.RandomNumberGenerator]::Create()
$RandomNumberGenerator.GetBytes($RandomBytes)
$RandomNumberGenerator.Dispose()
$Password = [Convert]::ToBase64String($RandomBytes).
    Replace('+', '-').
    Replace('/', '_').
    TrimEnd('=')
$Alias = 'bitacora-release'

try {
    $env:BITACORA_KEYSTORE_PASSWORD = $Password
    & $Keytool `
        -genkeypair `
        -noprompt `
        -storetype PKCS12 `
        -keystore $TemporaryKeystorePath `
        -storepass:env BITACORA_KEYSTORE_PASSWORD `
        -keypass:env BITACORA_KEYSTORE_PASSWORD `
        -alias $Alias `
        -dname 'CN=Bitacora RPG Personal, OU=Mobile, O=Personal, L=La Paz, ST=La Paz, C=BO' `
        -keyalg RSA `
        -keysize 4096 `
        -sigalg SHA256withRSA `
        -validity 10000
    if ($LASTEXITCODE -ne 0) {
        throw "keytool failed with exit code $LASTEXITCODE."
    }

    $PropertyLines = @(
        "storeFile=$($FinalKeystorePath.Replace('\', '/'))",
        "storePassword=$Password",
        "keyAlias=$Alias",
        "keyPassword=$Password"
    )
    [IO.File]::WriteAllLines(
        $TemporaryPropertiesPath,
        $PropertyLines,
        [Text.UTF8Encoding]::new($false)
    )

    Move-Item -LiteralPath $TemporaryKeystorePath -Destination $FinalKeystorePath
    Move-Item -LiteralPath $TemporaryPropertiesPath -Destination $SigningPropertiesPath

    & $Keytool `
        -list `
        -v `
        -keystore $FinalKeystorePath `
        -storepass:env BITACORA_KEYSTORE_PASSWORD `
        -alias $Alias |
        Select-String -Pattern 'Alias name:|Valid from:|SHA256:'
    if ($LASTEXITCODE -ne 0) {
        throw "keytool verification failed with exit code $LASTEXITCODE."
    }

    Write-Host ''
    Write-Host 'Production signing created. Back up both private files together:'
    Write-Host "  Keystore: $FinalKeystorePath"
    Write-Host "  Credentials: $SigningPropertiesPath"
    Write-Host 'Neither file is tracked by Git. Do not lose them.'
} finally {
    Remove-Item Env:BITACORA_KEYSTORE_PASSWORD -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $TemporaryKeystorePath) {
        Remove-Item -LiteralPath $TemporaryKeystorePath -Force
    }
    if (Test-Path -LiteralPath $TemporaryPropertiesPath) {
        Remove-Item -LiteralPath $TemporaryPropertiesPath -Force
    }
    [Array]::Clear($RandomBytes, 0, $RandomBytes.Length)
    $Password = $null
}
