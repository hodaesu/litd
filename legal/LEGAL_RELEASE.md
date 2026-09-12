# LITD — LEGAL RELEASE GATE

Audit date: 2026-09-08
Overall status: **ORANGE — development permitted; commercial release not cleared.**

This file is an operational release gate, not legal advice or a substitute for a French/EU IP professional.

## Gate status

| Area | Status | Release condition |
|---|---|---|
| Project proprietary license | GREEN | Keep repository LICENSE and chain of title current |
| Godot Engine | GREEN CONDITIONAL | Ship MIT notice and Godot third-party notices |
| Project dependencies | GREEN CONDITIONAL | Keep `legal/SBOM-LITD.csv` current and verify release binaries |
| Legacy visual assets | ORANGE | Use as development placeholders only unless provenance is recovered; replace before release if still unverified |
| Definitive v41 art | ORANGE | Produce through `PRODUCTION_MANIFEST.csv`; approved/final requires legal GREEN |
| Music / voice / SFX | ORANGE | Composition, master, performer, sample/library and AI provenance must be documented |
| Mobile privacy / SDKs | ORANGE | Audit final Android APK/AAB and iOS archive/app bundle, permissions, embedded SDKs and store declarations |
| Age/content ratings | ORANGE | Complete final store/IARC/age-rating questionnaires against release content |
| `Light in the Dark` commercial name | **ORANGE FORT** | Do not file or lock commercial branding until professional similarity/earlier-rights clearance |
| `Les Veilleurs` | ORANGE | Low distinctiveness / earlier media uses; working wording only until clearance |
| `Les Veilleurs des Cendres` | YELLOW / DEMOTED | Public fantasy use of the exact expression and close genre vocabulary make it a weaker candidate |
| `La Concorde des Cendres` | YELLOW-GREEN PRELIMINARY | Preferred candidate for formal INPI/EUIPO/WIPO and earlier-use search; not cleared |
| External contributors | ORANGE | Signed written agreement + provenance record before accepting production work |

## Definitive-art production gate

Canonical production is controlled by:

- `assets/art/v41/PRODUCTION_MANIFEST.csv`
- `docs/art/FINAL_ASSET_REPLACEMENT_PLAN.md`
- `legal/PROVENANCE_TEMPLATE.md`

Priority policy:

- **P0**: text-free brand symbol, Sanctuary, Sahen Varo, Mira Sen, Narem Osh, Ysra Nahal, combat frame, UI panel/tooltip frames and humanoid anatomy.
- **P1**: title/background support, Goule affamée, Oni, Jorōgumo, additional anatomy and body icons.
- **P2**: remaining creatures, variants, secondary screens and polish.

Hard rule: any asset with production status `approved` or `final` must have legal status `GREEN`.

The final wordmark stays `blocked_name_clearance` / `BLOCKED` until the commercial title has passed the required clearance.

## Hard NO-GO conditions

A commercial release must not be approved while any of these are true:

1. The commercial title has not passed final trademark/name clearance.
2. Any shipped player-facing legacy asset remains legally unverified.
3. Any definitive asset marked `approved` or `final` lacks legal status `GREEN` and its provenance evidence.
4. A shipped third-party component is absent from the SBOM or its license obligations are unknown.
5. Godot license information is unavailable to the player in the shipped product.
6. Music, voice, samples or performances lack the necessary written rights/evidence.
7. Final mobile packages have not been inspected for permissions, SDKs and privacy declarations.
8. Store content/age questionnaires have not been completed from the final gore/violence implementation.

## Source-level findings on 2026-09-08

- Export presets exist for Web, Windows, Android, iOS and Linux.
- Android package id and iOS bundle id currently use `com.hodaesu.lightinthedark`; this is a technical identifier, but the visible package/game name should not be treated as trademark-cleared.
- Repository searches did not identify Firebase, AdMob, Sentry, Mixpanel, Amplitude, Godot HTTPRequest/HTTPClient/WebSocket usage or a GDExtension at this scan point. This is **not** equivalent to a final-binary privacy audit.
- `addons/` currently exposes the internal `veilleurs_pipeline` plugin only.
- Python development dependencies declared by the repository are pytest and PyYAML.
- The current `assets/` inventory contains 64 image binaries registered in `ASSET-LITD.csv`; provenance evidence is not established by repository presence alone.
- The canonical art pipeline already supports `missing → placeholder → candidate → approved → final` and includes rights in its review gate.

## Automated safeguards

Current tests enforce or are intended to enforce:

- reference-library rights values limited to public-domain/CC0 sources;
- unique legal asset IDs and paths;
- no GREEN legacy asset with unresolved core rights metadata;
- unique definitive production IDs and targets;
- presence of all four canonical Veilleurs in P0;
- no approved/final definitive art unless legal status is GREEN;
- final wordmark remains blocked until title clearance.

## Release sign-off

Final sign-off requires all release-critical rows above to be GREEN and the following evidence bundle to be archived:

- final asset provenance register;
- definitive-art manifest with no shipped unresolved assets;
- final SBOM and notices;
- signed contributor/contractor agreements;
- audio chain-of-title evidence;
- Android permissions/SDK/Data Safety review;
- iOS privacy manifest/SDK/privacy-label review;
- final age/content rating submissions;
- professional clearance memo for the selected commercial title/mark.

## Current decision

**NO-GO for commercial release today. Development and art production may continue under the gates above.**
