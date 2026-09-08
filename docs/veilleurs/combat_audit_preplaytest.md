# Audit combat — Les Veilleurs

Audit initié depuis `main` à `a41cd18829bfc9c79dd720de9e28f0b32641bb7c`, puis revérifié contre `main` jusqu'à `cad1c5d158acb4e8291dd01c72e0dd8777cd4150`.

## Objectif

Figer les règles de combat déjà validées, sans confondre les constantes réellement codées avec les hypothèses qui doivent encore être tranchées par un playtest tactile humain.

## Verdict

Le cœur tactique est suffisamment opérationnel pour être gelé avant playtest humain. À ce stade, aucune refonte structurelle ne doit être entreprise sans observation issue d'un playtest. Les prochains changements doivent viser en priorité lisibilité, feedback, rythme, confort tactile et tuning.

## Règles codées à conserver

### Plateau et résolution

- grille tactique : 6 x 5 ;
- précision : `BaseSkill + (PRE_attacker - MOB_defender)*0.45 + position_mod + zone_mod + states` ;
- chance de toucher bornée à 10–97 % ;
- modificateurs anatomiques : torse +5, tête -15, bras -5, jambes -3 ;
- puissance : `WeaponPower * SkillMultiplier * (0.70 + FOR/200)` ;
- réduction d'armure : `Armor / (Armor + 100)`.

### Anatomie et conséquences

- intégrité de référence : tête 70, torse 140, bras 90, jambes 100 ;
- états corporels progressifs de L0 à L5 ;
- démembrement uniquement si la zone, le niveau de destruction, le type d'attaque et la puissance de démembrement sont compatibles ;
- les blessures `wounded` ou pires persistent après extraction ;
- une blessure critique crée un événement d'historique ;
- un membre perdu devient un état corporel permanent ;
- le mode gore peut être réduit ou désactivé sans modifier les mécaniques.

### IA et mémoire

- mémoire bornée pour préserver les performances mobile ;
- observations : 8, événements : 6, relations : 4 ;
- adaptations maximales : Memorial 1, Veteran 2, Elite 4, Nemesis 5 ;
- pas de simulation complète des ennemis hors écran ni de ragdolls vivants persistants ; l'état persistant repose sur seed + différences + cicatrices.

### Soumission et recrutement

- soumission déterministe ;
- cible obligatoirement vivante et non-boss ;
- PV <= 35 % ;
- résolution <= 20 ;
- au moins un état de contrôle accepté parmi `FEAR`, `PINNED`, `IMMOBILIZED`, `STAGGER` ;
- succès = `SUBDUED` : la cible cesse d'agir, compte comme résolue pour le combat mais reste vivante ;
- recrutement uniquement après victoire et uniquement parmi les candidats vivants ;
- maximum 3 candidats présentés ;
- choix : recruter, épargner ou laisser.

### Némésis

- maximum 1 Némésis réinjectée par rencontre ;
- seulement dans les stades élite/Némésis, statut actif ;
- préférence pour la même région ;
- minimum 2 rencontres et score 10 ;
- jamais injectée dans un combat de boss ;
- départage déterministe.

### Boss

- boss non soumissibles ;
- 3 phases ;
- transitions à 70 % et 35 % de PV ;
- 1 round de télégraphie avant transition ;
- les cinq boss de production disposent de leur séquence de phases dédiée.

### Persistance et vertical slice

- six donjons de production exposent le combat tactique réel ;
- sauvegarde v0.9 couvre donjon, combat actif, blessures d'expédition, décisions de recrutement et Rémanence ;
- victoire, retraite et défaite doivent conserver des sorties distinctes ; recrutement interdit après retraite/défaite.

## Référence d'équilibrage déjà codée

La référence v0.6.1 est explicitement pré-playtest et ne doit pas être interprétée comme équilibrage final :

- puissance d'arme Veilleur : 30 ;
- puissance d'arme ennemi : 42 ;
- première rencontre : taux de victoire cible 65–92 % ;
- première rencontre : 4–14 rounds ;
- Veilleurs survivants cible : 1,4–3,8 ;
- le playtest tactile humain reste l'autorité finale.

## Hypothèses UX à mesurer, pas à imposer

Les anciennes cibles `4–7 / 6–10 / 10–16 rounds` sont reclassées en hypothèses de confort. Elles ne remplacent pas la plage codée de 4–14 rounds pour la première rencontre. Le playtest devra déterminer si les combats standard, élite/Némésis et boss sont trop courts, trop longs ou suffisamment lisibles.

À mesurer : temps réel par round, nombre de taps par action, temps de compréhension de la cible/zone, taux d'annulation ou de mauvais tap, fréquence des tours sans contre-jeu, compétences surutilisées, dégâts/soins/contrôles, blessures, retraites et sensation d'attrition.

## Garde-fous de design avant playtest

1. Une action importante doit produire immédiatement un feedback compréhensible.
2. Aucun personnage ne doit perdre plusieurs tours sans possibilité identifiable de contre-jeu, sauf conséquence exceptionnelle clairement télégraphiée.
3. Une seule compétence ne doit pas devenir la réponse optimale universelle.
4. Soin et contrôle ne doivent pas effacer durablement l'attrition.
5. Chaque arbre conserve une identité tactique distincte.
6. La difficulté doit venir des décisions, blessures, synergies, positions et priorités de cible plutôt que d'une inflation artificielle des PV.
7. Les informations nécessaires à une décision doivent être accessibles sur téléphone sans texte minuscule ni précision de tap excessive.

## Critères GO / NO-GO pour le playtest PC/mobile

### GO

- combat complet jusqu'à victoire/défaite/retraite sans erreur ;
- chaque action disponible est sélectionnable et résolue ;
- états et blessures visibles et compréhensibles ;
- IA termine ses tours sans blocage ;
- boss changent de phase correctement ;
- Rémanence et blessures survivent aux transitions et à la sauvegarde/reprise ;
- recrutement n'apparaît que lorsque ses conditions sont valides ;
- état affiché cohérent avec l'état interne.

### NO-GO

- soft-lock de tour ;
- action sans cible valide néanmoins exécutable ;
- état persistant perdu après transition ou sauvegarde ;
- boss soumis ou recrutable ;
- divergence entre PV/états affichés et runtime ;
- interaction tactile demandant une précision incompatible avec un téléphone ;
- information critique uniquement disponible par texte trop petit ou ambigu.

## Ordre du prochain playtest humain

1. combat standard simple ;
2. combat avec contrôle, saignement et blessure ;
3. combat élite/Némésis ;
4. soumission puis recrutement ;
5. retraite ;
6. défaite ;
7. boss trois phases ;
8. sauvegarde au milieu d'un combat puis reprise ;
9. enchaînement de plusieurs combats pour vérifier attrition et Rémanence ;
10. répétition sur interface tactile.

## Mesures à relever

Durée totale, durée moyenne d'un round, nombre de rounds, taux de victoire/retraite, Veilleurs survivants, dégâts subis, contrôles subis, blessures, compétences les plus utilisées, actions mal comprises, erreurs tactiles, soft-locks et incohérences UI/runtime.

Le cœur tactique reste gelé jusqu'à ce que ces mesures fournissent une raison observable de le modifier.