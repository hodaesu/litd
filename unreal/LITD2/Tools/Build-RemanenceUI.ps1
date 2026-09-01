[CmdletBinding()]
param(
    [string]$EngineRoot = "",
    [switch]$SkipBuild,
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ProjectFile = Join-Path $ProjectRoot "LITD2.uproject"
$PythonScript = Join-Path $ProjectRoot "Content\Python\build_remanence_ui.py"
$GeneratedAsset = Join-Path $ProjectRoot "Content\UI\Remanence\WBP_RemembranceArchive.uasset"

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
            if (Test-Path (Join-Path $candidate "Engine\Binaries\Win64\UnrealEditor.exe")) {
                return $candidate
            }
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

    throw "Unreal Engine 5 introuvable. Installez-le ou passez -EngineRoot."
}

$ResolvedEngine = Find-UnrealEngine $EngineRoot
$BuildBat = Join-Path $ResolvedEngine "Engine\Build\BatchFiles\Build.bat"
$EditorExe = Join-Path $ResolvedEngine "Engine\Binaries\Win64\UnrealEditor.exe"
$EditorCmd = Join-Path $ResolvedEngine "Engine\Binaries\Win64\UnrealEditor-Cmd.exe"

Write-Host "Unreal : $ResolvedEngine"
Write-Host "Projet : $ProjectFile"
Write-Host "UI : Archives de Rémanence"

if (-not $SkipBuild) {
    & $BuildBat -projectfiles "-project=$ProjectFile" -game -engine -progress
    if ($LASTEXITCODE -ne 0) { throw "Échec de génération des fichiers projet LITD2." }

    & $BuildBat LITD2Editor Win64 Development "-Project=$ProjectFile" -WaitMutex -FromMsBuild
    if ($LASTEXITCODE -ne 0) { throw "Échec de compilation de LITD2Editor." }
}

$PythonArgument = "-ExecutePythonScript=$PythonScript"
& $EditorCmd $ProjectFile $PythonArgument -unattended -nop4 -nosplash -nullrhi
if ($LASTEXITCODE -ne 0) { throw "Échec de génération de WBP_RemembranceArchive." }

if (-not (Test-Path $GeneratedAsset)) {
    throw "Unreal s'est terminé sans produire $GeneratedAsset"
}

Write-Host "UMG généré : $GeneratedAsset"

if (-not $NoLaunch) {
    Start-Process $EditorExe -ArgumentList @($ProjectFile, "-log")
}
