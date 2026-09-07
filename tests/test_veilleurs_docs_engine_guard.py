from pathlib import Path

ROOT = Path(__file__).parents[1]
FORBIDDEN_GODOT_43_MARKERS = (
    "Godot 4.3",
    "godot4.3",
    "barichello/godot-ci:4.3",
    "Godot_v4.3-stable_win64",
)


def test_current_veilleurs_documentation_does_not_reference_godot_43():
    paths = [ROOT / "README.md"]
    paths.extend(sorted((ROOT / "docs" / "veilleurs").glob("*.md")))
    for path in paths:
        text = path.read_text(encoding="utf-8")
        for marker in FORBIDDEN_GODOT_43_MARKERS:
            assert marker not in text, f"{path.relative_to(ROOT)}: stale marker {marker}"
