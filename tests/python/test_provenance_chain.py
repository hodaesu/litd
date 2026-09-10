import sqlite3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.quality.provenance_chain import ProvenanceChain, STAGES


def build_full_chain(chain: ProvenanceChain) -> list[str]:
    ids = []
    parent = None
    for index, stage in enumerate(STAGES):
        node_id = f"node-{index}-{stage.lower()}"
        chain.append(
            node_id=node_id,
            stage=stage,
            parent_id=parent,
            evidence_id="ev-1",
            external_ref=f"ref-{stage}" if stage in {"SOURCE", "COMMIT", "TEST"} else None,
            payload={"stage": stage, "value": index},
        )
        ids.append(node_id)
        parent = node_id
    return ids


def test_full_provenance_chain_is_complete(tmp_path):
    chain = ProvenanceChain(tmp_path / "provenance.db")
    ids = build_full_chain(chain)
    trace = chain.trace(ids[-1])
    assert [node.stage for node in trace] == list(STAGES)
    assert chain.chain_complete_through(ids[-1], "MEASUREMENT") is True
    assert chain.verify_integrity() is True
    chain.close()


def test_cannot_skip_core_decision_before_commit(tmp_path):
    chain = ProvenanceChain(tmp_path / "provenance.db")
    source = chain.append(node_id="s", stage="SOURCE", payload={"u": "https://example.org"})
    doc = chain.append(node_id="d", stage="DOCUMENT", parent_id=source.node_id, payload={"h": "x"})
    discovery = chain.append(node_id="x", stage="DISCOVERY", parent_id=doc.node_id, payload={"e": "ev"})
    route = chain.append(node_id="r", stage="ROUTING_DECISION", parent_id=discovery.node_id, payload={"route": "LITD_LIBRARY"})
    try:
        chain.append(node_id="c", stage="COMMIT", parent_id=route.node_id, payload={"sha": "abc"})
    except ValueError as exc:
        assert "invalid_parent_stage" in str(exc)
    else:
        raise AssertionError("COMMIT must not bypass CORE_DECISION")
    chain.close()


def test_source_must_be_root(tmp_path):
    chain = ProvenanceChain(tmp_path / "provenance.db")
    chain.append(node_id="s1", stage="SOURCE", payload={"u": "https://a.example"})
    try:
        chain.append(node_id="s2", stage="SOURCE", parent_id="s1", payload={"u": "https://b.example"})
    except ValueError as exc:
        assert str(exc) == "source_must_be_root"
    else:
        raise AssertionError("SOURCE must be root")
    chain.close()


def test_missing_parent_is_rejected(tmp_path):
    chain = ProvenanceChain(tmp_path / "provenance.db")
    try:
        chain.append(node_id="d", stage="DOCUMENT", parent_id="absent", payload={})
    except ValueError as exc:
        assert str(exc) == "missing_parent"
    else:
        raise AssertionError("missing parent should fail")
    chain.close()


def test_history_is_append_only(tmp_path):
    path = tmp_path / "provenance.db"
    chain = ProvenanceChain(path)
    chain.append(node_id="s", stage="SOURCE", payload={"u": "https://example.org"})
    try:
        chain.connection.execute("UPDATE provenance_nodes SET stage='DOCUMENT' WHERE node_id='s'")
    except sqlite3.DatabaseError as exc:
        assert "append_only" in str(exc)
    else:
        raise AssertionError("UPDATE should be blocked")
    try:
        chain.connection.execute("DELETE FROM provenance_nodes WHERE node_id='s'")
    except sqlite3.DatabaseError as exc:
        assert "append_only" in str(exc)
    else:
        raise AssertionError("DELETE should be blocked")
    chain.close()


def test_persists_across_reopen(tmp_path):
    path = tmp_path / "provenance.db"
    chain = ProvenanceChain(path)
    ids = build_full_chain(chain)
    chain.close()

    reopened = ProvenanceChain(path)
    assert reopened.chain_complete_through(ids[-1], "MEASUREMENT") is True
    assert reopened.verify_integrity() is True
    reopened.close()


def test_external_refs_are_unique_per_stage(tmp_path):
    chain = ProvenanceChain(tmp_path / "provenance.db")
    chain.append(node_id="s1", stage="SOURCE", external_ref="https://example.org", payload={"u": 1})
    try:
        chain.append(node_id="s2", stage="SOURCE", external_ref="https://example.org", payload={"u": 2})
    except sqlite3.IntegrityError:
        pass
    else:
        raise AssertionError("same external ref in same stage should be unique")
    chain.close()


def test_can_apply_without_core_decision_is_never_true_for_valid_chain(tmp_path):
    chain = ProvenanceChain(tmp_path / "provenance.db")
    ids = build_full_chain(chain)
    assert chain.can_apply_without_core_decision(ids[5]) is False
    chain.close()
