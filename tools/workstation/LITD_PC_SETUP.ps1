param(
    [switch]$Install,
    [switch]$SkipBackup,
    [switch]$VerifyRemote,
    [string]$HeavyDataRoot = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $RepoRoot

Write-Host "LITD - preparation du poste Windows" -ForegroundColor Cyan

if ($VerifyRemote -and (Get-Command git -ErrorAction SilentlyContinue)) {
    git fetch origin --prune
    if ($LASTEXITCODE -ne 0) { throw "Impossible de verifier le depot distant." }
    $LocalHead = (git rev-parse HEAD).Trim()
    $RemoteHead = (git rev-parse origin/main).Trim()
    if ($LocalHead -ne $RemoteHead) {
        throw "Le clone n'est pas exactement sur origin/main. Local=$LocalHead Distant=$RemoteHead"
    }
    if (git status --porcelain) {
        throw "Le depot contient des modifications locales. Sauvegardez-les avant le transfert."
    }
    Write-Host "GitHub verifie : HEAD correspond a origin/main." -ForegroundColor Green
}

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
    @{ Name = "Git LFS"; Id = "GitHub.GitLFS" },
    @{ Name = "Python 3.12"; Id = "Python.Python.3.12" },
    @{ Name = "Godot"; Id = "GodotEngine.GodotEngine" },
    @{ Name = "Blender"; Id = "BlenderFoundation.Blender" },
    @{ Name = "MuseScore Studio"; Id = "MuseScore.MuseScore" },
    @{ Name = "REAPER"; Id = "Cockos.REAPER" },
    @{ Name = "Epic Games Launcher"; Id = "EpicGames.EpicGamesLauncher" }
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
    Write-Host "Installation/verif : Visual Studio 2022 et composants Unreal"
    winget install --id Microsoft.VisualStudio.2022.Community --exact `
        --override "--wait --passive --add Microsoft.VisualStudio.Workload.NativeGame --includeRecommended" `
        --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Visual Studio n'a pas pu etre installe automatiquement. Selectionnez 'Developpement de jeux en C++', MSVC et le SDK Windows dans Visual Studio Installer."
    }
} else {
    Write-Host "Mode diagnostic. Relance avec -Install pour installer les logiciels manquants."
}

$DataRoot = if ($HeavyDataRoot) {
    New-Item -ItemType Directory -Force -Path $HeavyDataRoot | Out-Null
    (Resolve-Path $HeavyDataRoot).Path
} else {
    Join-Path $RepoRoot "local"
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
    $Relative = $Dir -replace '^local\\', ''
    $Target = Join-Path $DataRoot $Relative
    New-Item -ItemType Directory -Force -Path $Target | Out-Null
}

if ($HeavyDataRoot) {
    $LinkPath = Join-Path $RepoRoot "local"
    if (-not (Test-Path $LinkPath)) {
        New-Item -ItemType Junction -Path $LinkPath -Target $DataRoot | Out-Null
        Write-Host "Donnees lourdes redirigees vers : $DataRoot" -ForegroundColor Green
    } else {
        Write-Warning "Le dossier local existe deja : jonction non creee. Utilisez un clone neuf ou deplacez son contenu manuellement."
    }
}

if (Get-Command git -ErrorAction SilentlyContinue) {
    git lfs install --local
    if ($LASTEXITCODE -ne 0) { Write-Warning "Git LFS n'est pas encore operationnel." }
}

python tools/workstation/pc_preflight.py --repo $RepoRoot --minimum-free-gb 150
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Le poste n'est pas encore complet. Consulte local/reports/pc_preflight.json."
    exit $LASTEXITCODE
}
Write-Host "Poste LITD pret." -ForegroundColor Green
