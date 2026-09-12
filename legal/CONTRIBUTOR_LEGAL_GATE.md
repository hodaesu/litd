# LITD — CONTRIBUTOR / EXTERNAL CREATION LEGAL GATE

Status: mandatory before accepting external production work.

No external art, code, music, SFX, voice, writing, animation, model, texture, font or other production asset may become release-cleared merely because it was delivered or merged.

## Before work starts

- identify the contributor/legal entity;
- use the appropriate written agreement (artist, developer, composer/audio, performer or other);
- define deliverables and rights actually needed;
- define compensation and credit;
- require disclosure of third-party material and generative-AI use;
- establish confidentiality if non-public material is shared.

## Before accepting a delivery

The delivery must include, as applicable:

- source files and export files;
- creator identity;
- invoice/contract or employment evidence;
- third-party components and licenses;
- marketplace receipts/licenses;
- sample/library list;
- performer releases;
- AI tool/model declaration and relevant terms/evidence;
- requested attribution text;
- repository/asset identifier.

## Before merge/release

1. Update `legal/ASSET-LITD.csv` or `legal/SBOM-LITD.csv`.
2. Store the contract/evidence reference.
3. Confirm commercial use and required attribution.
4. Add required notice text to `legal/THIRD_PARTY_NOTICES.txt` where applicable.
5. Mark the item GREEN only after the evidence exists.

## Automatic rejection / quarantine

Quarantine a delivery if its origin is unclear; if it contains ripped/decompiled third-party assets; if the contributor cannot explain the rights to incorporated material; if a license conflicts with the intended proprietary distribution; or if an identifiable voice/performance/sample lacks the required authorization.

This gate complements the project contract templates and does not replace individualized legal review for unusual or high-value agreements.
