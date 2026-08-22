param(
    [switch]$Install,
    [switch]$SkipBackup
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $RepoRoot

Write-Host "LITD - preparation du poste Windows" -ForegroundColor Cyan

if (-not $SkipBackup -and (Get-Command git -ErrorAction SilentlyContinue)) {
    $BackupDir = Join-Path $RepoRoot "local\backups"
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    $Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Bundle = Join-Path $BackupDir "LITD_before_pc_$Stamp.bundle"
    git bundle create $Bundle --all
    if ($LASTEXITCODE -ne 0) { throw "La sauvegarde Git a echoue." }
    Write-Host "Sauvegarde creee : $Bundle" -ForegroundColor Green
}

$Packages = @(
    @{ Name = "Git"; Id = "Git.Git" },
    @{ Name = "Python 3.12"; Id = "Python.Python.3.12" },
    @{ Name = "Godot"; Id = "GodotEngine.GodotEngine" },
    @{ Name = "Blender"; Id = "BlenderFoundation.Blender" },
    @{ Name = "MuseScore Studio"; Id = "MuseScore.MuseScore" },
    @{ Name = "REAPER"; Id = "Cockos.REAPER" }
)

if ($Install) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget est introuvable. Installe App Installer depuis Microsoft Store."
    }
    foreach ($Package in $Packages) {
        Write-Host "Installation/verif : $($Package.Name)"
        winget install --id $Package.Id --exact --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "$($Package.Name) n'a pas pu etre installe automatiquement."
        }
    }
} else {
    Write-Host "Mode diagnostic. Relance avec -Install pour installer les logiciels manquants."
}

$LocalDirs = @(
    "local\audio_library\sources",
    "local\audio_library\derived",
    "local\music_pipeline\renders",
    "local\music_pipeline\reaper_projects",
    "local\blender\jobs",
    "local\blender\exports",
    "local\reports",
    "local\backups"
)
foreach ($Dir in $LocalDirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $RepoRoot $Dir) | Out-Null
}

python tools/workstation/pc_preflight.py --repo $RepoRoot
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Le poste n'est pas encore complet. Consulte local/reports/pc_preflight.json."
    exit $LASTEXITCODE
}
Write-Host "Poste LITD pret." -ForegroundColor Green
