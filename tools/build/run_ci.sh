#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "==> Installation des dépendances de développement"
python -m pip install -r requirements-dev.txt

echo "==> Tests Python"
python -m pytest

echo "==> Audit QA de base"
python -m tools.qa.audit

echo "==> Audit transversal campagne et systèmes"
python -m tools.qa.cross_system_audit

echo "==> Audit progression, économie et NG+"
python -m tools.qa.balance_audit

echo "==> Audit tours complets et effets de talents"
python -m tools.qa.combat_turn_audit

echo "==> Audit rangs, déplacements et synergies tactiques"
python -m tools.qa.tactical_combat_audit

echo "==> Audit démembrements tactiques"
python -m tools.qa.dismemberment_audit

echo "==> Audit poussées, tractions et phases de boss"
python -m tools.qa.displacement_combat_audit

echo "==> Audit familles ennemies et réactions de membres"
python -m tools.qa.enemy_family_tactics_audit

echo "==> Audit anatomie avancée, capture, psychologie et Blender"
python -m tools.qa.anatomy_system_audit

echo "==> Génération des jobs Blender anatomiques"
python -m tools.blender.generate_dismemberment_jobs --output reports/dismemberment-jobs.json

echo "==> Simulation combat v2, économie et cycles NG+"
python -m tools.qa.combat_economy_sim_v2

if command -v godot >/dev/null 2>&1; then
  echo "==> Smoke test Godot"
  godot --headless --path . --import --quit
  godot --headless --path . --script res://scripts/core/smoke_test.gd
else
  echo "==> Godot non trouvé : smoke test local ignoré (il reste exécuté dans GitHub Actions)."
fi

echo "==> Vérification terminée"
