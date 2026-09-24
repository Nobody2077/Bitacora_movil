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
    $schemaMatch = Select-String -LiteralPath 'lib/infrastructure/database/app_database.dart' `
        -Pattern 'int get schemaVersion => (\d+);' | Select-Object -First 1
    if (-not $schemaMatch) {
        throw 'The release must declare an explicit Drift schema version.'
    }
    $schemaVersion = [int]$schemaMatch.Matches[0].Groups[1].Value
    $schemaSnapshot = "drift_schemas/drift_schema_v$schemaVersion.json"
    if (-not (Test-Path -LiteralPath $schemaSnapshot -PathType Leaf)) {
        throw "Declared schema version $schemaVersion has no snapshot at $schemaSnapshot."
    }
    Write-Host "A8 preflight: Drift schema version $schemaVersion has a snapshot."
    Assert-TextContains -Path 'lib/infrastructure/database/default_seed_v1.dart' `
        -Pattern "'schema_version',\s*'1'" `
        -FailureMessage 'default_seed_v1 must insert schema_version 1 as the initial mirror value; AppDatabase raises it to the current schemaVersion afterwards.'
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

    $logMatches = Get-ChildItem -LiteralPath 'lib' -Recurse -Filter '*.dart' -File |
        Select-String -Pattern '\b(?:debugPrint|print)\s*\('
    if ($logMatches) {
        $logReport = ($logMatches | ForEach-Object {
            "{0}:{1}: {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()
        }) -join "`n"
        throw "Production Dart sources contain direct logging:`n$logReport"
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
