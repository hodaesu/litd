# LITD — ASSET PROVENANCE AUDIT

Date: 2026-09-08
Scope: current 64 binary images registered in `legal/ASSET-LITD.csv`.
Status: **ORANGE — chain of custody established from repository import, original creation source still unverified.**

## What Git proves

The current asset families were present in the repository's root import commit:

- commit: `80757dfedddd243f2b26d618d168635180c0fe16`
- message: `Initial import of Light in the Dark`
- author/committer account: `hodaesu`
- date: 2026-08-14
- commit signature: unsigned

Representative path-history checks for:

- `assets/backgrounds/crypts.webp`
- `assets/heroes/watcher.webp`
- `assets/enemies/enemy_39.webp`

all resolve directly to that initial import commit and no earlier Git commit.

The root commit's changed-file list contains the background, enemy and hero binary assets as newly imported files. Therefore Git provides a useful chain-of-custody anchor from 2026-08-14 onward.

## What Git does NOT prove

The initial-import documentation explicitly says the project arrived as an archive **without a `.git` directory** and was then imported into a new Working Copy repository. Therefore the repository does not contain pre-import history for the files.

Consequences:

- the Git author is the importer, not automatically the image author;
- the import date is not automatically the creation date;
- the project `LICENSE` statement that “original game assets” are all-rights-reserved is a rights assertion, not independent evidence that each binary is original;
- no commercial-release asset may become GREEN solely because it was present in the initial commit.

## Conversation/history retrieval

A search of available prior project context on 2026-09-08 did not recover a sufficiently specific creation event for these exact filenames. No exact prompt, source URL, stock-pack receipt, artist delivery, or generation record could be tied reliably to the 64 current binaries from that search.

This means the files remain ORANGE until stronger evidence is attached.

## Duplicate-art finding

The initial import manifest/hashes show at least two exact duplicate pairs among hero files:

- `assets/heroes/duelist.webp` and `assets/heroes/scout.webp` share SHA-256 `d6663accc8e9ea676fe2780c9c269d3c767c49c2a6d25fe52e3fd1f9b545d4a4`.
- `assets/heroes/duelist_2.webp` and `assets/heroes/scout_2.webp` share SHA-256 `a52a444f2e9219367d564617c43caba3d78473dcc1ff79df3ff13a11505206dc`.

This is not itself a legal problem, but it proves that filename/class identity is not sufficient provenance evidence. Rights should be tracked by binary/source lineage, not merely filename.

## Evidence ladder for moving an asset to GREEN

An asset can become GREEN only when the registry contains enough evidence to answer all applicable questions:

1. **Origin** — original drawing/render/generation, commissioned artist, purchased pack, licensed source, etc.
2. **Author / rightsholder** — who created it and who currently owns or licenses the needed rights.
3. **Tool/source evidence** — source project, prompt/generation record, invoice, contract, license page/archive, or delivery message.
4. **AI disclosure** — whether generative AI was used and with which service/model where known.
5. **Third-party material** — reference images, textures, fonts, logos, characters or source-game material incorporated into the asset.
6. **Commercial rights** — right to use, modify, distribute and market in the intended territories/platforms.
7. **Attribution/notice requirements** — recorded and implemented where required.

## Practical recovery order

### Priority A — source files and local archives

Search the original pre-Git archive/device folders for:

- PSD/Krita/Blender/Godot source files;
- original PNG/JPG/WebP versions with older timestamps;
- prompt exports or generation filenames;
- download receipts/license text;
- artist folders or delivery archives.

### Priority B — chat / generation records

For images created through an AI/image tool, retain:

- date and conversation/thread;
- original prompt and resulting image where recoverable;
- tool/service used;
- subsequent manual edits;
- confirmation that no protected third-party asset was supplied as an unauthorized source.

### Priority C — replace rather than litigate provenance

If an old asset's source cannot be established, mark it `REPLACE_BEFORE_RELEASE` and create a new production asset under the current legal gate. This is safer and usually cheaper than trying to reconstruct an unverifiable chain of title.

## Release rule

**NO-GO for commercial release:** any player-facing asset still marked `UNVERIFIED` or `REPLACE_BEFORE_RELEASE` in `ASSET-LITD.csv` must either obtain a documented rights chain or be replaced before release candidate lock.
