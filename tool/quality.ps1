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

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $ProjectRoot

try {
    Invoke-NativeChecked 'dart' @(
        'format',
        '--output=none',
        '--set-exit-if-changed',
        'lib',
        'test',
        'integration_test'
    )
    Invoke-NativeChecked 'dart' @('run', 'build_runner', 'build')
    Invoke-NativeChecked 'flutter' @('analyze')
    Invoke-NativeChecked 'flutter' @('test')
} finally {
    Pop-Location
}
