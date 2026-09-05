# LITD : Les Veilleurs — audit canonique statique pré-PC

Date : 2026-09-04

## Source canonique auditée

Source bibliothèque : `LITD_Les_Veilleurs_Referentiel_Combat_Maitre_Narratif.xlsx`.

Copie corrigée sans changement de gameplay : `LITD_Les_Veilleurs_Referentiel_Combat_Maitre_Narratif_CORRIGE_ID.xlsx`.

Deux collisions historiques d'identifiants ont été corrigées uniquement dans la copie de travail canonique :

- `DÉL-CHA-01…15` reste attaché à **Chair ouverte** ; **Chair de réserve** devient `DÉL-RÉS-01…15`.
- `POR-PRO-01…15` reste attaché à **Procession immobile** ; **Procession muette** devient `POR-MUE-01…15`.

Aucun nom de compétence, effet, valeur de combat ou progression n'a été modifié par cette correction.

## Invariants vérifiés

- 4 Veilleurs : Nayra Orun, Tarek Senn, Aïsha Maren, Idris Vael.
- 12 arbres Veilleurs.
- 180 compétences Veilleurs, 180 IDs uniques.
- 12 ultimes Veilleurs.
- 24 ennemis ordinaires + 5 boss.
- 87 arbres ennemis/boss.
- 1 305 compétences ennemis/boss, 1 305 IDs uniques après correction.
- 87 ultimes ennemis/boss.
- Total : 99 arbres, 1 485 compétences normales, 1 485 IDs uniques, 99 ultimes.
- 15 compétences exactement par arbre.
- Échelle commune des 99 arbres : `1,4,7,10,13,16,19,22,25,28,31,35,39,44,49`.
- Progression 1–50 complète.
- 30 états de Rémanence des blessures.
- 60 Traces psychologiques ; l'ancienne mention « 59 » est une erreur documentaire.
- 64 compositions et 64 rencontres narratives, appariement exact.
- 29 entités combat et 29 fiches narratives, appariement exact.
- 5 boss / 16 phases.
- 667 clés de localisation FR uniques.
- 48 scénarios de validation uniques.

## Empreintes SHA-256 de référence

### Compétences

- `Compétences_180` : `400896bcc6db6a69c936306001f67e66dcb2afa2c741e75e0502c607bad9ddf2`
- `Comp_bestiaire_585` : `761cef57f0ce34c6a5d36267b4b9e979de14c2924ac52051d2a7cab3d95838e7`
- `Comp_II_V_720` : `ac794311537650d88717b96a4ada86765a19c09c537578766361707986645356`

### Ultimes

- `Ultimes_12` : `4b014267212e121407ccb87bc5261992fffaaf5855c91199c6317ebd1f71c2dc`
- `Ult_bestiaire_39` : `121240dec74a2e9314df443a9b524372fb8c547be884364552e1097572391db1`
- `Ult_II_V_48` : `7d1f47f4409491c62655b88743000e3204418f5a968138a296adb71c66421fa5`

### Systèmes et validation

- `Tests_48` : `31bd5279fafc4ca5a40bb1646b60cac03d168f5d41dbad3dce5edb5ae875815f`
- `Progression_1_50` : `2217a12b566969354052547536589346876e521fadadfeb0e7f3b3612c704aca`
- `Rémanence_blessures` : `76d8778ad030991e57590058be40f8fef36e6afa7679338f2b650f13b725639c`
- `Traces_psychologiques` : `cb1e3688c89416e4d3e2ccc24d8c185a6bf118725ead0c8981dab44e1a3edfdb`
- `Compositions_64` : `7b657e86385dda0d2fae571a2b51d002761f25d2522c812aa3aeeb9e69841a09`
- `Boss_5_phases` : `0e677381e830fbc8b82de85f8b8ea2e558098a9722450afa33e50f83b24d30d9`
- `Localisation_FR` : `256a72fecfb61c905c84f82cfd34750d17d9a4c8059b80750982dd0c65832976`

## Règle de build

Le stade historique `315 compétences / 21 ultimes` ne doit jamais être chargé comme canon actif. Les fingerprints ci-dessus servent à détecter un export incomplet, une collision réintroduite ou un mélange accidentel avec les données legacy.

Les valeurs de gameplay du référentiel sont des baselines de prototype : elles doivent être mesurées dans Godot avant d'être considérées comme équilibre final.
