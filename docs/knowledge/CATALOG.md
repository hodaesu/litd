# Catalogue vivant LITD — Lots 01–02

Ce catalogue est un point d'entrée humain vers la bibliothèque. Il ne remplace pas le Knowledge Graph ni les données du dépôt ; il indique ce qui a déjà une fiche de connaissance structurée, son niveau de preuve et ce qui doit encore être importé ou revalidé.

## Canon / décisions actives

| ID | Sujet | Statut | Confiance | Preuves principales |
|---|---|---|---|---|
| ADR-0001 | Guardian progressif | active/accepté | high | Knowledge System + validator |
| ADR-0002 | Quatuor de départ Mathilde / Marec / Anouk / Aurélien | active | very_high | PR #246, #250, #259 |
| ADR-0003 | Doctrine UX/UI Monde → HUD → Contexte/Décision → Inspection | active | high | PR #255, Bible UX/UI |
| ADR-0004 | CI Godot par domaines + filet monolithique | active | very_high | PR #253, #257, #242 |
| ADR-0005 | Compétences des Veilleurs : 3 arbres × 15 | active | high | données `data/veilleurs/skills/*.json` |
| ADR-0006 | Convention de rangs R1–R4 / formation | active pour la convention, formation exacte évolutive | high | données/tests de formation |

## Connaissances à revalider

| ID | Sujet | Statut | Confiance | Preuves principales |
|---|---|---|---|---|
| ADR-0007 | Boucle d'expédition et Lumière | revalidate | medium_high | PR #70 fusionnée ; runtime actuel à reconfirmer |
| ADR-0008 | Capture/recrutement | active pour Ange non capturable ; revalidate pour les règles secondaires | high / medium_high | `guardian-rules.yml` + PR #70 fusionnée |

La distinction ci-dessus est volontaire : une preuve historique fusionnée confirme qu'un système a existé et a été validé à un instant donné, mais ne suffit pas à certifier son état runtime actuel après de nombreuses évolutions.

## Research records / écarts de preuve

| ID | Sujet | Statut | Confiance | Condition de promotion |
|---|---|---|---|---|
| RR-0001 | Rémanence / persistance des conséquences | revalidate | medium | test ou smoke actuel démontrant état → persistance → rechargement/transition → conséquence observable |
| RR-0002 | Loot déterministe par seed | revalidate | medium | test même seed + même contexte → même loot, avec identité persistante maîtrisée |
| RR-0003 | Exclusivité d'arbre | revalidate | medium_high | test logique : choix A → B/C interdits, puis persistance si applicable |
| RR-0004 | Vertical Slice 01 / Lumière | revalidate | medium_high | données/config runtime traçables + tests principaux + mesure playtest pour la durée cible |
| RR-0005 | Galeries Éteintes / PR #245 | revalidate | high | corriger la dérive de roster, réaligner sur `main`, smokes/CI verts puis fusion |
| RR-0006 | Méthode d'ingénierie / PR #254 | revalidate | high | relecture contre le dépôt courant, validation puis fusion sur `main` |
| RR-0007 | Playtest PC / cinq testeurs / PR #243 | experimental | high | cinq sessions humaines réelles et seuils du protocole atteints ; protocole fusionné |
| RR-0008 | Trieur canonique ⇄ Core / PR #260 | revalidate | high | chemin destructif unique/sûr vérifié, audit/tests verts, puis fusion |

Ces fiches formalisent volontairement les lacunes de preuve au lieu de promouvoir un faux canon technique. Une règle Guardian en `automated_candidate`, une PR ouverte ou un build techniquement vert ne constituent pas seuls une validation complète.

### Contradictions importantes conservées

- PR #245 : véritable prototype Galeries Éteintes, mais le diff contient encore des références à Nayra/Tarek/Aïsha/Idris ; cette dérive contredit le quatuor de départ actuel Mathilde/Marec/Anouk/Aurélien et bloque une promotion canonique.
- PR #243 : la validation technique peut être verte tout en laissant `human_validation_status=NOT_RUN` ; aucune conclusion de compréhension joueur ne doit en être déduite.
- PR #260 : l'architecture Core ⇄ Trieur est substantielle, mais reste hors de `main` tant que la PR n'est pas fusionnée et le chemin de suppression final entièrement vérifié.

## Incidents capitalisés

- `incidents/2026-09-10-runtime-player-smoke-equipment.md` — migration du quatuor ayant révélé une couverture d'équipement de test incomplète ; cause corrigée sans fallback artificiel.

## Protocoles / gouvernance

- `README.md` — architecture du LITD Development Intelligence System.
- `LIVING_LIBRARY_PROTOCOL.md` — protocole systématique Source → Connaissance → Hypothèse → Décision → Core → Implémentation → Test → Mesure → Preuve → Réévaluation.
- `guardian-rules.yml` — premiers invariants et niveaux Guardian.
- `dependencies.yml` — dépendances structurées existantes.
- `templates/decision.md`, `templates/research.md`, `templates/incident.md` — formats normalisés.

## À traiter ensuite — priorité élevée

1. corriger/réaligner Galeries Éteintes #245 sur le quatuor canonique et l'état actuel de `main` ;
2. raccorder RR-0001 à RR-0004 à des tests runtime explicites plutôt qu'à des intentions ;
3. revalider puis intégrer la méthode d'ingénierie #254 si elle correspond toujours à l'architecture actuelle ;
4. maintenir #243 en `experimental` jusqu'aux cinq observations humaines réelles ;
5. sécuriser puis intégrer #260 comme capteur/exécutant contrôlé du Core ;
6. promouvoir ensuite uniquement les connaissances dont les preuves convergent sur le head réel.

## Règle d'admission

Un élément n'entre pas comme `active` uniquement parce qu'il apparaît dans une discussion, un ancien fichier ou une PR ouverte. Avant promotion :

- vérifier la source réelle et son état (fusionnée, ouverte, draft, remplacée) ;
- rechercher les décisions contradictoires ou plus récentes ;
- relier les tests/preuves disponibles ;
- attribuer statut et confiance ;
- noter les conditions de réexamen.

Une règle déclarée dans le Guardian avec `automated_candidate` constitue un objectif/invariant suivi, pas encore une preuve d'implémentation complète.

## Prochaine passe

Le Lot 02 et les quatre principaux chantiers connexes sont désormais représentés sans faux positif de validation. La prochaine étape n'est plus d'ajouter des affirmations : elle consiste à réduire ces écarts de preuve dans le code et la CI, en commençant par la contradiction canonique de Galeries Éteintes puis les invariants runtime manquants.
