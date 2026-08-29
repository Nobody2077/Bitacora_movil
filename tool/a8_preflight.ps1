param(
    [switch]$SkipQuality
)

$ErrorActionPreference = 'Stop'

function Invoke-NativeChecked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Executable failed with exit code $LASTEXITCODE."
    }
}

function Assert-TextContains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Pattern,
        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    if (-not (Select-String -LiteralPath $Path -Pattern $Pattern -Quiet)) {
        throw $FailureMessage
    }
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $ProjectRoot

try {
    Write-Host 'A8 preflight: version, schema and Android hardening...'
    Assert-TextContains -Path 'pubspec.yaml' -Pattern '^version:\s+\d+\.\d+\.\d+\+\d+$' `
        -FailureMessage 'pubspec.yaml must declare a semantic Android release version.'
    Assert-TextContains -Path 'lib/infrastructure/database/app_database.dart' `
        -Pattern 'schemaVersion\s*=>\s*1' `
        -FailureMessage 'The release must keep the explicit Drift schema version.'
    Assert-TextContains -Path 'lib/infrastructure/database/default_seed_v1.dart' `
        -Pattern "'schema_version',\s*'1'" `
        -FailureMessage 'The schema metadata mirror is not version 1.'
    Assert-TextContains -Path 'android/app/src/main/AndroidManifest.xml' `
        -Pattern 'android:allowBackup="false"' `
        -FailureMessage 'Android backup must remain disabled.'
    Assert-TextContains -Path 'android/app/src/main/AndroidManifest.xml' `
        -Pattern 'android:dataExtractionRules="@xml/data_extraction_rules"' `
        -FailureMessage 'Android 12+ data extraction rules must be explicit.'
    Assert-TextContains -Path 'android/app/build.gradle.kts' `
        -Pattern 'isCoreLibraryDesugaringEnabled\s*=\s*true' `
        -FailureMessage 'API 24/25 needs core library desugaring for java.time.'
    Assert-TextContains -Path 'android/app/src/prod/AndroidManifest.xml' `
        -Pattern 'android:usesCleartextTraffic="false"' `
        -FailureMessage 'The prod flavor must reject cleartext traffic.'

    $productionManifests = @(
        'android/app/src/main/AndroidManifest.xml',
        'android/app/src/prod/AndroidManifest.xml'
    )
    foreach ($manifest in $productionManifests) {
        if (Select-String -LiteralPath $manifest `
                -Pattern 'android.permission.INTERNET' -Quiet) {
            throw "Production manifest requests INTERNET: $manifest"
        }
    }

    $logMatches = & rg -n --glob '*.dart' '\b(?:debugPrint|print)\s*\(' lib
    if ($LASTEXITCODE -eq 0) {
        throw "Production Dart sources contain direct logging:`n$($logMatches -join "`n")"
    }
    if ($LASTEXITCODE -gt 1) {
        throw "rg failed while scanning production logging (exit $LASTEXITCODE)."
    }

    if (Select-String -LiteralPath 'android/app/build.gradle.kts' `
            -Pattern 'signingConfigs\.getByName\("debug"\)' -Quiet) {
        throw 'Release signing must never reuse the Android debug key.'
    }

    if (-not $SkipQuality) {
        & (Join-Path $PSScriptRoot 'quality.ps1')
        if ($LASTEXITCODE -ne 0) {
            throw "quality.ps1 failed with exit code $LASTEXITCODE."
        }
    }

    Write-Host 'A8 preflight: release-only Flutter plugin registry...'
    Invoke-NativeChecked 'flutter' @(
        'build',
        'apk',
        '--release',
        '--config-only',
        '--flavor',
        'prod',
        '-t',
        'lib/main_prod.dart'
    )

    Write-Host 'A8 preflight: Android release lint...'
    Invoke-NativeChecked '.\android\gradlew.bat' @(
        '-p',
        'android',
        ':app:lintProdRelease'
    )

    Write-Host 'A8 preflight passed.'
} finally {
    Pop-Location
}
