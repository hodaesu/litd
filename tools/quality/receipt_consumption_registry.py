#!/usr/bin/env python3
"""Stateful single-use receipt registry for governance replay protection.

This is a SQLite contract/prototype for P0 #331. Production durability and
multi-project coordination belong in the target PostgreSQL/Supabase registry.
The module deliberately grants no Core, merge, application, or target authority.
"""
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
HEX64 = set("0123456789abcdef")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _hash(payload: dict[str, Any]) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def _hex64(value: Any) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(ch in HEX64 for ch in value)


@dataclass(frozen=True)
class ConsumptionResult:
    accepted: bool
    status: str
    reason: str
    receipt_hash: str
    audit_entry_hash: str


class ReceiptConsumptionRegistry:
    """Append-only, project-scoped single-use receipt registry.

    Each registered receipt is bound to one project, route, source hash,
    critical-context hash, and expected consumer. Consumption occurs under
    ``BEGIN IMMEDIATE`` and is represented by a unique append-only row, so two
    concurrent consumers cannot both win on the same SQLite database.
    """

    def __init__(self, path: str | Path, *, project_id: str = PROJECT_ID, target_route: str = TARGET_ROUTE):
        if project_id != PROJECT_ID:
            raise ValueError("registry project scope mismatch")
        if target_route != TARGET_ROUTE:
            raise ValueError("registry route scope mismatch")
        self.path = str(path)
        self.project_id = project_id
        self.target_route = target_route
        self.connection = sqlite3.connect(self.path, timeout=10.0, isolation_level=None)
        self.connection.row_factory = sqlite3.Row
        self.connection.execute("PRAGMA busy_timeout=10000")
        self.connection.execute("PRAGMA journal_mode=WAL")
        self._init_schema()

    def _init_schema(self) -> None:
        self.connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS registered_receipts (
                receipt_hash TEXT PRIMARY KEY,
                receipt_id TEXT NOT NULL UNIQUE,
                receipt_kind TEXT NOT NULL,
                project_id TEXT NOT NULL,
                target_route TEXT NOT NULL,
                source_hash TEXT NOT NULL,
                context_hash TEXT NOT NULL,
                expected_consumer TEXT NOT NULL,
                registered_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS receipt_consumptions (
                receipt_hash TEXT PRIMARY KEY,
                consumer TEXT NOT NULL,
                actor TEXT NOT NULL,
                consumed_at TEXT NOT NULL,
                current_context_hash TEXT NOT NULL,
                FOREIGN KEY(receipt_hash) REFERENCES registered_receipts(receipt_hash)
            );
            CREATE TABLE IF NOT EXISTS receipt_invalidations (
                receipt_hash TEXT PRIMARY KEY,
                invalidation_kind TEXT NOT NULL CHECK(invalidation_kind IN ('REVOKED','SUPERSEDED')),
                reason TEXT NOT NULL,
                replacement_receipt_hash TEXT,
                actor TEXT NOT NULL,
                invalidated_at TEXT NOT NULL,
                FOREIGN KEY(receipt_hash) REFERENCES registered_receipts(receipt_hash)
            );
            CREATE TABLE IF NOT EXISTS consumption_audit (
                sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                receipt_hash TEXT NOT NULL,
                project_id TEXT NOT NULL,
                target_route TEXT NOT NULL,
                consumer TEXT NOT NULL,
                actor TEXT NOT NULL,
                current_context_hash TEXT NOT NULL,
                outcome TEXT NOT NULL,
                reason TEXT NOT NULL,
                recorded_at TEXT NOT NULL,
                previous_hash TEXT NOT NULL,
                entry_hash TEXT NOT NULL UNIQUE
            );

            CREATE TRIGGER IF NOT EXISTS registered_receipts_no_update
            BEFORE UPDATE ON registered_receipts BEGIN SELECT RAISE(ABORT, 'registered_receipts_append_only'); END;
            CREATE TRIGGER IF NOT EXISTS registered_receipts_no_delete
            BEFORE DELETE ON registered_receipts BEGIN SELECT RAISE(ABORT, 'registered_receipts_append_only'); END;
            CREATE TRIGGER IF NOT EXISTS receipt_consumptions_no_update
            BEFORE UPDATE ON receipt_consumptions BEGIN SELECT RAISE(ABORT, 'receipt_consumptions_append_only'); END;
            CREATE TRIGGER IF NOT EXISTS receipt_consumptions_no_delete
            BEFORE DELETE ON receipt_consumptions BEGIN SELECT RAISE(ABORT, 'receipt_consumptions_append_only'); END;
            CREATE TRIGGER IF NOT EXISTS receipt_invalidations_no_update
            BEFORE UPDATE ON receipt_invalidations BEGIN SELECT RAISE(ABORT, 'receipt_invalidations_append_only'); END;
            CREATE TRIGGER IF NOT EXISTS receipt_invalidations_no_delete
            BEFORE DELETE ON receipt_invalidations BEGIN SELECT RAISE(ABORT, 'receipt_invalidations_append_only'); END;
            CREATE TRIGGER IF NOT EXISTS consumption_audit_no_update
            BEFORE UPDATE ON consumption_audit BEGIN SELECT RAISE(ABORT, 'consumption_audit_append_only'); END;
            CREATE TRIGGER IF NOT EXISTS consumption_audit_no_delete
            BEFORE DELETE ON consumption_audit BEGIN SELECT RAISE(ABORT, 'consumption_audit_append_only'); END;
            """
        )

    def close(self) -> None:
        self.connection.close()

    def register_receipt(
        self,
        *,
        receipt_id: str,
        receipt_hash: str,
        receipt_kind: str,
        source_hash: str,
        context_hash: str,
        expected_consumer: str,
    ) -> None:
        if not receipt_id.strip() or not receipt_kind.strip() or not expected_consumer.strip():
            raise ValueError("receipt identity, kind and expected consumer are required")
        for label, value in (("receipt_hash", receipt_hash), ("source_hash", source_hash), ("context_hash", context_hash)):
            if not _hex64(value):
                raise ValueError(f"{label} must be 64 lowercase hex")
        self.connection.execute("BEGIN IMMEDIATE")
        try:
            self.connection.execute(
                "INSERT INTO registered_receipts(receipt_hash,receipt_id,receipt_kind,project_id,target_route,source_hash,context_hash,expected_consumer,registered_at) VALUES (?,?,?,?,?,?,?,?,?)",
                (
                    receipt_hash,
                    receipt_id.strip(),
                    receipt_kind.strip(),
                    self.project_id,
                    self.target_route,
                    source_hash,
                    context_hash,
                    expected_consumer.strip(),
                    _now(),
                ),
            )
            self.connection.execute("COMMIT")
        except Exception:
            self.connection.execute("ROLLBACK")
            raise

    def invalidate_receipt(
        self,
        receipt_hash: str,
        *,
        kind: str,
        reason: str,
        actor: str,
        replacement_receipt_hash: str | None = None,
    ) -> None:
        if kind not in {"REVOKED", "SUPERSEDED"}:
            raise ValueError("unsupported invalidation kind")
        if not reason.strip() or not actor.strip():
            raise ValueError("invalidation reason and actor are required")
        if kind == "SUPERSEDED" and not _hex64(replacement_receipt_hash):
            raise ValueError("supersession requires replacement receipt hash")
        if replacement_receipt_hash is not None and not _hex64(replacement_receipt_hash):
            raise ValueError("replacement receipt hash must be 64 lowercase hex")
        self.connection.execute("BEGIN IMMEDIATE")
        try:
            row = self.connection.execute(
                "SELECT receipt_hash FROM registered_receipts WHERE receipt_hash=? AND project_id=? AND target_route=?",
                (receipt_hash, self.project_id, self.target_route),
            ).fetchone()
            if row is None:
                raise ValueError("unknown receipt")
            self.connection.execute(
                "INSERT INTO receipt_invalidations(receipt_hash,invalidation_kind,reason,replacement_receipt_hash,actor,invalidated_at) VALUES (?,?,?,?,?,?)",
                (receipt_hash, kind, reason.strip(), replacement_receipt_hash, actor.strip(), _now()),
            )
            self.connection.execute("COMMIT")
        except Exception:
            self.connection.execute("ROLLBACK")
            raise

    def _last_audit_hash(self) -> str:
        row = self.connection.execute("SELECT entry_hash FROM consumption_audit ORDER BY sequence DESC LIMIT 1").fetchone()
        return row[0] if row else "GENESIS"

    def _append_audit(
        self,
        *,
        receipt_hash: str,
        consumer: str,
        actor: str,
        current_context_hash: str,
        outcome: str,
        reason: str,
    ) -> str:
        previous_hash = self._last_audit_hash()
        recorded_at = _now()
        payload = {
            "receipt_hash": receipt_hash,
            "project_id": self.project_id,
            "target_route": self.target_route,
            "consumer": consumer,
            "actor": actor,
            "current_context_hash": current_context_hash,
            "outcome": outcome,
            "reason": reason,
            "recorded_at": recorded_at,
            "previous_hash": previous_hash,
        }
        entry_hash = _hash(payload)
        self.connection.execute(
            "INSERT INTO consumption_audit(receipt_hash,project_id,target_route,consumer,actor,current_context_hash,outcome,reason,recorded_at,previous_hash,entry_hash) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            (
                receipt_hash,
                self.project_id,
                self.target_route,
                consumer,
                actor,
                current_context_hash,
                outcome,
                reason,
                recorded_at,
                previous_hash,
                entry_hash,
            ),
        )
        return entry_hash

    def consume(
        self,
        receipt_hash: str,
        *,
        consumer: str,
        actor: str,
        current_context_hash: str,
    ) -> ConsumptionResult:
        if not _hex64(receipt_hash):
            raise ValueError("receipt_hash must be 64 lowercase hex")
        if not _hex64(current_context_hash):
            raise ValueError("current_context_hash must be 64 lowercase hex")
        if not consumer.strip() or not actor.strip():
            raise ValueError("consumer and actor are required")

        self.connection.execute("BEGIN IMMEDIATE")
        try:
            row = self.connection.execute(
                "SELECT * FROM registered_receipts WHERE receipt_hash=?",
                (receipt_hash,),
            ).fetchone()
            outcome = "REJECTED"
            reason = "unknown_receipt"

            if row is not None:
                if row["project_id"] != self.project_id:
                    reason = "project_scope_mismatch"
                elif row["target_route"] != self.target_route:
                    reason = "target_route_mismatch"
                elif row["expected_consumer"] != consumer:
                    reason = "unexpected_consumer"
                elif row["context_hash"] != current_context_hash:
                    reason = "stale_context"
                else:
                    invalidation = self.connection.execute(
                        "SELECT invalidation_kind FROM receipt_invalidations WHERE receipt_hash=?",
                        (receipt_hash,),
                    ).fetchone()
                    if invalidation is not None:
                        reason = "receipt_" + str(invalidation["invalidation_kind"]).casefold()
                    else:
                        consumed = self.connection.execute(
                            "SELECT consumer FROM receipt_consumptions WHERE receipt_hash=?",
                            (receipt_hash,),
                        ).fetchone()
                        if consumed is not None:
                            reason = "replay_detected"
                        else:
                            self.connection.execute(
                                "INSERT INTO receipt_consumptions(receipt_hash,consumer,actor,consumed_at,current_context_hash) VALUES (?,?,?,?,?)",
                                (receipt_hash, consumer, actor, _now(), current_context_hash),
                            )
                            outcome = "ACCEPTED"
                            reason = "consumed_once"

            audit_hash = self._append_audit(
                receipt_hash=receipt_hash,
                consumer=consumer,
                actor=actor,
                current_context_hash=current_context_hash,
                outcome=outcome,
                reason=reason,
            )
            self.connection.execute("COMMIT")
            return ConsumptionResult(outcome == "ACCEPTED", outcome, reason, receipt_hash, audit_hash)
        except Exception:
            self.connection.execute("ROLLBACK")
            raise

    def verify_audit_chain(self) -> bool:
        previous_hash = "GENESIS"
        rows = self.connection.execute(
            "SELECT * FROM consumption_audit ORDER BY sequence"
        ).fetchall()
        for row in rows:
            if row["previous_hash"] != previous_hash:
                return False
            if row["project_id"] != self.project_id or row["target_route"] != self.target_route:
                return False
            payload = {
                "receipt_hash": row["receipt_hash"],
                "project_id": row["project_id"],
                "target_route": row["target_route"],
                "consumer": row["consumer"],
                "actor": row["actor"],
                "current_context_hash": row["current_context_hash"],
                "outcome": row["outcome"],
                "reason": row["reason"],
                "recorded_at": row["recorded_at"],
                "previous_hash": row["previous_hash"],
            }
            if _hash(payload) != row["entry_hash"]:
                return False
            previous_hash = row["entry_hash"]
        return True

    def consumption_count(self, receipt_hash: str) -> int:
        row = self.connection.execute(
            "SELECT COUNT(*) FROM receipt_consumptions WHERE receipt_hash=?",
            (receipt_hash,),
        ).fetchone()
        return int(row[0])
