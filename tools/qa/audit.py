
#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, html, json, re, sys
import yaml
from tools.qa.contracts import DATA_FILES, duplicate_ids, load_json, missing_fields

ROOT = Path(__file__).resolve().parents[2]

class Audit:
    def __init__(self): self.results=[]
    def check(self, name, ok, detail=""):
        self.results.append({"name":name,"ok":bool(ok),"detail":detail})
    @property
    def failed(self): return [r for r in self.results if not r["ok"]]

def run(root=ROOT):
    a=Audit(); data_dir=root/'data'
    loaded={}
    for filename in sorted(DATA_FILES):
        path=data_dir/filename
        a.check(f"data/{filename} présent", path.exists())
        if not path.exists(): continue
        try:
            payload=load_json(path); loaded[filename]=payload
            a.check(f"data/{filename} JSON valide", isinstance(payload,list), f"type={type(payload).__name__}")
            if isinstance(payload,list):
                a.check(f"data/{filename} IDs uniques", not duplicate_ids(payload), str(sorted(duplicate_ids(payload))))
                misses=[(i,sorted(missing_fields(filename,x))) for i,x in enumerate(payload) if isinstance(x,dict) and missing_fields(filename,x)]
                a.check(f"data/{filename} contrat", not misses, str(misses[:5]))
        except Exception as exc: a.check(f"data/{filename} JSON valide", False, str(exc))

    classes={x['id'] for x in loaded.get('classes.json',[]) if 'id' in x}
    races={x['id'] for x in loaded.get('races.json',[]) if 'id' in x}
    heroes=loaded.get('heroes.json',[])
    a.check('Références classes des héros', all(h.get('class_id') in classes for h in heroes))
    a.check('Références races des héros', all(h.get('race_id') in races for h in heroes))

    missing=[]
    for c in loaded.get('classes.json',[]):
        p=root/'assets/heroes'/c.get('art','')
        if not p.is_file(): missing.append(str(p.relative_to(root)))
    for e in loaded.get('enemies.json',[]):
        p=root/'assets/enemies'/e.get('art','')
        if not p.is_file(): missing.append(str(p.relative_to(root)))
    a.check('Illustrations référencées présentes', not missing, ', '.join(missing[:10]))

    resource_pattern=re.compile(r'res://[A-Za-z0-9_./-]+')
    broken=[]
    for p in list(root.rglob('*.gd'))+list(root.rglob('*.tscn'))+list(root.rglob('*.godot')):
        text=p.read_text(encoding='utf-8',errors='replace')
        for ref in resource_pattern.findall(text):
            target=root/ref.removeprefix('res://')
            if not target.exists(): broken.append(f"{p.relative_to(root)} -> {ref}")
    a.check('Références res:// valides', not broken, '; '.join(broken[:10]))

    conflicts=[]
    for p in root.rglob('*'):
        if p.is_file() and '.git' not in p.parts and p.name != 'audit.py' and p.suffix in {'.gd','.py','.json','.md','.yml','.yaml','.tscn','.godot'}:
            txt=p.read_text(encoding='utf-8',errors='replace')
            if '<<<<<<< ' in txt or '>>>>>>> ' in txt: conflicts.append(str(p.relative_to(root)))
    a.check('Aucun marqueur de conflit Git', not conflicts, ', '.join(conflicts))

    yaml_errors=[]
    for p in (root/'.github/workflows').glob('*.yml'):
        try: yaml.safe_load(p.read_text(encoding='utf-8'))
        except Exception as exc: yaml_errors.append(f"{p.name}: {exc}")
    a.check('Workflows YAML valides', not yaml_errors, '; '.join(yaml_errors))
    return a

def write_reports(a, outdir):
    outdir.mkdir(parents=True,exist_ok=True)
    payload={'summary':{'passed':len(a.results)-len(a.failed),'failed':len(a.failed),'total':len(a.results)},'checks':a.results}
    (outdir/'qa-report.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding='utf-8')
    rows=''.join(f"<tr class={'ok' if r['ok'] else 'fail'}><td>{html.escape(r['name'])}</td><td>{'OK' if r['ok'] else 'ÉCHEC'}</td><td>{html.escape(r['detail'])}</td></tr>" for r in a.results)
    doc=("<!doctype html><html lang='fr'><meta charset='utf-8'><title>Rapport QA</title>"
         "<style>body{font-family:system-ui;max-width:1100px;margin:2rem auto;background:#111;color:#eee}"
         "table{width:100%;border-collapse:collapse}td,th{padding:.65rem;border:1px solid #444}"
         ".ok{background:#16351f}.fail{background:#4a1717}</style>"
         f"<h1>Light in the Dark — Rapport QA</h1><p>{payload['summary']}</p>"
         f"<table><tr><th>Contrôle</th><th>État</th><th>Détail</th></tr>{rows}</table></html>")
    (outdir/'qa-report.html').write_text(doc,encoding='utf-8')

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--root',type=Path,default=ROOT); parser.add_argument('--out',type=Path,default=ROOT/'reports'); args=parser.parse_args()
    a=run(args.root); write_reports(a,args.out)
    for r in a.results: print(('PASS' if r['ok'] else 'FAIL'), '-', r['name'], r['detail'])
    print(f"RESULT: {len(a.results)-len(a.failed)} passed, {len(a.failed)} failed")
    return 1 if a.failed else 0
if __name__=='__main__': raise SystemExit(main())
