# Light in the Dark — Studio Sprint 1

Fondation professionnelle du prototype Godot de **Light in the Dark**.

## Documentation

- [Bible du lore — Trois Éveils](docs/LORE_BIBLE.md)
- [Monde extérieur, Voile et Chute](docs/LORE_MONDE_VOILE_ET_CHUTE.md)
- [Civilisations étrangères — peuples, puissances et après-Chute](docs/CIVILISATIONS_ETRANGERES_APRES_CHUTE.md)
- [Civilisations antérieures et Premier Voile](docs/CIVILISATIONS_ANTERIEURES_ET_PREMIER_VOILE.md)
- [Civilisations antérieures des mondes extérieurs](docs/CIVILISATIONS_ANTERIEURES_MONDES_EXTERIEURS.md)
- [Campagne principale — 10 chapitres, boss, révélations et fins](docs/CAMPAGNE_PRINCIPALE.md)
- [Combat tactique — rangs, déplacements et synergies](docs/COMBAT_TACTIQUE_RANGS.md)
- [Combat — démembrements tactiques](docs/COMBAT_DEMEMBREMENTS.md)
- [Combat v5 — déplacements forcés, démembrements et phases de boss](docs/COMBAT_DEPLACEMENTS_DEMEMBREMENTS.md)
- [Chapitre I — verticale jouable des Terres de Cendre](docs/CHAPITRE_01_VERTICAL_SLICE.md)
- [Chapitre II — enquête jouable et Route des Bornes](docs/CHAPITRE_02_VERTICAL_SLICE.md)
- [Chapitre III — Projet Seuil, responsabilités et Écho](docs/CHAPITRE_03_PROJET_SEUIL.md)
- [Chapitre IV — Première Rupture et Ashaï de Nhal](docs/CHAPITRE_04_PREMIERE_RUPTURE.md)
- [Chapitre V — Or-Silex et la Grande Fermeture](docs/CHAPITRE_05_GRANDE_FERMETURE.md)
- [Chapitre VI — Les Absents](docs/CHAPITRE_06_LES_ABSENTS.md)
- [Chapitre VII — Les responsables vivants](docs/CHAPITRE_07_RESPONSABLES_VIVANTS.md)
- [Chapitre VIII — Le monde extérieur](docs/CHAPITRE_08_MONDE_EXTERIEUR.md)
- [Chapitre IX — Ce qu'est réellement le Voile](docs/CHAPITRE_09_NATURE_DU_VOILE.md)
- [Chapitre X — La lumière mérite d'être défendue](docs/CHAPITRE_10_LA_LUMIERE_MERITE_ETRE_DEFENDUE.md)
- [Épilogues, postgame et Nouveau Cycle+](docs/EPILOGUES_POSTGAME_NG_PLUS.md)
- [Histoire fondatrice — Dernière Guerre et Trois Éveils](docs/HISTOIRE_TROIS_EVEILS.md)
- [La Concorde — droit et justice](docs/CONCORDE_DROIT_JUSTICE.md)
- [La Concorde avant la Chute — courants politiques](docs/CONCORDE_COURANTS_PRE_CHUTE.md)
- [La Concorde — cités, institutions, histoire et quêtes politiques](docs/CONCORDE_MONDE_POLITIQUE.md)
- [La Concorde après la Chute — courants et figures politiques](docs/CONCORDE_COURANTS_POST_CHUTE.md)

## Vérifier le projet

```bash
python -m pip install -r requirements-dev.txt
python -m pytest
python -m tools.qa.audit
python -m tools.qa.cross_system_audit
python -m tools.qa.balance_audit
python -m tools.qa.combat_turn_audit
python -m tools.qa.tactical_combat_audit
python -m tools.qa.dismemberment_audit
python -m tools.qa.displacement_combat_audit
python -m tools.qa.combat_economy_sim_v2
```

`tools.qa.audit` vérifie les données de base, les références `res://`, les assets, les conflits Git et les workflows YAML.

`tools.qa.cross_system_audit` vérifie les relations entre systèmes : campagne I→X, scènes et routes, contrats des boss, sept Vestiges Profonds, sauvegarde, autoloads, postgame et règles du Nouveau Cycle+.

`tools.qa.balance_audit` vérifie la progression 1→50, le coût et les prérequis des arbres, les ascensions des compagnons, les six fins, les soft-locks économiques du postgame, le scaling NG+ et les 34 recrutements de boss/mini-boss. Les incohérences certaines échouent en CI ; les cas qui exigent encore un playtest ou une analyse de chemins exclusifs sont signalés comme avertissements.

`tools.qa.combat_turn_audit` verrouille le moteur de rounds à quatre héros conservé par la chaîne v5 → v4 → v3 → v2 : chaque héros vivant agit une fois par round, le compagnon agit une seule fois après le groupe, puis les ennemis. Il vérifie aussi que toutes les statistiques produites par les arbres de compétences sont réellement consommées par le combat effectif.

`tools.qa.tactical_combat_audit` vérifie la couche tactique v3 conservée sous v4/v5 : quatre rangs uniques, positions d'utilisation et de ciblage, déplacement consommant l'action, techniques propres aux héros, ciblage avant/arrière des ennemis, liberté de ciblage des boss et synergies de formation.

`tools.qa.dismemberment_audit` vérifie la couche v4 conservée sous v5 : jauge de trauma, profils corporels, conséquences fonctionnelles, résistance accrue des boss, absence d'exécution instantanée des boss et indépendance entre mécanique et niveau de gore affiché.

`tools.qa.displacement_combat_audit` vérifie la couche v5 : poussées et tractions des coups lourds, recul sous Peur, déplacements provoqués par la perte de membres et quatre manœuvres de boss dont le fonctionnement dépend d'un membre précis.

`tools.qa.combat_economy_sim_v2` reste le modèle numérique de base pour les checkpoints de niveaux 1/10/20/30/40/50, plus de trente boss/mini-boss, les compagnons recrutés, les cycles NG+ 0→5, la vitesse d'XP et l'économie Or/Essence. Les couches tactiques v3/v4/v5 ajoutent les rangs, synergies, démembrements et déplacements forcés par-dessus cette base.

Les rapports sont écrits dans `reports/qa-report.json`, `reports/qa-report.html`, `reports/cross-system-report.json`, `reports/balance-report.json`, `reports/combat-turn-report.json`, `reports/tactical-combat-report.json`, `reports/dismemberment-report.json`, `reports/displacement-combat-report.json` et `reports/combat-economy-report.json`.

Ou sous macOS/Linux :

```bash
bash ./tools/build/run_ci.sh
```

Le script exécute également le smoke test Godot si `godot` est disponible localement.

## GitHub Actions

- **CI** : tests Python, audits de structure/équilibrage, audit du moteur de tours, audit tactique des rangs/synergies, audit des démembrements, audit des déplacements forcés/phases de boss, simulation combat-économie et smoke test Godot headless.
- **Builds** : exports Web, Windows et Linux.
- **Nightly QA** : régression quotidienne avec les audits, la simulation et le smoke test Godot.
- **Release** : création d’une release lors d’un tag `v*`.

## Premier envoi sur GitHub

Décompressez l’archive, envoyez tout son contenu à la racine d’un dépôt vide, y compris le dossier `.github`. Consultez `docs/GITHUB_SETUP.md`.

## Limites du Sprint 1

La CI est prête à exécuter les validations dans GitHub. Les exports Android/iOS nécessitent toujours leurs SDK et signatures et sont prévus dans un sprint ultérieur.
