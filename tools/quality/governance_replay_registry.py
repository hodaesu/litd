#!/usr/bin/env python3
"""Stateful replay-protection contract for governance receipts.

This SQLite implementation is a local contract/prototype for #331. Production
closure still requires the durable Supabase/PostgreSQL registry described there.
"""
from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from hashlib import sha256
from pathlib import Path

PROJECT_ID = "LITD"
TARGET_ROUTE = "LITD_LIBRARY"


@dataclass(frozen=True)
class ConsumeResult:
    accepted: bool
    reason: str
    receipt_id: str
    consumer: str


def _hash(payload: dict[str, str]) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


class GovernanceReplayRegistry:
    """Atomic single-use registry with append-only audit evidence."""

    def __init__(self, path: str | Path):
        self.path = str(path)
        self.connection = sqlite3.connect(self.path, timeout=10, isolation_level=None, check_same_thread=False)
        self.connection.row_factory = sqlite3.Row
        self.connection.executescript(
            """
            PRAGMA journal_mode=WAL;
            PRAGMA busy_timeout=10000;
            CREATE TABLE IF NOT EXISTS receipts (
                receipt_id TEXT PRIMARY KEY,
                project_id TEXT NOT NULL,
                target_route TEXT NOT NULL,
                candidate_hash TEXT NOT NULL,
                receipt_hash TEXT NOT NULL UNIQUE,
                critical_context_hash TEXT NOT NULL,
                state TEXT NOT NULL CHECK(state IN ('active','consumed','superseded','revoked')),
                registered_at TEXT NOT NULL,
                consumed_at TEXT,
                consumed_by TEXT
            );
            CREATE TABLE IF NOT EXISTS replay_audit (
                sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                receipt_id TEXT NOT NULL,
                project_id TEXT NOT NULL,
                target_route TEXT NOT NULL,
                receipt_hash TEXT NOT NULL,
                consumer TEXT NOT NULL,
                accepted INTEGER NOT NULL CHECK(accepted IN (0,1)),
                reason TEXT NOT NULL,
                recorded_at TEXT NOT NULL,
                previous_hash TEXT NOT NULL,
                entry_hash TEXT NOT NULL UNIQUE
            );
            CREATE TRIGGER IF NOT EXISTS replay_audit_no_update
            BEFORE UPDATE ON replay_audit BEGIN SELECT RAISE(ABORT, 'replay_audit_is_append_only'); END;
            CREATE TRIGGER IF NOT EXISTS replay_audit_no_delete
            BEFORE DELETE ON replay_audit BEGIN SELECT RAISE(ABORT, 'replay_audit_is_append_only'); END;
            """
        )

    def close(self) -> None:
        self.connection.close()

    @staticmethod
    def receipt_id(project_id: str, target_route: str, candidate_hash: str, receipt_hash: str) -> str:
        return _hash({
            "project_id": project_id,
            "target_route": target_route,
            "candidate_hash": candidate_hash,
            "receipt_hash": receipt_hash,
        })

    def register(self, *, project_id: str, target_route: str, candidate_hash: str,
                 receipt_hash: str, critical_context_hash: str) -> str:
        if project_id != PROJECT_ID or target_route != TARGET_ROUTE:
            raise ValueError("receipt scope mismatch")
        rid = self.receipt_id(project_id, target_route, candidate_hash, receipt_hash)
        now = datetime.now(timezone.utc).isoformat()
        self.connection.execute(
            "INSERT INTO receipts VALUES (?, ?, ?, ?, ?, ?, 'active', ?, NULL, NULL)",
            (rid, project_id, target_route, candidate_hash, receipt_hash, critical_context_hash, now),
        )
        return rid

    def supersede(self, receipt_id: str) -> None:
        self.connection.execute("UPDATE receipts SET state='superseded' WHERE receipt_id=? AND state='active'", (receipt_id,))

    def revoke(self, receipt_id: str) -> None:
        self.connection.execute("UPDATE receipts SET state='revoked' WHERE receipt_id=? AND state='active'", (receipt_id,))

    def _last_audit_hash(self) -> str:
        row = self.connection.execute("SELECT entry_hash FROM replay_audit ORDER BY sequence DESC LIMIT 1").fetchone()
        return row[0] if row else "GENESIS"

    def _append_audit(self, *, row: sqlite3.Row, consumer: str, accepted: bool, reason: str) -> None:
        recorded_at = datetime.now(timezone.utc).isoformat()
        previous_hash = self._last_audit_hash()
        payload = {
            "receipt_id": row["receipt_id"], "project_id": row["project_id"],
            "target_route": row["target_route"], "receipt_hash": row["receipt_hash"],
            "consumer": consumer, "accepted": str(int(accepted)), "reason": reason,
            "recorded_at": recorded_at, "previous_hash": previous_hash,
        }
        self.connection.execute(
            "INSERT INTO replay_audit(receipt_id,project_id,target_route,receipt_hash,consumer,accepted,reason,recorded_at,previous_hash,entry_hash) VALUES (?,?,?,?,?,?,?,?,?,?)",
            (row["receipt_id"], row["project_id"], row["target_route"], row["receipt_hash"], consumer,
             int(accepted), reason, recorded_at, previous_hash, _hash(payload)),
        )

    def consume(self, *, receipt_id: str, project_id: str, target_route: str,
                candidate_hash: str, receipt_hash: str, critical_context_hash: str,
                consumer: str) -> ConsumeResult:
        self.connection.execute("BEGIN IMMEDIATE")
        try:
            row = self.connection.execute("SELECT * FROM receipts WHERE receipt_id=?", (receipt_id,)).fetchone()
            if row is None:
                self.connection.execute("ROLLBACK")
                return ConsumeResult(False, "unknown_receipt", receipt_id, consumer)

            reason = "accepted"
            accepted = False
            if row["project_id"] != project_id or row["target_route"] != target_route:
                reason = "scope_mismatch"
            elif row["candidate_hash"] != candidate_hash or row["receipt_hash"] != receipt_hash:
                reason = "binding_mismatch"
            elif row["critical_context_hash"] != critical_context_hash:
                reason = "stale_context"
            elif row["state"] != "active":
                reason = f"receipt_{row['state']}"
            else:
                changed = self.connection.execute(
                    "UPDATE receipts SET state='consumed', consumed_at=?, consumed_by=? WHERE receipt_id=? AND state='active'",
                    (datetime.now(timezone.utc).isoformat(), consumer, receipt_id),
                ).rowcount
                accepted = changed == 1
                reason = "accepted" if accepted else "receipt_consumed"

            self._append_audit(row=row, consumer=consumer, accepted=accepted, reason=reason)
            self.connection.execute("COMMIT")
            return ConsumeResult(accepted, reason, receipt_id, consumer)
        except Exception:
            self.connection.execute("ROLLBACK")
            raise

    def verify_audit_chain(self) -> bool:
        previous = "GENESIS"
        for row in self.connection.execute("SELECT * FROM replay_audit ORDER BY sequence"):
            if row["previous_hash"] != previous:
                return False
            payload = {
                "receipt_id": row["receipt_id"], "project_id": row["project_id"],
                "target_route": row["target_route"], "receipt_hash": row["receipt_hash"],
                "consumer": row["consumer"], "accepted": str(row["accepted"]), "reason": row["reason"],
                "recorded_at": row["recorded_at"], "previous_hash": row["previous_hash"],
            }
            expected = _hash(payload)
            if expected != row["entry_hash"]:
                return False
            previous = row["entry_hash"]
        return True
