[CmdletBinding()]
param(
    [string]$EngineRoot = "",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ProjectFile = Join-Path $ProjectRoot "LITDValidation.uproject"
$ReportRoot = Join-Path $ProjectRoot "Saved\Automation\CombatCore"

function Find-UnrealEngine {
    param([string]$ExplicitRoot)
    if ($ExplicitRoot -and (Test-Path (Join-Path $ExplicitRoot "Engine\Binaries\Win64\UnrealEditor-Cmd.exe"))) {
        return (Resolve-Path $ExplicitRoot).Path
    }
    $registryPath = "HKCU:\Software\Epic Games\Unreal Engine\Builds"
    if (Test-Path $registryPath) {
        $properties = Get-ItemProperty $registryPath
        foreach ($property in $properties.PSObject.Properties) {
            if ($property.Name -like "PS*") { continue }
            $candidate = [string]$property.Value
            if (Test-Path (Join-Path $candidate "Engine\Binaries\Win64\UnrealEditor-Cmd.exe")) { return $candidate }
        }
    }
    $launcherRoot = Join-Path $env:ProgramFiles "Epic Games"
    if (Test-Path $launcherRoot) {
        $candidate = Get-ChildItem $launcherRoot -Directory -Filter "UE_*" |
            Sort-Object Name -Descending |
            Where-Object { Test-Path (Join-Path $_.FullName "Engine\Binaries\Win64\UnrealEditor-Cmd.exe") } |
            Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    }
    throw "Unreal Engine 5 introuvable. Installez-le ou passez -EngineRoot."
}

$ResolvedEngine = Find-UnrealEngine $EngineRoot
$BuildBat = Join-Path $ResolvedEngine "Engine\Build\BatchFiles\Build.bat"
$EditorCmd = Join-Path $ResolvedEngine "Engine\Binaries\Win64\UnrealEditor-Cmd.exe"

if (-not $SkipBuild) {
    & $BuildBat LITDValidationEditor Win64 Development "-Project=$ProjectFile" -WaitMutex -FromMsBuild
    if ($LASTEXITCODE -ne 0) { throw "Échec de compilation du prototype Unreal." }
}

if (Test-Path $ReportRoot) { Remove-Item $ReportRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $ReportRoot | Out-Null

& $EditorCmd $ProjectFile `
    -unattended -nop4 -nosplash -NullRHI `
    '-ExecCmds=Automation RunTest LITD.Combat.Core;Quit' `
    "-ReportExportPath=$ReportRoot" `
    -log

if ($LASTEXITCODE -ne 0) {
    throw "Les tests LITD.Combat.Core ont échoué. Consultez $ReportRoot et Saved\Logs."
}

Write-Host "Tests LITD.Combat.Core terminés. Rapport : $ReportRoot"
