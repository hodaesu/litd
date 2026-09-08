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
| Existing visual assets | ORANGE | Every row in `legal/ASSET-LITD.csv` must have documented creator/ownership/license/provenance |
| Music / voice / SFX | ORANGE | Composition, master, performer, sample/library and AI provenance must be documented |
| Mobile privacy / SDKs | ORANGE | Audit final Android APK/AAB and iOS archive/app bundle, permissions, embedded SDKs and store declarations |
| Age/content ratings | ORANGE | Complete final store/IARC/age-rating questionnaires against release content |
| `Light in the Dark` commercial name | **ORANGE FORT** | Do not file or lock commercial branding until a professional similarity/earlier-rights clearance is completed |
| `Les Veilleurs` | ORANGE | Search exact/similar earlier rights in relevant territories/classes |
| External contributors | ORANGE | Signed written agreement + provenance record before accepting production work |

## Hard NO-GO conditions

A commercial release must not be approved while any of these are true:

1. The commercial title has not passed final trademark/name clearance.
2. Any shipped binary asset remains `UNVERIFIED` in `ASSET-LITD.csv`.
3. A shipped third-party component is absent from the SBOM or its license obligations are unknown.
4. Godot license information is unavailable to the player in the shipped product.
5. Music, voice, samples or performances lack the necessary written rights/evidence.
6. Final mobile packages have not been inspected for permissions, SDKs and privacy declarations.
7. Store content/age questionnaires have not been completed from the final gore/violence implementation.

## Source-level findings on 2026-09-08

- Export presets exist for Web, Windows, Android, iOS and Linux.
- Android package id and iOS bundle id currently use `com.hodaesu.lightinthedark`; this is a technical identifier, but the visible package/game name should not be treated as trademark-cleared.
- Repository searches did not identify Firebase, AdMob, Sentry, Mixpanel, Amplitude, Godot HTTPRequest/HTTPClient/WebSocket usage or a GDExtension at this scan point. This is **not** equivalent to a final-binary privacy audit.
- `addons/` currently exposes the internal `veilleurs_pipeline` plugin only.
- Python development dependencies declared by the repository are pytest and PyYAML.
- The current `assets/` inventory contains 64 image binaries registered in `ASSET-LITD.csv`; provenance evidence is not established by repository presence alone.

## Release sign-off

Final sign-off requires all rows above to be GREEN and the following evidence bundle to be archived:

- final asset provenance register;
- final SBOM and notices;
- signed contributor/contractor agreements;
- audio chain-of-title evidence;
- Android permissions/SDK/Data Safety review;
- iOS privacy manifest/SDK/privacy-label review;
- final age/content rating submissions;
- professional clearance memo for the selected commercial title/mark.
