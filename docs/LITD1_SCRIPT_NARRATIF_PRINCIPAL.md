# LITD 1 — Script narratif principal du cycle initial

> Statut : **script de production V1 complet pour la narration principale**  
> Portée : **cycle initial uniquement**  
> Source runtime : `data/narrative/main_script/manifest.json`

## Principe

La campagne principale possède désormais un script authored de bout en bout. Le runtime ne doit pas inventer les répliques nécessaires à la compréhension de l'histoire.

Le protagoniste est créé par le joueur. Pour cette raison, le script **ne lui impose pas une voix, un caractère ou des phrases fixes**. Lorsque le joueur intervient dans une scène, l'interface présente une intention ou une décision : demander les faits, privilégier une politique, refuser un risque, proposer une orientation. Les PNJ répondent ensuite avec des répliques authored.

## Couverture

Les dix chapitres possèdent chacun au moins huit scènes de production comprenant selon les besoins :

- ouverture de chapitre ;
- scènes de quêtes principales ;
- confrontations et boss ;
- retours ou débats au Sanctuaire ;
- choix et réponses immédiates ;
- conséquences enregistrables ;
- fermeture de chapitre et transition causale.

Toutes les quêtes principales définies dans `data/world/main_campaign.json` possèdent au moins une scène authored dans le script principal. Tous les boss principaux possèdent une scène de résolution authored.

## Contrat de dialogue

Une ligne principale doit toujours respecter :

1. la voix du personnage ;
2. ce qu'il sait réellement à ce chapitre ;
3. ce qu'il tente d'obtenir dans la scène ;
4. les limites du canon et du Voile ;
5. une fonction jouable : information, pression, décision, relation, révélation ou conséquence.

Les PNJ ne servent pas de terminaux de codex. Une information complexe doit être introduite parce qu'un personnage la conteste, l'utilise, la cache, la mesure ou doit prendre une décision à cause d'elle.

## Progression des dix chapitres

### I — Survivre aux Terres de Cendre
Survie, rationnement, premières règles de justice, relation initiale aux créatures, Témoin des Cendres, découverte de traces antérieures à la Chute.

### II — Les traces d'avant la Chute
Instruments pré-Chute, archives effacées, relais cachés, passage de l'accident à la préparation volontaire.

### III — Le Projet Seuil
Six responsabilités individualisées, Pacte de l'Horizon Fermé, sabotage tardif de Bram, limites de Veyra, Écho du Seuil, cause immédiate de la Chute établie.

### IV — La Première Rupture
Civilisation ashaï avant sa catastrophe, méthodes de mesure, quatre sources contradictoires, erreur de maîtrise, Chœur Inachevé, Voile non réduit à une porte spatiale.

### V — Or-Silex et la Grande Fermeture
Militarisation locale, doctrine de sécurité, réseau de Saan, populations sacrifiées par la Fermeture, parallèle contemporain, Général de Silex.

### VI — Les Absents
Signaux structurés, Saen, traces portées par certaines créatures, Frontière qui marche traitée sans conscience supposée, politique de contact et consentement.

### VII — Les responsables vivants
Bram, Veyra, Edras, neutralisation de toute nouvelle ouverture, confrontation et jugement public, responsabilité individuelle et procédure.

### VIII — Le monde extérieur
Varkhane, Namar, Azravel et Kor-Em comme sociétés pluralistes traversées de conflits internes ; régimes et institutions responsables distingués des populations.

### IX — Ce qu'est réellement le Voile
Lumière comme référence partagée, peur/Folie du Voile bornées, comparaison avec Saen, limites de l'expérimentation, inconnues assumées, Consensus Brisé.

### X — La lumière mérite d'être défendue
Assemblée représentative, coûts des orientations, dernière traversée, Rupture Commune non personnifiée, choix final conditionné par la campagne, réponse collective et épilogue.

## Runtime

`MainNarrativeScriptRuntime` :

- charge le manifest et les dix scripts ;
- recherche une scène par identifiant ou déclencheur ;
- démarre une scène ;
- avance beat par beat ;
- filtre les beats conditionnels ;
- présente uniquement les options disponibles ;
- enregistre les drapeaux produits par les choix ;
- expose sérialisation/désérialisation de la position courante dans une scène ;
- refuse ce script principal lorsque `active_cycle > 0`, afin de ne pas étendre silencieusement le NG+.

## Fichiers

- `data/narrative/main_script/manifest.json`
- `data/narrative/main_script/chapter_01_ashlands.json`
- `data/narrative/main_script/chapter_02_before_fall.json`
- `data/narrative/main_script/chapter_03_threshold.json`
- `data/narrative/main_script/chapter_04_first_rupture.json`
- `data/narrative/main_script/chapter_05_great_closure.json`
- `data/narrative/main_script/chapter_06_absent.json`
- `data/narrative/main_script/chapter_07_living_responsible.json`
- `data/narrative/main_script/chapter_08_outer_world.json`
- `data/narrative/main_script/chapter_09_veil_nature.json`
- `data/narrative/main_script/chapter_10_final_choice.json`
- `scripts/core/main_narrative_script_runtime.gd`
- `tests/python/test_main_narrative_full_script.py`

## Ce que « complet » signifie ici

Le script principal contient les scènes nécessaires pour jouer et comprendre l'histoire principale du cycle initial. Il peut encore recevoir plus tard du contenu secondaire : conversations optionnelles supplémentaires, variantes rares de réactions, bavardages de voyage, nouvelles quêtes secondaires ou doublage définitif.

Ces ajouts ne doivent pas être nécessaires pour comprendre la campagne, ses personnages centraux, ses révélations, ses choix ou ses fins.
