[CmdletBinding()]
param(
    [string]$EngineRoot = "",
    [switch]$BuildOnly,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ProjectFile = Join-Path $ProjectRoot "LITDValidation.uproject"

function Find-UnrealEngine {
    param([string]$ExplicitRoot)
    if ($ExplicitRoot -and (Test-Path (Join-Path $ExplicitRoot "Engine\Binaries\Win64\UnrealEditor.exe"))) {
        return (Resolve-Path $ExplicitRoot).Path
    }
    $registryPath = "HKCU:\Software\Epic Games\Unreal Engine\Builds"
    if (Test-Path $registryPath) {
        $properties = Get-ItemProperty $registryPath
        foreach ($property in $properties.PSObject.Properties) {
            if ($property.Name -like "PS*") { continue }
            $candidate = [string]$property.Value
            if (Test-Path (Join-Path $candidate "Engine\Binaries\Win64\UnrealEditor.exe")) { return $candidate }
        }
    }
    $launcherRoot = Join-Path $env:ProgramFiles "Epic Games"
    if (Test-Path $launcherRoot) {
        $candidate = Get-ChildItem $launcherRoot -Directory -Filter "UE_*" |
            Sort-Object Name -Descending |
            Where-Object { Test-Path (Join-Path $_.FullName "Engine\Binaries\Win64\UnrealEditor.exe") } |
            Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    }
    throw "Unreal Engine 5 introuvable. Installez-le avec Epic Games Launcher ou passez -EngineRoot."
}

$ResolvedEngine = Find-UnrealEngine $EngineRoot
$BuildBat = Join-Path $ResolvedEngine "Engine\Build\BatchFiles\Build.bat"
$EditorExe = Join-Path $ResolvedEngine "Engine\Binaries\Win64\UnrealEditor.exe"

Write-Host "Unreal : $ResolvedEngine"
Write-Host "Projet : $ProjectFile"

if (-not $SkipBuild) {
    & $BuildBat -projectfiles "-project=$ProjectFile" -game -engine -progress
    if ($LASTEXITCODE -ne 0) { throw "Échec de génération des fichiers projet." }
    & $BuildBat LITDValidationEditor Win64 Development "-Project=$ProjectFile" -WaitMutex -FromMsBuild
    if ($LASTEXITCODE -ne 0) { throw "Échec de compilation du prototype Unreal." }
}
if (-not $BuildOnly) {
    Start-Process $EditorExe -ArgumentList @($ProjectFile, "-game", "-log")
}
