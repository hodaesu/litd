# LITD : Les Veilleurs — Gel de préproduction avant PC

Date : 2026-09-03
Statut : contrat fonctionnel pré-prototype, corrigé après récupération du référentiel combat maître narratif le plus récent.

## Source de vérité de ce gel

Pour le combat, les rencontres et le bestiaire : `LITD_Les_Veilleurs_Referentiel_Combat_Maitre_Narratif.xlsx` est désormais la source maîtresse récupérée. Voir `CANON_RECOVERY_2026-09-03.md`.

## Principes non négociables

- Godot, mobile-first avec adaptation PC complète.
- Groupe de 4 combattants maximum, toujours au moins 1 Veilleur.
- Les 4 Veilleurs sont les seuls protagonistes humains permanents ; les renforts viennent du Ralliement lorsque le référentiel d'espèce l'autorise.
- Mort permanente. Pas de résurrection.
- Gore systémique : anatomie, impacts, lésions, conséquences fonctionnelles, armure et environnement. Aucun démembrement par simple proc arbitraire.
- Rémanence : individus, cadavres, ennemis mémoriels, connaissance et cicatrices du donjon persistent de façon bornée.
- Ralliement découvert par connaissance et observation ; aucun pourcentage de capture visible.
- Perception ennemie honnête : aucune IA ne connaît automatiquement la position du joueur.
- Connaissance qualitative, jamais monnaie abstraite.

## Veilleurs canoniques et IDs stables

- V01 / `veilleur.v01` : Nayra Orun — avant-garde / protection / rupture physique.
- V02 / `veilleur.v02` : Tarek Senn — mobilité / traque / discrétion / information.
- V03 / `veilleur.v03` : Aïsha Maren — anatomie / soin / neutralisation / Rémanence corporelle.
- V04 / `veilleur.v04` : Idris Vael — autorité / ordre / politique / cohésion et dissidence.

Les noms de présentation ne servent jamais de clés de sauvegarde.

## Corpus actuel des Veilleurs

- 4 Veilleurs.
- 3 arbres chacun.
- 12 arbres.
- 15 compétences normales par arbre.
- 180 compétences normales.
- 12 ultimes séparés.

Ultimes canoniques actuels :

- Nayra / Bastion — `La Ligne ne rompt pas`.
- Nayra / Brisure — `Le Poids du Mur`.
- Nayra / Serment — `Pas un de plus`.
- Tarek / Traque — `La Proie n’a plus d’ombre`.
- Tarek / Entaille — `Les Sept Ouvertures`.
- Tarek / Disparition — `Là où nul ne regarde`.
- Aïsha / Anatomie — `Carte parfaite du vivant`.
- Aïsha / Suture — `Tout ce qui peut être sauvé`.
- Aïsha / Hémocorde — `Le Dernier Battement`.
- Idris / Sentence — `Le Verdict tombe`.
- Idris / Concorde — `Un seul mouvement`.
- Idris / Dissidence — `Que l’ordre se brise`.

Baseline actuelle des charges : N16=1, N32=2, N48=3, avec une activation maximum du même ultime par rencontre. À confirmer en playtest Godot.

## Ancien stade 315

Le contrat `21 arbres / 315 compétences / 21 ultimes` basé sur Barek Thann, Ilya Kesh et Oshren Vaïr est archivé comme étape de conception antérieure. Il ne doit plus être utilisé par les validateurs du build actuel.

## Bestiaire actuel du référentiel maître

### Acte I — Les Marches du Sanctuaire

- Délié Affamé
- Délié Boursouflé
- Censeur Fendu
- Flagellant Fendu
- Sentinelle du Seuil
- Exécuteur de Pierre
- Traque-Suie
- Brise-Os de Suie
- Boss : Ishar, Gardien du Passage

### Acte II — Les Routes Muettes

- Écouteur Creux
- Porte-Signe
- Marcheur Aphone
- Reteneur de Souffle
- Boss : Orateur Sans Voix

### Acte III — Ce qui pousse sous nous

- Veine Rampante
- Nœud-Écorché
- Porte-Sang
- Germe Artériel
- Boss : Mère des Veines

### Acte IV — Les Cendres de la Paix

- Marche-Pâle
- Porte-Linceul
- Effaceur de Traces
- Dormeur de Cendre
- Boss : Porte-Cendres Blanc

### Acte V — Les Versions

- Copie Lacunaire
- Rature Vivante
- Archiviste de Version
- Double du Seuil
- Boss final : Le Copiste

Total actuel : 24 ennemis ordinaires + 5 boss = 29 entités nommées. Chaque entité possède 3 arbres de 15 compétences dans le référentiel actuel : 1 305 compétences ennemies/boss + 87 ultimes.

Le corpus combat spécifié totalise donc actuellement 1 485 compétences normales et 99 ultimes séparés, mais cette quantité ne doit pas être implémentée avant validation de la verticale jouable.

## Matrice 25 archétypes / 75 orientations

La matrice antérieure Déliés / Retournés / Silencieux / Veines / Porte-Cendres reste conservée comme réserve de concepts et design legacy. Elle ne doit plus être utilisée comme contrat quantitatif du build sans décision explicite de réintégration.

Les systèmes qu'elle a permis de définir restent valables : Ralliement, Refuge, relations, blessures persistantes, choix de traitement, mémoire individuelle et conséquences de libération.

## Compétence : contrat systémique

Chaque compétence doit renseigner au minimum : identité stable, propriétaire, arbre, niveau, type, fonction, positions, cible, impacts, zones privilégiées, puissance qualitative, précision qualitative, lésions possibles, conséquences fonctionnelles, démembrement, interaction armure, interaction environnement, risque utilisateur, tags, cooldown, charges, conditions, variante si blessé, variante équipement et note d'intégration Godot.

Aucune compétence physique ne contourne gratuitement anatomie, armure ou géométrie.

## Refuge

Capacité de conception conservée : I=4, II=6, III=8, IV=10, V=12. Les résidents ont besoins, fonctions et droits ; ils peuvent demander à partir. Les relations utilisent Confiance, Respect, Peur et Ressentiment.

## SPE — perception événementielle

Canaux : vision, son, odeur, vibration, biologique ; perturbations de cendre comme médium spécialisé. Une perception crée une hypothèse avec certitude, jamais une position omnisciente.

Cycle IA : PERCEIVE -> UPDATE BELIEFS -> ASSESS SELF -> ASSESS SITUATION -> SELECT GOAL -> SELECT ACTION -> EXECUTE -> LEARN/REMEMBER.

## Rémanence

Mémoire individuelle bornée. Ennemi : NORMAL -> MEMORIEL -> VETERAN -> ELITE -> NEMESIS uniquement par événements vécus. Persistance du monde par cicatrices ancrées plutôt que snapshots complets.

Le référentiel récupéré contient aussi les tables `Rémanence_blessures` et `Traces_psychologiques`, à importer avant extension du contenu.

## Rencontres

Le référentiel actuel fixe :

- 64 templates de rencontre.
- 5 paliers de profondeur par acte.
- 12 dangers de combat persistants.
- 48 cas de validation préparés.
- 4 acteurs ennemis simultanés maximum en combat standard mobile.
- 5 boss avec 16 phases au total : Ishar 3, Orateur 3, Mère des Veines 3, Porte-Cendres Blanc 3, Copiste 4.

## Génération et sauvegarde

Pipeline hybride : seed campagne -> macrographe auteur -> contraintes -> modules -> connectivité -> cicatrices -> écologie/factions -> directeur de rencontres -> ressources -> ancres narratives -> extraction -> cohérence.

RNG séparés par flux. Recharger ne reroll jamais les propriétés persistantes.

## Boss

Boss non ralliables. Pas de sacs à PV : terrain, fonctions, doctrine, réseau, seuils et conditions tactiques doivent compter. Le référentiel maître fournit déjà les phases et dialogues des cinq boss actuels.

## Interface

Mobile : information fonctionnelle d'abord, détails contextuels, ciblage anatomique lisible au pouce. PC : densité supérieure, pas simple agrandissement mobile.

## Ce qui reste PROTOTYPE

Les valeurs numériques du référentiel sont une baseline de conception, pas un équilibrage final. Restent à valider dans Godot : dégâts/PV, timings, cooldowns, haptique, lisibilité tactile, densité, rythme XP, économie, mémoire IA, difficulté et performance.

## Blocage réel atteint

Le référentiel maître indique explicitement que la suite utile exige désormais :

- CombatResolver Godot.
- intégration/exécution du générateur de rencontres.
- IA + intentions.
- exécution des 48 tests automatiques.
- playtests mobile/PC.

Le travail éditorial de récupération des compétences et ultimes n'est plus bloquant : la source exacte a été retrouvée.
