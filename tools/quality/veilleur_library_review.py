#!/usr/bin/env python3
"""Conservative governed review layer for Veilleur triage output.

This layer prepares library review candidates, contradiction checks and impact
assessment. It never promotes knowledge, marks canon obsolete, or creates a
Core change automatically. Contradiction/obsolescence require structured links
rather than fuzzy text guesses.
"""
from __future__ import annotations
import argparse,json
from hashlib import sha256
from pathlib import Path
from typing import Any

def _hash(payload:dict[str,Any])->str:
    raw=json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()

def build_review_batch(triage:dict[str,Any], canonical_records:list[dict[str,Any]]|None=None)->dict[str,Any]:
    if triage.get("kind")!="LITD_VEILLEUR_TRIAGE_BATCH": raise ValueError("invalid triage batch kind")
    for key in ("core_write_allowed","automatic_library_write_allowed","automatic_core_change_candidate_allowed"):
        if triage.get(key) is not False: raise ValueError(f"triage authority violation:{key}")
    canonical_records=canonical_records or []
    by_hash={r.get("canonical_hash"):r for r in canonical_records if isinstance(r,dict) and r.get("canonical_hash")}
    items=[]
    for row in triage.get("items",[]):
        if not isinstance(row,dict): continue
        if not row.get("library_candidate"):
            items.append({"evidence_id":row.get("evidence_id"),"status":"NOT_CANDIDATE","route":row.get("route"),"core_write_allowed":False})
            continue
        canonical_hash=row.get("canonical_hash")
        exact=by_hash.get(canonical_hash)
        contradiction={"status":"EXACT_CANONICAL_MATCH" if exact else "REVIEW_REQUIRED","canonical_record_id":exact.get("record_id") if exact else None,"automatic_contradiction_decision_allowed":False}
        obsolescence={"status":"NO_CHANGE" if exact else "REVIEW_REQUIRED","supersedes_record_id":None,"automatic_obsolescence_allowed":False}
        impact=row.get("impact_analysis") if isinstance(row.get("impact_analysis"),dict) else {}
        candidate={"kind":"LITD_LIBRARY_REVIEW_CANDIDATE","evidence_id":row.get("evidence_id"),"canonical_hash":canonical_hash,"route":row.get("route"),"route_confidence":row.get("route_confidence"),"cross_reference":bool(row.get("cross_reference",False)),"contradiction":contradiction,"obsolescence":obsolescence,"impact":{"scopes":list(impact.get("scopes",[])),"status":"REVIEW_REQUIRED" if row.get("route")=="LITD_LIBRARY" else "GENERAL_KNOWLEDGE_REVIEW","requires_core_review":row.get("route")=="LITD_LIBRARY","automatic_core_change_candidate_allowed":False},"allowed_review_decisions":["PROMOTE_TO_LIBRARY","KEEP_QUARANTINED","REQUEST_MORE_EVIDENCE","LINK_AS_CROSS_REFERENCE","PROPOSE_SUPERSESSION"],"core_write_allowed":False,"automatic_library_write_allowed":False}
        candidate["candidate_hash"]=_hash(candidate)
        items.append(candidate)
    summary={"review_candidates":sum(i.get("kind")=="LITD_LIBRARY_REVIEW_CANDIDATE" for i in items),"contradiction_reviews_required":sum(i.get("contradiction",{}).get("status")=="REVIEW_REQUIRED" for i in items),"obsolescence_reviews_required":sum(i.get("obsolescence",{}).get("status")=="REVIEW_REQUIRED" for i in items),"core_reviews_required":sum(i.get("impact",{}).get("requires_core_review") is True for i in items)}
    result={"kind":"LITD_VEILLEUR_LIBRARY_REVIEW_BATCH","status":"READY_FOR_GOVERNED_REVIEW","summary":summary,"items":items,"core_write_allowed":False,"automatic_library_write_allowed":False,"automatic_obsolescence_allowed":False,"automatic_core_change_candidate_allowed":False,"next_stage":"GOVERNED_REVIEW_RESOLUTION"}
    result["review_batch_hash"]=_hash(result)
    return result

def main()->int:
    p=argparse.ArgumentParser(); p.add_argument("--triage",required=True); p.add_argument("--canonical-records"); p.add_argument("--output",default="reports/veilleur-library-review.json"); a=p.parse_args()
    triage=json.loads(Path(a.triage).read_text(encoding="utf-8")); records=json.loads(Path(a.canonical_records).read_text(encoding="utf-8")) if a.canonical_records else []
    if isinstance(records,dict): records=records.get("records",[])
    report=build_review_batch(triage,records); out=Path(a.output); out.parent.mkdir(parents=True,exist_ok=True); out.write_text(json.dumps(report,ensure_ascii=False,indent=2,sort_keys=True)+"\n",encoding="utf-8"); return 0
if __name__=="__main__": raise SystemExit(main())
