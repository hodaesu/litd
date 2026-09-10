# LITD Engineering Working Method

This document defines the default engineering method for Light in the Dark (LITD).

## Goal

Reduce regression cost, shorten diagnosis loops, keep systems decoupled, and make every change reproducible and reviewable.

## Default change loop

1. Write a short behavioral specification.
2. List invariants that must remain true.
3. Implement the smallest coherent change.
4. Add or update the closest fast test.
5. Run targeted CI for the affected domain.
6. Run integration coverage.
7. Run player-journey/E2E coverage when the change affects runtime flow or UI.
8. Merge only when the expected behavior is demonstrated and CI is green.

## Testing pyramid

### L0 — static/import gate

Very fast checks. Intended to catch syntax, import, autoload, encoding and obvious data-contract failures before expensive tests run.

### L1 — unit and invariant tests

Fast tests for pure or nearly pure game rules. Prefer tests that express game invariants rather than long scenario scripts.

Examples:
- exactly 3 skill trees per eligible character;
- exactly 15 skills per tree;
- once a tree is locked, points cannot be spent in another tree;
- R1..R4 ordering is canonical and deterministic;
- a support role is not automatically placed ahead of an available melee role when the formation rule forbids it;
- identical seeds produce identical deterministic loot inputs;
- non-capturable bosses remain non-capturable;
- save/load preserves the canonical state.

### L2 — subsystem integration

Tests covering interactions inside one domain: combat, UI, persistence, narrative, audiovisual, world generation, Blender handoff, etc.

### L3 — player journey / E2E

Critical paths only. These tests prove that a player can complete important flows but should not be the first place a small rule regression is detected.

### L4 — exhaustive/nightly

Large matrices, long simulations, broad balance sweeps, expensive visual checks and long-running scenario sets.

## CI domains

Prefer domain-oriented jobs because their names should explain a failure without opening logs.

Recommended domains:
- core/data
- lore
- combat
- narrative
- UI/UX
- persistence
- audiovisual
- world/level
- Blender/assets
- vertical slice

Use `fail-fast: false` for independent domain matrices so one regression does not hide failures in other domains.

## Determinism and reproduction

Every generated or stochastic test failure should report enough state to replay it:
- seed;
- scene/test identifier;
- roster;
- relevant equipment/state;
- save or compact state snapshot when possible;
- domain and test level;
- logs;
- screenshot for visual/UI failures when available.

A random failure without a reproducible seed is considered an incomplete test failure.

## Architecture rules

Prefer data-driven content and generic execution systems.

Content such as characters, skills, enemies, effects, equipment, dialogue, quests and events should be represented as validated data/resources where practical. Runtime systems should consume explicit contracts rather than reach into unrelated systems.

Preferred direction:

`data/resource -> domain service/resolver -> event/signal/result -> presentation`

Avoid direct UI-to-combat state mutation when a domain API can express the operation. Avoid cross-system singleton coupling unless the lifetime and ownership genuinely require it.

## Small changes

Prefer small, reviewable commits and PRs. A change should have one primary reason to exist. Separate refactors from behavioral changes when practical so regressions are easier to localize.

## Definition of Done

A feature or correction is done only when all applicable items are true:
- intended behavior is documented or obvious from a focused specification;
- invariants are identified;
- implementation is complete;
- fast targeted tests exist or were updated;
- integration coverage passes;
- E2E/player-journey coverage passes when relevant;
- deterministic failures are reproducible;
- user-visible changes have appropriate evidence (screenshots/logs/snapshots where useful);
- CI is green;
- documentation/data contracts are updated when affected.

## Performance

Profile before optimizing. Do not rewrite GDScript code into another language solely on intuition.

For performance-sensitive features, define measurable budgets such as:
- combat entry latency;
- turn-resolution latency;
- dungeon generation time;
- save/load time;
- memory budget per expedition;
- node/object count where relevant;
- minimum frame-rate target for the supported hardware class.

Performance work should include before/after measurements.

## Pull request standard

Each non-trivial PR should communicate:
- why the change exists;
- what changed;
- systems/domains affected;
- invariants protected;
- tests added/updated;
- risks or migrations;
- visual evidence when UI/art changes are involved.

## Encoding and source hygiene

Default to UTF-8 text files, normalized line endings, consistent naming and formatter/style rules appropriate to the language. Mechanical style failures should be automated rather than discovered during manual review.

## CI evolution priority

1. Keep the current coverage intact.
2. Split long monolithic jobs by meaningful domain.
3. Add a fast preflight gate.
4. Move expensive exhaustive checks out of the critical PR path when they are not needed for every change.
5. Add reproducibility artifacts for failures.
6. Add change-aware targeted execution only after test ownership/domain metadata is reliable.
7. Continuously measure CI duration and flaky-test rate.

## Rule for future LITD work

The default engineering strategy is: small modifications, decoupled systems, tests close to the rules they protect, progressive CI, domain-oriented parallelism, deterministic seeds, and automatic evidence on failure.
