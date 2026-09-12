#!/usr/bin/env python3
"""Persistent, project-scoped evidence registry and append-only ledger for LITD."""
from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from hashlib import sha256
from pathlib import Path
from typing import Any

PROJECT_ID = "LITD"
TARGET_ROUTE = "LITD_LIBRARY"


@dataclass(frozen=True)
class LedgerAppendResult:
    sequence: int
    entry_hash: str
    previous_hash: str


class EvidenceLedger:
    """SQLite-backed durable registry for the LITD VEILLEUR V2 ingress path.

    Every evidence and decision row is explicitly bound to the LITD project and
    LITD library route. The decision ledger is hash-chained and append-only.
    """

    def __init__(self, path: str | Path, *, project_id: str = PROJECT_ID, target_route: str = TARGET_ROUTE):
        if project_id != PROJECT_ID:
            raise ValueError("ledger project scope mismatch")
        if target_route != TARGET_ROUTE:
            raise ValueError("ledger route scope mismatch")
        self.path = str(path)
        self.project_id = project_id
        self.target_route = target_route
        self.connection = sqlite3.connect(self.path)
        self.connection.row_factory = sqlite3.Row
        self._init_schema()

    def _columns(self, table: str) -> set[str]:
        return {row[1] for row in self.connection.execute(f"PRAGMA table_info({table})")}

    def _migrate_scope_columns(self) -> None:
        evidence_columns = self._columns("evidence_registry")
        if "project_id" not in evidence_columns:
            self.connection.execute("ALTER TABLE evidence_registry ADD COLUMN project_id TEXT NOT NULL DEFAULT 'LITD'")
        if "target_route" not in evidence_columns:
            self.connection.execute("ALTER TABLE evidence_registry ADD COLUMN target_route TEXT NOT NULL DEFAULT 'LITD_LIBRARY'")

        decision_columns = self._columns("decision_ledger")
        if "project_id" not in decision_columns:
            self.connection.execute("ALTER TABLE decision_ledger ADD COLUMN project_id TEXT NOT NULL DEFAULT 'LITD'")
        if "target_route" not in decision_columns:
            self.connection.execute("ALTER TABLE decision_ledger ADD COLUMN target_route TEXT NOT NULL DEFAULT 'LITD_LIBRARY'")

    def _init_schema(self) -> None:
        self.connection.executescript(
            """
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS evidence_registry (
                evidence_id TEXT PRIMARY KEY,
                canonical_hash TEXT NOT NULL UNIQUE,
                source_url TEXT NOT NULL,
                first_seen_at TEXT NOT NULL,
                project_id TEXT NOT NULL DEFAULT 'LITD',
                target_route TEXT NOT NULL DEFAULT 'LITD_LIBRARY'
            );
            CREATE TABLE IF NOT EXISTS decision_ledger (
                sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                evidence_id TEXT NOT NULL,
                decision TEXT NOT NULL,
                reason TEXT NOT NULL,
                recorded_at TEXT NOT NULL,
                project_id TEXT NOT NULL DEFAULT 'LITD',
                target_route TEXT NOT NULL DEFAULT 'LITD_LIBRARY',
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
        self._migrate_scope_columns()
        self.connection.commit()

    def close(self) -> None:
        self.connection.close()

    def known_evidence_ids(self) -> set[str]:
        rows = self.connection.execute(
            "SELECT evidence_id FROM evidence_registry WHERE project_id=? AND target_route=?",
            (self.project_id, self.target_route),
        )
        return {row[0] for row in rows}

    def known_hashes(self) -> set[str]:
        rows = self.connection.execute(
            "SELECT canonical_hash FROM evidence_registry WHERE project_id=? AND target_route=?",
            (self.project_id, self.target_route),
        )
        return {row[0] for row in rows}

    def register_evidence(self, evidence_id: str, canonical_hash: str, source_url: str) -> None:
        now = datetime.now(timezone.utc).isoformat()
        self.connection.execute(
            "INSERT INTO evidence_registry(evidence_id, canonical_hash, source_url, first_seen_at, project_id, target_route) VALUES (?, ?, ?, ?, ?, ?)",
            (evidence_id, canonical_hash, source_url, now, self.project_id, self.target_route),
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
            "project_id": self.project_id,
            "target_route": self.target_route,
            "evidence_id": evidence_id,
            "decision": decision,
            "reason": reason,
            "recorded_at": recorded_at,
            "previous_hash": previous_hash,
        }
        entry_hash = self._entry_hash(payload)
        cursor = self.connection.execute(
            "INSERT INTO decision_ledger(evidence_id, decision, reason, recorded_at, project_id, target_route, previous_hash, entry_hash) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                evidence_id,
                decision,
                reason,
                recorded_at,
                self.project_id,
                self.target_route,
                previous_hash,
                entry_hash,
            ),
        )
        self.connection.commit()
        return LedgerAppendResult(int(cursor.lastrowid), entry_hash, previous_hash)

    def verify_chain(self) -> bool:
        previous_hash = "GENESIS"
        rows = self.connection.execute(
            "SELECT sequence, evidence_id, decision, reason, recorded_at, project_id, target_route, previous_hash, entry_hash FROM decision_ledger ORDER BY sequence"
        ).fetchall()
        for row in rows:
            if row["previous_hash"] != previous_hash:
                return False
            if row["project_id"] != self.project_id or row["target_route"] != self.target_route:
                return False
            payload = {
                "project_id": row["project_id"],
                "target_route": row["target_route"],
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
