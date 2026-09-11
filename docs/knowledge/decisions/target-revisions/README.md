# LITD canonical target revision governance

Canonical design targets must not be weakened merely because an implementation regressed.

A Pull Request that changes a canonical target is a governance-only change. It must not modify gameplay/runtime implementation in the same Pull Request.

Every target revision requires a JSON proposal in this directory containing:

- `kind: LITD_TARGET_REVISION_PROPOSAL`
- `decision: PROPOSE_TARGET_REVISION`
- one or more `target_ids`
- the previous values in `old_values`
- the proposed values in `new_values`
- a substantive `rationale`
- at least one `evidence_refs` entry
- optional `candidate_hash` linking a design-review candidate
- `core_write_allowed: false`

A proposal is evidence for a governance decision. It does not itself modify the Core or authorize implementation changes.

Required separation:

1. Observe and measure the problem.
2. Open a governance-only target revision proposal if the target itself is believed to be wrong.
3. Review and approve/reject that target revision independently.
4. Only after the target decision is settled may a separate implementation change be proposed.
5. Run tests and telemetry again against the resulting canonical targets.

This prevents a failing implementation from making its own success criteria easier in the same change set.
