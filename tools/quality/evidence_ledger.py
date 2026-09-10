#!/usr/bin/env python3
"""Persistent evidence registry and append-only hash-chained decision ledger for LITD."""
from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from hashlib import sha256
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class LedgerAppendResult:
    sequence: int
    entry_hash: str
    previous_hash: str


class EvidenceLedger:
    """SQLite-backed durable registry used by the VEILLEUR V2 ingress path.

    The database stores canonical evidence ids/hashes and an append-only routing
    decision history. Every decision entry includes the previous entry hash, so
    accidental or malicious rewrites are detectable by verify_chain().
    """

    def __init__(self, path: str | Path):
        self.path = str(path)
        self.connection = sqlite3.connect(self.path)
        self.connection.row_factory = sqlite3.Row
        self._init_schema()

    def _init_schema(self) -> None:
        self.connection.executescript(
            """
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS evidence_registry (
                evidence_id TEXT PRIMARY KEY,
                canonical_hash TEXT NOT NULL UNIQUE,
                source_url TEXT NOT NULL,
                first_seen_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS decision_ledger (
                sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                evidence_id TEXT NOT NULL,
                decision TEXT NOT NULL,
                reason TEXT NOT NULL,
                recorded_at TEXT NOT NULL,
                previous_hash TEXT NOT NULL,
                entry_hash TEXT NOT NULL UNIQUE
            );
            CREATE TRIGGER IF NOT EXISTS decision_ledger_no_update
            BEFORE UPDATE ON decision_ledger
            BEGIN
                SELECT RAISE(ABORT, 'decision_ledger_is_append_only');
            END;
            CREATE TRIGGER IF NOT EXISTS decision_ledger_no_delete
            BEFORE DELETE ON decision_ledger
            BEGIN
                SELECT RAISE(ABORT, 'decision_ledger_is_append_only');
            END;
            """
        )
        self.connection.commit()

    def close(self) -> None:
        self.connection.close()

    def known_evidence_ids(self) -> set[str]:
        rows = self.connection.execute("SELECT evidence_id FROM evidence_registry")
        return {row[0] for row in rows}

    def known_hashes(self) -> set[str]:
        rows = self.connection.execute("SELECT canonical_hash FROM evidence_registry")
        return {row[0] for row in rows}

    def register_evidence(self, evidence_id: str, canonical_hash: str, source_url: str) -> None:
        now = datetime.now(timezone.utc).isoformat()
        self.connection.execute(
            "INSERT INTO evidence_registry(evidence_id, canonical_hash, source_url, first_seen_at) VALUES (?, ?, ?, ?)",
            (evidence_id, canonical_hash, source_url, now),
        )
        self.connection.commit()

    def _last_hash(self) -> str:
        row = self.connection.execute(
            "SELECT entry_hash FROM decision_ledger ORDER BY sequence DESC LIMIT 1"
        ).fetchone()
        return row[0] if row else "GENESIS"

    @staticmethod
    def _entry_hash(payload: dict[str, Any]) -> str:
        raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        return sha256(raw.encode("utf-8")).hexdigest()

    def append_decision(self, evidence_id: str, decision: str, reason: str) -> LedgerAppendResult:
        previous_hash = self._last_hash()
        recorded_at = datetime.now(timezone.utc).isoformat()
        payload = {
            "evidence_id": evidence_id,
            "decision": decision,
            "reason": reason,
            "recorded_at": recorded_at,
            "previous_hash": previous_hash,
        }
        entry_hash = self._entry_hash(payload)
        cursor = self.connection.execute(
            "INSERT INTO decision_ledger(evidence_id, decision, reason, recorded_at, previous_hash, entry_hash) VALUES (?, ?, ?, ?, ?, ?)",
            (evidence_id, decision, reason, recorded_at, previous_hash, entry_hash),
        )
        self.connection.commit()
        return LedgerAppendResult(int(cursor.lastrowid), entry_hash, previous_hash)

    def verify_chain(self) -> bool:
        previous_hash = "GENESIS"
        rows = self.connection.execute(
            "SELECT sequence, evidence_id, decision, reason, recorded_at, previous_hash, entry_hash FROM decision_ledger ORDER BY sequence"
        ).fetchall()
        for row in rows:
            if row["previous_hash"] != previous_hash:
                return False
            payload = {
                "evidence_id": row["evidence_id"],
                "decision": row["decision"],
                "reason": row["reason"],
                "recorded_at": row["recorded_at"],
                "previous_hash": row["previous_hash"],
            }
            expected = self._entry_hash(payload)
            if expected != row["entry_hash"]:
                return False
            previous_hash = row["entry_hash"]
        return True
