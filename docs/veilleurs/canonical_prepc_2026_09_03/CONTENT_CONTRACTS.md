# LITD : Les Veilleurs — Contrats de contenu V2

Source combat/rencontres actuelle : `LITD_Les_Veilleurs_Referentiel_Combat_Maitre_Narratif.xlsx`.

## Progression 1–50 — baseline récupérée

Le référentiel contient une progression exacte de conception, à importer puis mesurer en Godot plutôt qu'à réinventer.

Nœuds de compétence Veilleur :

- N1 : nœud 1
- N4 : nœud 2
- N7 : nœud 3
- N10 : nœud 4
- N13 : nœud 5
- N16 : nœud 6 + ultime à 1 charge
- N19 : nœud 7
- N22 : nœud 8
- N25 : nœud 9
- N28 : nœud 10
- N31 : nœud 11
- N32 : ultime passe à 2 charges
- N35 : nœud 12
- N39 : nœud 13
- N44 : nœud 14
- N48 : ultime passe à 3 charges
- N49 : nœud 15
- N50 : maîtrise niveau max

Principe explicite du référentiel : la puissance ne doit pas venir principalement d'une inflation brute ; elle vient de l'arbre, de l'équipement et de la maîtrise. Les multiplicateurs numériques du tableur sont une baseline de test, non l'équilibrage final.

Pour les ennemis recrutables des actes II–V, leurs arbres utilisent également les paliers 1/4/7/.../49 et deviennent exclusifs une fois spécialisés. Les anciennes orientations L10 du système 25/75 sont donc archivées comme concept legacy, pas comme contrat de progression courant.

## Corpus de compétences actuel

### Veilleurs

- 12 arbres.
- 180 compétences normales.
- 12 ultimes séparés.

### Ennemis et boss

- 29 entités nommées.
- 87 arbres.
- 1 305 compétences normales.
- 87 ultimes.

### Total spécifié

- 99 arbres.
- 1 485 compétences normales.
- 99 ultimes séparés.

Ce total décrit la bibliothèque de contenu. Il ne justifie pas son implémentation massive avant la verticale jouable.

## Ultimes des Veilleurs

Les 12 ultimes actuels sont listés dans `SKILL_TREE_INDEX.md` et `data/TREE_REGISTRY_V1.json`.

Le référentiel fournit pour chacun : mécanique, charges, limite de combat, condition, puissance, garde-fou et huit beats de storyboard. Il faut préserver ces huit beats lors de l'import, sans les réduire à un simple multiplicateur de dégâts.

Baseline : N16=1, N32=2, N48=3 ; une activation maximum du même ultime par rencontre ; conditions de l'arbre et fonctions corporelles requises ; jamais d'invulnérabilité ni de résurrection.

## Équipement

Armes : exigences de prise et fonctions corporelles, portée, masse, modes d'attaque, types d'impact, pénétration, précision, durabilité, bruit, vibration, usages environnementaux.

Armures : couverture par zone, matériau, rigidité, absorption, déflexion, résistance à pénétration, état, mobilité, bruit et éventuels effets thermiques/respiratoires.

Une armure endommagée peut créer une faiblesse locale persistante. Une pièce lourde peut sauver un membre tout en rendant l'approche plus bruyante ou certains gestes moins accessibles.

## Résolution des dégâts et du gore

Aucune compétence ne produit directement une mutilation par probabilité libre. Le moteur vérifie contact, zone, armure, tissus, lésion préalable, puissance, impact et anatomie.

Conséquences supportées par le contrat : contusion, lacération, perforation, fracture, luxation, rupture musculo-tendineuse, saignements externe/interne, brûlure, écrasement, section et traumatisme d'organe lorsque l'anatomie le permet.

Les conséquences fonctionnelles priment sur une simple lecture en HP.

## Rémanence corporelle et Traces

Les feuilles `Rémanence_blessures` et `Traces_psychologiques` du pack canonique deviennent les données de référence à importer.

Une blessure/Trace ne doit pas être recréée à partir d'un résumé de conversation : utiliser les lignes exactes du pack extrait.

## Bestiaire actuel

Le roster quantitatif courant est `data/BESTIARY_REGISTRY_V1.json` : 24 ennemis ordinaires + 5 boss.

L'ancienne matrice 25 archétypes / 75 orientations est conservée dans `data/legacy/` comme réserve de concepts. Une idée peut en être réintroduite plus tard, mais seulement par décision explicite et migration vers le roster actuel.

## Ralliement / auxiliaires

Le principe systémique reste : capture/neutralisation et ralliement sont distincts ; les blessures ne sont pas effacées ; aucun boss n'est recruté ; un auxiliaire ne remplace jamais le rôle narratif d'un Veilleur.

Acte I : la source indique seulement `Auxiliaire possible; ne remplace jamais un Veilleur` pour les huit ennemis ordinaires. Aucune condition numérique supplémentaire ne doit être inventée avant qu'elle soit écrite/testée.

Actes II–V : utiliser exactement les conditions de recrutement et rôles auxiliaires du référentiel, déjà reportés dans `data/SYSTEM_RULES_V1.json`.

## Génération hybride des donjons

Structure : macro-dramaturgie écrite + modules procéduraux + Rémanence persistante.

Pipeline : CampaignSeed -> AuthoredMacroGraph -> ZoneConstraints -> RoomModuleSelection -> ConnectivityValidation -> PersistentScarInjection -> FactionEcologyState -> EncounterDirector -> ResourcePlacement -> NarrativeAnchors -> ExtractionValidation -> ConsistencyPass.

Les 64 rencontres actuelles, la profondeur, les tables de spawn, les synergies et les 12 dangers doivent être importés depuis le pack maître avant création manuelle de nouvelles rencontres.

Le directeur ne doit pas contre-picker artificiellement la composition du joueur.

## Boss actuels

- Acte I : Ishar, Gardien du Passage — 3 phases.
- Acte II : Orateur Sans Voix — 3 phases.
- Acte III : Mère des Veines — 3 phases.
- Acte IV : Porte-Cendres Blanc — 3 phases.
- Acte V : Le Copiste — 4 phases.

Les phases exactes sont dans `Boss_5_phases`. Les boss sont non ralliables.

Leur victoire peut dépendre de conditions tactiques et doctrinales en plus de la vitalité. Par exemple, Le Copiste combine Correction, Palimpseste et synthèse des comportements utilisés par le joueur ; une seule routine de statut ou un combo signature répété doit pouvoir être puni sans transformer le boss en omniscient.

## Économie d'expédition — état récupéré

La feuille `Recompenses_capture` comporte explicitement :

- Or cible
- Essence cible
- Rémanence cible
- Butin
- Capture
- Bonus connaissance

Donc `Essence` ne peut plus être supprimée des données de rencontre comme si elle n'existait pas. En revanche, le référentiel retrouvé ne suffit pas à lui seul à définir sa fonction globale de dépense/persistance. Statut pré-PC : **donnée de récompense canonique présente, fonction économique globale à valider/consolider**.

La Connaissance reste qualitative et le bonus de connaissance récompense notamment une nouvelle entrée de bestiaire.

## Narration de zone

Les couches narratives actuelles du référentiel comprennent :

- 64 rencontres narratives
- 29 entrées de bestiaire narratif
- 68 barks Veilleurs
- 30 lignes de dialogue boss
- 15 événements narratifs régionaux
- 667 clés FR stables

Règle narrative récupérée : `Observation ≠ certitude`; la Lumière stabilise le référentiel partagé, jamais une vérité absolue.

Toute nouvelle scène doit respecter cette couche avant d'inventer des textes de remplacement.

## Interconnexion Universe

Les Veilleurs montrent des pratiques encore émergentes : observation structurée, ralliement/auxiliaires, traitement des altérés, mémoire des blessures, cohabitation et règles communes. Les jeux futurs peuvent institutionnaliser, déformer ou oublier ces pratiques sans que Les Veilleurs deviennent une simple préquelle explicative.

## Règle avant expansion

Avant d'ajouter une compétence, ennemi, rencontre ou boss hors référentiel :

1. intégrer la verticale Acte I ;
2. faire passer les gates ;
3. exécuter les tests pertinents parmi `Tests_48` ;
4. mesurer mobile/PC ;
5. seulement ensuite étendre le corpus.
