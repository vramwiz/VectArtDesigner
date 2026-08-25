param(
    [string]$InputPath = "",
    [string]$OutputPath = "",
    [switch]$Hex
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$inputDirectory = if ($InputPath) {
    [System.IO.Path]::GetFullPath($InputPath)
} else {
    Join-Path $projectRoot 'mif'
}
$runRoot = Join-Path $projectRoot 'Win64\MifDiagnostics\runs'
if ($OutputPath) {
    $outputDirectory = [System.IO.Path]::GetFullPath($OutputPath)
} else {
    $runId = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
    $outputDirectory = Join-Path $runRoot $runId
}
$buildDirectory = Join-Path $projectRoot 'Win64\MifDiagnostics\bin'
$dcuDirectory = Join-Path $buildDirectory 'DCU'
$sourceFile = Join-Path $projectRoot 'Tools\MifDiagnostics\MifDiagnostics.dpr'
$executable = Join-Path $buildDirectory 'MifDiagnostics.exe'
$rsvars = 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat'

Push-Location $projectRoot
try {
    New-Item -ItemType Directory -Force -Path $buildDirectory, $dcuDirectory,
        $outputDirectory | Out-Null

    $compileCommand = 'call "{0}" && dcc64 -B -Q -E"{1}" -N0"{2}" "{3}"' -f `
        $rsvars, $buildDirectory, $dcuDirectory, $sourceFile
    & cmd.exe /d /c $compileCommand
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $arguments = @('--input', $inputDirectory, '--output', $outputDirectory)
    if ($Hex) {
        $arguments += '--hex'
    }
    & $executable @arguments
    $diagnosticExitCode = $LASTEXITCODE
    if ($diagnosticExitCode -eq 0) {
        Write-Output (Join-Path $outputDirectory 'report.md')
    }
    exit $diagnosticExitCode
}
finally {
    Pop-Location
}
