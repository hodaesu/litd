
#!/usr/bin/env python3
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[2]
version=sys.argv[1] if len(sys.argv)>1 else (root/'VERSION').read_text().strip()
changelog=(root/'CHANGELOG.md').read_text(encoding='utf-8')
print(f"# Light in the Dark {version}
")
print("Build automatisé par GitHub Actions.
")
print("## Changements
")
print(changelog[:6000])
