# LITD : Les Veilleurs — Récupération du canon combat

Date de récupération : 2026-09-03

## Source maîtresse retrouvée

Le fichier bibliothèque `LITD_Les_Veilleurs_Referentiel_Combat_Maitre_Narratif.xlsx`, créé le 2026-09-03 après le premier référentiel maître, est la source la plus récente retrouvée pour le combat, le bestiaire, les rencontres et la narration de combat.

Feuilles structurantes :

- `Compétences_180` — 180 compétences normales des quatre Veilleurs.
- `Ultimes_12` — 12 ultimes séparés.
- `Progression_1_50` — progression et coefficients de conception.
- `Rémanence_blessures` — 30 états corporels persistants/rémanents.
- `Traces_psychologiques` — 60 entrées incluant en-tête, 59 Traces numérotées visibles dans le référentiel.
- `Bestiaire_confirmé` — Acte I + boss nommés.
- `Comp_bestiaire_585` / `Ult_bestiaire_39` — première extension nommée.
- `Actes_II_V_bestiaire` — 16 ennemis ordinaires supplémentaires.
- `Comp_II_V_720` / `Ult_II_V_48` — arbres des actes II à V.
- `Compositions_64` — 64 rencontres.
- `Boss_5_phases` — phases des cinq boss.
- `Tests_48` — 48 cas de validation.
- `Pack_Godot` — inventaire du pack préparé pour l'intégration.
- `Bestiaire_narratif_29`, `Rencontres_narratives_64`, `Barks_Veilleurs`, `Dialogues_Boss`, `Evenements_narratifs`, `Localisation_FR` — couche narrative/localisation.

## Règle de précédence

Pour ce domaine :

1. Référentiel Combat Maître Narratif le plus récent.
2. Référentiel Combat Maître antérieur.
3. Décisions textuelles validées plus anciennes.
4. Propositions ou variantes exploratoires.

Cette règle n'autorise pas le tableur à réécrire le lore hors de son domaine. Elle tranche uniquement les divergences de données de combat/rencontres qu'il contient explicitement.

## Correction majeure : le stade « 315 » est historique

L'ancienne étape de conception :

- 4 Veilleurs = 180 compétences.
- Barek Thann, Ilya Kesh, Oshren Vaïr = 135 compétences.
- Total = 315 compétences + 21 ultimes.

est désormais **supersédée** comme contrat de contenu actuel.

Le référentiel actuel fixe :

### Veilleurs

- 4 Veilleurs.
- 12 arbres.
- 180 compétences normales.
- 12 ultimes séparés.

### Ennemis et boss actuels

- 24 ennemis ordinaires.
- 5 boss.
- 29 entités de combat nommées.
- 3 arbres par entité.
- 45 compétences normales par entité.
- 1 305 compétences ennemies/boss.
- 87 ultimes ennemis/boss.

### Total de contenu combat actuellement spécifié

- 99 arbres de compétences.
- 1 485 compétences normales.
- 99 ultimes séparés.

Ces nombres décrivent le contenu actuellement spécifié, pas une obligation d'implémenter tout le contenu avant la verticale jouable.

## Boss actuels

- Ishar, Gardien du Passage — Acte I.
- Orateur Sans Voix — Acte II.
- Mère des Veines — Acte III.
- Porte-Cendres Blanc — Acte IV.
- Le Copiste — Acte V / boss final.

Barek Thann, Ilya Kesh et Oshren Vaïr restent des éléments historiques de conception et ne doivent plus être utilisés par les validateurs du contenu actuel sans réintroduction explicite.

## Ultimes actuels des Veilleurs

### Nayra Orun

- Bastion — **La Ligne ne rompt pas**.
- Brisure — **Le Poids du Mur**.
- Serment — **Pas un de plus**.

### Tarek Senn

- Traque — **La Proie n’a plus d’ombre**.
- Entaille — **Les Sept Ouvertures**.
- Disparition — **Là où nul ne regarde**.

### Aïsha Maren

- Anatomie — **Carte parfaite du vivant**.
- Suture — **Tout ce qui peut être sauvé**.
- Hémocorde — **Le Dernier Battement**.

Les anciennes variantes `JE SAIS CE QUI VA CÉDER`, `JE VOIS CE QUI CÈDE`, `PAS ICI`, `TU NE MEURS PAS ICI`, `LE CORPS SE SOUVIENT` et `LE SANG A SA ROUTE` sont archivées comme variantes antérieures et ne sont plus les titres canoniques actuels.

### Idris Vael

- Sentence — **Le Verdict tombe**.
- Concorde — **Un seul mouvement**.
- Dissidence — **Que l’ordre se brise**.

## Règles de charges des ultimes récupérées

Le référentiel actuel indique pour les 12 ultimes :

- N16 = 1 charge.
- N32 = 2 charges.
- N48 = 3 charges.
- Au maximum une activation du même ultime par rencontre.
- Les effets restent soumis aux fonctions corporelles et conditions de l'arbre.
- Aucune invulnérabilité ni résurrection n'est accordée par un ultime.

Les valeurs finales restent à valider par prototype Godot, mais elles constituent désormais la baseline récupérée, pas une valeur inventée.

## Bestiaire actuel

Acte I confirmé :

- Délié Affamé
- Délié Boursouflé
- Censeur Fendu
- Flagellant Fendu
- Sentinelle du Seuil
- Exécuteur de Pierre
- Traque-Suie
- Brise-Os de Suie

Actes II–V confirmés :

- Écouteur Creux
- Porte-Signe
- Marcheur Aphone
- Reteneur de Souffle
- Veine Rampante
- Nœud-Écorché
- Porte-Sang
- Germe Artériel
- Marche-Pâle
- Porte-Linceul
- Effaceur de Traces
- Dormeur de Cendre
- Copie Lacunaire
- Rature Vivante
- Archiviste de Version
- Double du Seuil

## Conflit avec la matrice 25 archétypes / 75 orientations

La matrice Déliés / Retournés / Silencieux / Veines / Porte-Cendres à 25 archétypes et 75 orientations reste un travail de conception riche, mais elle n'est pas la liste de combat actuelle du référentiel maître retrouvé. Elle doit être conservée comme **design legacy / réserve de concepts** jusqu'à décision explicite de réintégration, au lieu d'être utilisée comme contrat quantitatif du build.

Les mécanismes de Ralliement, Refuge, blessures persistantes et relations restent valables comme systèmes. Seule la liste d'espèces/évolutions qui les alimente doit suivre le référentiel courant.

## Blocage réel

Le référentiel indique déjà comme blocage :

- CombatResolver Godot à implémenter.
- Générateur de rencontres à intégrer/exécuter.
- IA + intentions à intégrer/exécuter.
- 48 tests automatiques à exécuter.
- équilibrage tactile réel à valider en playtest mobile/PC.

La récupération de canon éditorial est donc terminée pour ce corpus : aucune régénération des 180 compétences ou des titres d'ultimes n'est nécessaire.
