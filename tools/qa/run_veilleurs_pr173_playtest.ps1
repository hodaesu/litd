param(
    [ValidateSet('qa','khar-sen','tactical','editor','gate')]
    [string]$Mode = 'qa',
    [string]$GodotBin = $env:GODOT_BIN,
    [string]$Results = 'data/veilleurs/qa/premerge_playtest_results_template_v1.json'
)

$ErrorActionPreference = 'Stop'
$repo = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repo

function Resolve-Godot {
    param([string]$Requested)
    if ($Requested) {
        if (-not (Test-Path $Requested)) { throw "GODOT_BIN introuvable: $Requested" }
        return (Resolve-Path $Requested).Path
    }
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $cmd) { $cmd = Get-Command godot.exe -ErrorAction SilentlyContinue }
    if (-not $cmd) {
        throw "Godot introuvable. Installe Godot 4.3 ou définis GODOT_BIN vers godot.exe."
    }
    return $cmd.Source
}

function Start-GodotScene {
    param([string]$Scene)
    $godot = Resolve-Godot $GodotBin
    Write-Host "Godot: $godot"
    Write-Host "Projet: $repo"
    Write-Host "Scène: $Scene"
    & $godot --path $repo $Scene
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

switch ($Mode) {
    'qa' {
        Write-Host 'PLAYTEST PR173 — Salle QA'
        Write-Host 'Ordre conseillé: QA de base -> Khar-Sen gauche -> Khar-Sen droite -> Rémanence/recrutement -> boss.'
        Start-GodotScene 'res://scenes/qa/qa_validation_room.tscn'
    }
    'khar-sen' {
        Write-Host 'PLAYTEST PR173 — Khar-Sen'
        Start-GodotScene 'res://scenes/veilleurs/v061_khar_sen_slice.tscn'
    }
    'tactical' {
        Write-Host 'PLAYTEST PR173 — Combat tactique v0.6.1'
        Start-GodotScene 'res://scenes/veilleurs/v061_tactical_demo.tscn'
    }
    'editor' {
        $godot = Resolve-Godot $GodotBin
        Write-Host 'Ouverture de Godot en mode éditeur.'
        & $godot --editor --path $repo
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    'gate' {
        if (-not (Test-Path $Results)) { throw "Fichier de résultats introuvable: $Results" }
        $python = Get-Command python -ErrorAction SilentlyContinue
        if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
        if (-not $python) { throw 'Python introuvable pour calculer le verdict MERGE/NO_MERGE.' }
        Write-Host "Évaluation du gate avec: $Results"
        & $python.Source tools/qa/veilleurs_pr173_playtest_gate.py --results $Results
        exit $LASTEXITCODE
    }
}
