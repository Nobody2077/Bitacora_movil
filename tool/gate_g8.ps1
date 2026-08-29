param(
    [Parameter(Mandatory = $true)]
    [string]$DeviceId,
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

function Get-LocalProperty {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $line = Get-Content 'android/local.properties' |
        Where-Object { $_ -match "^$([regex]::Escape($Name))=" } |
        Select-Object -First 1
    if (-not $line) {
        throw "android/local.properties does not define $Name."
    }
    return ($line.Substring($line.IndexOf('=') + 1) -replace '\\\\', '\')
}

function Test-SigningConfigured {
    $environmentNames = @(
        'BITACORA_RELEASE_STORE_FILE',
        'BITACORA_RELEASE_STORE_PASSWORD',
        'BITACORA_RELEASE_KEY_ALIAS',
        'BITACORA_RELEASE_KEY_PASSWORD'
    )
    $environmentConfigured = $true
    foreach ($name in $environmentNames) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
            $environmentConfigured = $false
        }
    }
    if ($environmentConfigured) {
        return $true
    }

    $propertiesPath = 'android/signing.properties'
    if (-not (Test-Path -LiteralPath $propertiesPath -PathType Leaf)) {
        return $false
    }
    $propertyNames = @('storeFile', 'storePassword', 'keyAlias', 'keyPassword')
    $content = Get-Content -LiteralPath $propertiesPath
    foreach ($name in $propertyNames) {
        if (-not ($content | Where-Object { $_ -match "^$name=.+$" })) {
            return $false
        }
    }
    return $true
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $ProjectRoot

try {
    if (-not (Test-SigningConfigured)) {
        throw @'
Production signing is not configured. Copy android/signing.properties.example
to android/signing.properties or define the four BITACORA_RELEASE_* variables.
G8 never falls back to the debug key.
'@
    }

    & (Join-Path $PSScriptRoot 'a8_preflight.ps1') -SkipQuality:$SkipQuality
    if ($LASTEXITCODE -ne 0) {
        throw "a8_preflight.ps1 failed with exit code $LASTEXITCODE."
    }

    $sdkDirectory = Get-LocalProperty -Name 'sdk.dir'
    $adb = Join-Path $sdkDirectory 'platform-tools/adb.exe'
    if (-not (Test-Path -LiteralPath $adb -PathType Leaf)) {
        throw "adb was not found at $adb."
    }
    $deviceState = & $adb -s $DeviceId get-state 2>$null
    if ($LASTEXITCODE -ne 0 -or $deviceState -ne 'device') {
        throw "Android device $DeviceId is not connected and authorized."
    }

    Write-Host 'G8: encrypted database, access and restart regressions...'
    Invoke-NativeChecked 'flutter' @(
        'test',
        'integration_test/encrypted_database_test.dart',
        '--flavor',
        'dev',
        '-d',
        $DeviceId
    )
    Invoke-NativeChecked 'flutter' @(
        'test',
        'integration_test/access_security_test.dart',
        '--flavor',
        'dev',
        '-d',
        $DeviceId
    )
    & (Join-Path $PSScriptRoot 'process_restart_g2.ps1') -DeviceId $DeviceId
    if ($LASTEXITCODE -ne 0) {
        throw "process_restart_g2.ps1 failed with exit code $LASTEXITCODE."
    }

    Write-Host 'G8: performance on encrypted extensive dataset...'
    Invoke-NativeChecked 'flutter' @(
        'test',
        'integration_test/a8_performance_test.dart',
        '--flavor',
        'dev',
        '-d',
        $DeviceId,
        '--reporter',
        'expanded'
    )

    Write-Host 'G8: signed prod APK and AAB...'
    Invoke-NativeChecked 'flutter' @(
        'build',
        'apk',
        '--release',
        '--flavor',
        'prod',
        '-t',
        'lib/main_prod.dart'
    )
    Invoke-NativeChecked 'flutter' @(
        'build',
        'appbundle',
        '--release',
        '--flavor',
        'prod',
        '-t',
        'lib/main_prod.dart'
    )

    $apk = Resolve-Path 'build/app/outputs/flutter-apk/app-prod-release.apk'
    $aab = Resolve-Path 'build/app/outputs/bundle/prodRelease/app-prod-release.aab'
    $buildTools = Get-ChildItem (Join-Path $sdkDirectory 'build-tools') -Directory |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1
    if (-not $buildTools) {
        throw 'No stable Android build-tools installation was found.'
    }
    $apkSigner = Join-Path $buildTools.FullName 'apksigner.bat'
    Invoke-NativeChecked $apkSigner @(
        'verify',
        '--verbose',
        '--print-certs',
        $apk.Path
    )

    $flutterConfig = & flutter config --list
    $jdkLine = $flutterConfig | Where-Object { $_ -match '^\s+jdk-dir:\s+' } |
        Select-Object -First 1
    if (-not $jdkLine) {
        throw 'Flutter does not expose a configured JDK directory.'
    }
    $jdkDirectory = ($jdkLine -replace '^\s+jdk-dir:\s+', '').Trim()
    $jarSigner = Join-Path $jdkDirectory 'bin/jarsigner.exe'
    Invoke-NativeChecked $jarSigner @('-verify', $aab.Path)

    $apkAnalyzer = Join-Path $sdkDirectory 'cmdline-tools/latest/bin/apkanalyzer.bat'
    if (-not (Test-Path -LiteralPath $apkAnalyzer -PathType Leaf)) {
        throw "apkanalyzer was not found at $apkAnalyzer."
    }
    $permissions = & $apkAnalyzer manifest permissions $apk.Path
    if ($LASTEXITCODE -ne 0) {
        throw "apkanalyzer failed with exit code $LASTEXITCODE."
    }
    if ($permissions -contains 'android.permission.INTERNET') {
        throw 'The prod release APK unexpectedly requests INTERNET.'
    }

    Write-Host 'G8: non-destructive release smoke install...'
    & $adb -s $DeviceId install -r $apk.Path
    if ($LASTEXITCODE -ne 0) {
        throw @'
The release APK could not update the installed prod package. If the device has
a debug-signed prod APK, Android will reject the signature change. Do not
uninstall it if its local data must be preserved; use a dedicated clean device.
'@
    }
    Invoke-NativeChecked $adb @(
        '-s',
        $DeviceId,
        'shell',
        'am',
        'start',
        '-W',
        '-n',
        'com.jcyq.bitacorarpg/.MainActivity'
    )

    $evidenceDirectory = Join-Path $ProjectRoot 'build/a8_evidence'
    New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null
    $versionLine = Get-Content 'pubspec.yaml' |
        Where-Object { $_ -match '^version:' } |
        Select-Object -First 1
    $manifest = [ordered]@{
        generatedAtUtc = [DateTime]::UtcNow.ToString('o')
        version = ($versionLine -replace '^version:\s*', '')
        schemaVersion = 1
        deviceId = $DeviceId
        apk = [ordered]@{
            path = $apk.Path
            bytes = (Get-Item $apk.Path).Length
            sha256 = (Get-FileHash $apk.Path -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        aab = [ordered]@{
            path = $aab.Path
            bytes = (Get-Item $aab.Path).Length
            sha256 = (Get-FileHash $aab.Path -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        internetPermission = $false
    }
    $manifest | ConvertTo-Json -Depth 4 |
        Set-Content -LiteralPath (Join-Path $evidenceDirectory 'release_manifest.json') `
            -Encoding utf8

    Write-Host 'G8 automated gate passed. Complete the manual matrix in documentos/A8-VALIDACION-RELEASE.md.'
} finally {
    Pop-Location
}
