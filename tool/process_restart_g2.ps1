param(
    [string]$DeviceId = 'emulator-5554',
    [string]$AdbPath = ''
)

$ErrorActionPreference = 'Stop'

$PackageName = 'com.jcyq.bitacorarpg.dev'
$MainActivity = 'com.jcyq.bitacorarpg.MainActivity'

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

function Resolve-AdbExecutable {
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $resolved = Resolve-Path -LiteralPath $RequestedPath -ErrorAction Stop
        return $resolved.Path
    }

    $command = Get-Command 'adb' -CommandType Application -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_SDK_ROOT)) {
        $candidates += Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe'
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_HOME)) {
        $candidates += Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $candidates += Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw 'adb was not found. Set ANDROID_SDK_ROOT or pass -AdbPath.'
}

function Get-PackagePid {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AdbExecutable
    )

    $output = & $AdbExecutable -s $DeviceId shell pidof $PackageName 2>&1
    $exitCode = $LASTEXITCODE
    $value = ($output | Out-String).Trim()

    if ($exitCode -eq 1 -and [string]::IsNullOrWhiteSpace($value)) {
        return $null
    }
    if ($exitCode -ne 0) {
        throw "adb pidof failed with exit code ${exitCode}: $value"
    }
    if ($value -notmatch '^\d+(\s+\d+)*$') {
        throw "adb returned an invalid PID for ${PackageName}: $value"
    }
    return $value
}

function Assert-ProdPackageAbsent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AdbExecutable
    )

    # Mismo riesgo que en gate_g8.ps1: si falla la instalacion dev, Flutter
    # puede desinstalar el paquete prod y borrar sus datos cifrados.
    $packages = & $AdbExecutable -s $DeviceId shell pm list packages com.jcyq.bitacorarpg
    if ($LASTEXITCODE -ne 0) {
        throw "adb could not list packages on $DeviceId."
    }
    if ($packages | Where-Object { $_.Trim() -eq 'package:com.jcyq.bitacorarpg' }) {
        throw "$DeviceId has the prod package com.jcyq.bitacorarpg installed. Use a clean dedicated device."
    }
}

function Wait-ForPackagePid {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AdbExecutable
    )

    for ($attempt = 0; $attempt -lt 40; $attempt += 1) {
        $processId = Get-PackagePid -AdbExecutable $AdbExecutable
        if ($null -ne $processId) {
            return $processId
        }
        Start-Sleep -Milliseconds 250
    }
    return $null
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$AdbExecutable = Resolve-AdbExecutable -RequestedPath $AdbPath
Push-Location -LiteralPath $ProjectRoot

try {
    Invoke-NativeChecked $AdbExecutable @('-s', $DeviceId, 'get-state')
    Assert-ProdPackageAbsent -AdbExecutable $AdbExecutable

    Write-Host 'G2 process restart: seeding encrypted access state...'
    Invoke-NativeChecked 'flutter' @(
        'drive',
        '--keep-app-running',
        '--driver',
        'integration_test/support/integration_test_driver.dart',
        '--target',
        'integration_test/process_restart_seed_test.dart',
        '--flavor',
        'dev',
        '-d',
        $DeviceId
    )

    $pidBeforeStop = Get-PackagePid -AdbExecutable $AdbExecutable
    if ($null -eq $pidBeforeStop) {
        Write-Host 'Seed runner exited; starting the same APK before the explicit force-stop...'
        Invoke-NativeChecked $AdbExecutable @(
            '-s',
            $DeviceId,
            'shell',
            'am',
            'start',
            '-W',
            '-n',
            "$PackageName/$MainActivity"
        )
        $pidBeforeStop = Wait-ForPackagePid -AdbExecutable $AdbExecutable
    }
    if ($null -eq $pidBeforeStop) {
        throw "Package $PackageName did not expose a live PID before force-stop."
    }

    Write-Host "G2 process restart: force-stopping PID $pidBeforeStop..."
    Invoke-NativeChecked $AdbExecutable @(
        '-s',
        $DeviceId,
        'shell',
        'am',
        'force-stop',
        $PackageName
    )

    for ($attempt = 0; $attempt -lt 40; $attempt += 1) {
        if ($null -eq (Get-PackagePid -AdbExecutable $AdbExecutable)) {
            break
        }
        Start-Sleep -Milliseconds 250
    }
    $pidAfterStop = Get-PackagePid -AdbExecutable $AdbExecutable
    if ($null -ne $pidAfterStop) {
        throw "Package $PackageName is still alive after force-stop (PID $pidAfterStop)."
    }
    Write-Host 'G2 process restart: PID termination confirmed.'

    Write-Host 'G2 process restart: verifying cold locked session and cleanup...'
    Invoke-NativeChecked 'flutter' @(
        'drive',
        '--driver',
        'integration_test/support/integration_test_driver.dart',
        '--target',
        'integration_test/process_restart_verify_test.dart',
        '--flavor',
        'dev',
        '-d',
        $DeviceId
    )
    Write-Host 'G2 process restart: passed.'
} finally {
    Pop-Location
}
