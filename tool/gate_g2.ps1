param(
    [string]$DeviceId = 'emulator-5554'
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $ProjectRoot

try {
    & (Join-Path $PSScriptRoot 'quality.ps1')
    if ($LASTEXITCODE -ne 0) {
        throw "quality.ps1 failed with exit code $LASTEXITCODE."
    }

    flutter test integration_test/encrypted_database_test.dart --flavor dev -d $DeviceId
    if ($LASTEXITCODE -ne 0) {
        throw "Android encryption regression failed with exit code $LASTEXITCODE."
    }

    flutter test integration_test/access_security_test.dart --flavor dev -d $DeviceId
    if ($LASTEXITCODE -ne 0) {
        throw "Android access/privacy integration failed with exit code $LASTEXITCODE."
    }

    flutter build apk --debug --flavor dev -t lib/main_dev.dart
    if ($LASTEXITCODE -ne 0) {
        throw "dev APK build failed with exit code $LASTEXITCODE."
    }

    flutter build apk --debug --flavor prod -t lib/main_prod.dart
    if ($LASTEXITCODE -ne 0) {
        throw "prod APK build failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}
