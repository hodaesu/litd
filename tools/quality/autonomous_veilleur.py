#!/usr/bin/env python3
from __future__ import annotations
import argparse,html,json,re,urllib.request,xml.etree.ElementTree as ET
from datetime import datetime,timezone
from hashlib import sha256
from pathlib import Path
from typing import Any
from urllib.parse import urlparse
from tools.quality.source_registry import enabled_sources,load_registry
from tools.quality.veilleur_v2_ingest import canonical_content_hash,validate_event
USER_AGENT="LITD-Veilleur/1.0 (+https://github.com/hodaesu/litd)"
TAG_RE=re.compile(r"<[^>]+>"); SPACE_RE=re.compile(r"\s+")
def _clean_text(value:str|None)->str: return SPACE_RE.sub(" ",TAG_RE.sub(" ",html.unescape(value or ""))).strip()
def _iso(value:str)->str:
    raw=value.strip()
    try: dt=datetime.fromisoformat(raw.replace("Z","+00:00"))
    except ValueError:
        from email.utils import parsedate_to_datetime
        dt=parsedate_to_datetime(raw)
    if dt.tzinfo is None: raise ValueError("naive publication timestamp")
    return dt.astimezone(timezone.utc).isoformat().replace("+00:00","Z")
def _event(source,title,summary,link,published_at,discovered_at):
    if urlparse(link).scheme!="https": raise ValueError("feed item link is not HTTPS")
    stable=sha256(f"{source['source_id']}\n{link}\n{title}".encode()).hexdigest()[:24]
    e={"evidence_id":f"veilleur:{source['source_id']}:{stable}","title":title[:500],"summary":summary[:5000],"source_url":link,"source_verified":True,"source_confidence":source["source_confidence"],"discovered_at":discovered_at,"published_at":published_at,"domain_hints":source["domain_hints"]}
    e["content_hash"]=canonical_content_hash(e["title"],e["summary"],e["source_url"]); return e
def parse_feed(payload:bytes,source:dict[str,Any],discovered_at:str):
    root=ET.fromstring(payload); rows=[]; fmt=source["format"]
    if fmt=="atom":
        ns={"a":"http://www.w3.org/2005/Atom"}
        for entry in root.findall("a:entry",ns):
            title=_clean_text(entry.findtext("a:title",default="",namespaces=ns)); summary=_clean_text(entry.findtext("a:summary",default="",namespaces=ns) or entry.findtext("a:content",default="",namespaces=ns)); published=entry.findtext("a:published",default="",namespaces=ns) or entry.findtext("a:updated",default="",namespaces=ns); link=""
            for node in entry.findall("a:link",ns):
                if node.attrib.get("rel","alternate")=="alternate" and node.attrib.get("href"): link=node.attrib["href"]; break
            if title and summary and published and link: rows.append(_event(source,title,summary,link,_iso(published),discovered_at))
    elif fmt=="rss":
        for item in root.findall("./channel/item"):
            title=_clean_text(item.findtext("title")); summary=_clean_text(item.findtext("description")); link=(item.findtext("link") or "").strip(); published=(item.findtext("pubDate") or "").strip()
            if title and summary and published and link: rows.append(_event(source,title,summary,link,_iso(published),discovered_at))
    else: raise ValueError(f"unsupported feed format: {fmt}")
    return rows
def fetch_bytes(source,*,timeout,max_bytes):
    parsed=urlparse(source["url"])
    if parsed.scheme!="https" or parsed.hostname!=source["allowed_host"]: raise ValueError("source URL violates registry host policy")
    req=urllib.request.Request(source["url"],headers={"User-Agent":USER_AGENT,"Accept":"application/atom+xml, application/rss+xml, application/xml, text/xml"})
    with urllib.request.urlopen(req,timeout=timeout) as response:
        final=urlparse(response.geturl())
        if final.scheme!="https" or final.hostname!=source["allowed_host"]: raise ValueError("redirect escaped allowed host")
        data=response.read(max_bytes+1)
    if len(data)>max_bytes: raise ValueError("source response exceeds maximum size")
    return data
def run(registry,*,fetcher=fetch_bytes,now=None):
    policy=registry["policy"]; discovered_at=(now or datetime.now(timezone.utc)).astimezone(timezone.utc).isoformat().replace("+00:00","Z"); candidates=[]; failures=[]
    for source in enabled_sources(registry):
        try:
            for event in parse_feed(fetcher(source,timeout=int(policy["timeout_seconds"]),max_bytes=int(policy["max_response_bytes"])),source,discovered_at):
                d=validate_event(event); candidates.append(event) if d.accepted else failures.append({"source_id":source["source_id"],"reason":f"ingress:{d.status}:{d.reason}"})
        except Exception as exc: failures.append({"source_id":source["source_id"],"reason":f"fetch_or_parse:{type(exc).__name__}:{exc}"})
    candidates.sort(key=lambda r:(r["published_at"],r["evidence_id"]),reverse=True)
    return {"kind":"LITD_VEILLEUR_DISCOVERY_BATCH","status":"OK" if not failures else "PARTIAL","generated_at":discovered_at,"candidate_count":len(candidates),"failure_count":len(failures),"candidates":candidates,"failures":failures,"core_write_allowed":False,"automatic_library_write_allowed":False,"next_stage":"VEILLEUR_V2_INGRESS_AND_TRIAGE"}
def main():
    p=argparse.ArgumentParser(); p.add_argument("--registry",default="docs/knowledge/source-registry.json"); p.add_argument("--output",default="reports/veilleur-discovery.json"); a=p.parse_args(); r=run(load_registry(a.registry)); o=Path(a.output); o.parent.mkdir(parents=True,exist_ok=True); o.write_text(json.dumps(r,ensure_ascii=False,indent=2,sort_keys=True)+"\n",encoding="utf-8"); return 0
if __name__=="__main__": raise SystemExit(main())
