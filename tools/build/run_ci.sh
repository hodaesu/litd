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

if command -v godot >/dev/null 2>&1; then
  echo "==> Smoke test Godot"
  godot --headless --path . --import --quit
  godot --headless --path . --script res://scripts/core/smoke_test.gd
else
  echo "==> Godot non trouvé : smoke test local ignoré (il reste exécuté dans GitHub Actions)."
fi

echo "==> Vérification terminée"
