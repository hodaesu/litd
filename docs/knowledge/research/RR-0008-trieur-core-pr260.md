# Research Record — Trieur canonique relié au Core / PR #260

- ID: RR-0008
- Date: 2026-09-10
- Domaine: repository-intelligence / core / safety
- Question: Le trieur canonique et son contrat avec le Core peuvent-ils être considérés comme actifs ?
- Niveau: R1
- Statut: revalidate
- Confiance: high

## Qui ? Quoi ? Où ? Pourquoi ? Comment ?

- Qui : LITD Development Intelligence System.
- Quoi : trieur de fichiers, couche d’intelligence dépôt, gate de suppression Git-backed et contrat Core ⇄ Trieur.
- Où : PR #260, branche `tools/canonical-file-sorter`.
- Pourquoi : détecter doublons, versions, références et obsolescence sans laisser une heuristique décider seule d’une suppression.
- Comment : recherche documentée, classification prudente, preuves convergentes, Guardian, Git et CI non destructive.

## Sources

- PR #260 : ouverte, non fusionnée, mergeable au contrôle du 2026-09-10 ; `obsolete_records` vide, aucune suppression automatique.
- `docs/knowledge/file-sorter-core-contract.md` : Bibliothèque ⇄ Core ⇄ Trieur ⇄ dépôt réel ⇄ CI/tests/mesures ⇄ Core ⇄ Bibliothèque.
- Le contrat sépare explicitement les responsabilités : trieur observe/recommande, Core gouverne, Guardian autorise/bloque, Git exécute/rollback, CI apporte la preuve, bibliothèque conserve l’apprentissage.

## Résultats concordants

L’architecture est alignée avec le Pilier fondamental de collaboration n°1 et la règle recherche avant modification importante. Les garde-fous destructifs sont conservateurs et la CI est conçue en lecture/audit.

## Contradictions / limites

La PR reste hors de `main`. Le contrat et les outils ne doivent donc pas être présentés comme infrastructure canonique intégrée. De plus, toute ancienne voie de suppression directe dans le trieur principal doit rester surveillée jusqu’à vérification qu’elle est supprimée, désactivée ou routée exclusivement via le gate sûr.

## Recherche opposée

Tentative de promotion : architecture, tests et garde-fous sont déjà substantiels. Contre-preuve : PR non fusionnée et nécessité de vérifier qu’aucun chemin destructif alternatif ne contourne `litd_safe_delete.py`.

## Ce qui est vérifié dans LITD

- contrat Core ⇄ Trieur explicite ;
- heuristique seule insuffisante pour suppression ;
- hash/UID/compagnons Godot/Git dry-run intégrés à la stratégie ;
- CI annoncée non destructive ;
- rollback Git prévu.

## Conditions de promotion

Promouvoir après : rebase sur `main`, vérification du chemin de suppression unique et sûr, tests du trieur/intelligence/safe-delete verts, audit non destructif vert, absence de contournement Guardian, puis fusion.

## Relations Knowledge Graph

- source_for: canonical-file-sorter-core-contract
- contradicts: heuristic-authorizes-deletion
- validated_by: future-pr260-green-merge
- influences: repository-observability, knowledge-graph, guardian, evidence-loop
