# LITD — Veilleur : pipeline de recherche appliquée

Statut : **OFFICIEL / ACTIF**

## Principe

La bibliothèque LITD n'est pas une archive passive. Toute connaissance candidate doit être traitée comme une hypothèse susceptible d'améliorer concrètement Light in the Dark.

## Pipeline obligatoire

1. **Découverte** — identifier une connaissance, méthode, œuvre, recherche ou pratique pertinente.
2. **Vérification** — rechercher les sources primaires lorsque possible, dater l'information, évaluer provenance et fiabilité.
3. **Comparaison** — confronter plusieurs sources, méthodes, cultures, implémentations ou écoles.
4. **Contradiction** — rechercher activement des preuves contraires, limites, échecs et coûts cachés.
5. **Classement bibliothèque** — enregistrer le savoir, ses sources, son niveau de confiance, sa date et ses domaines.
6. **Analyse de pertinence LITD** — préciser quel système, scène, personnage, environnement, mécanique, outil ou processus pourrait être amélioré.
7. **Proposition concrète** — formuler une modification testable, sans transformer automatiquement une découverte en décision de design.
8. **CORE_CHANGE_CANDIDATE** — uniquement si la proposition touche une règle structurante du projet. Aucun changement du Core sans preuve et validation.
9. **Implémentation contrôlée** — changement versionné et réversible.
10. **Test en jeu / validation technique** — vérifier comportement, performance, lisibilité, cohérence artistique et régressions.
11. **Mesure** — comparer le résultat aux critères définis avant implémentation.
12. **Retour d'expérience** — conserver résultat, échec ou réussite, limites et décision finale dans la bibliothèque.

## Domaines officiels surveillés

- Art et histoire de l'art
- Musique, composition, musique interactive, sound design et acoustique
- Game design
- Philosophie
- Psychologie et cognition du joueur
- Sociologie
- Anthropologie
- Mythologies, légendes, folklore et traditions narratives de **tous les pays et cultures du monde**, en conservant variantes régionales et contexte culturel
- Dialogue, dialoguistes, sous-texte et caractérisation
- Scénarisation, dramaturgie et analyse de scénarios
- Mise en scène : théâtre, cinéma et jeu vidéo
- Architecture mondiale : historique, vernaculaire, sacrée, militaire, domestique, monumentale et funéraire ; urbanisme, ruines, matériaux, construction et circulation spatiale
- Physique appliquée au jeu vidéo : mouvement, forces, collisions, projectiles, fluides, tissus, destruction, optique/lumière, acoustique, simulation et approximations
- Programmation, moteurs, architecture logicielle et optimisation
- UX/UI et accessibilité
- Génération procédurale
- Mathématiques, probabilités, statistiques et équilibrage
- QA, tests et instrumentation
- Sécurité logicielle et chaîne de dépendances
- Production et méthodes de travail

## Règles culturelles

Une mythologie, tradition, architecture ou pratique culturelle n'est jamais copiée hors contexte. Le Veilleur doit distinguer source historique, tradition vivante, interprétation moderne et invention populaire. Il documente les variantes et évite de présenter une culture comme homogène.

L'objectif n'est pas de reproduire directement une figure culturelle dans LITD, mais de comprendre sa fonction, son symbolisme, son contexte et ses variantes avant toute inspiration créative.

## Grille d'impact LITD

Chaque proposition doit indiquer :

- domaine source ;
- source(s) et niveau de confiance ;
- élément LITD concerné ;
- problème ou opportunité ;
- bénéfice attendu ;
- coût d'implémentation ;
- coût CPU/GPU/mémoire si applicable ;
- risque artistique/narratif/culturel/technique ;
- critère de succès mesurable ;
- stratégie de retour arrière ;
- résultat après test.

## Exemples d'application

### Architecture
Une technique architecturale peut nourrir la structure d'un village, d'un sanctuaire ou d'un donjon, la circulation, la défense, le climat, la hiérarchie sociale et le langage visuel. La pertinence pour le level design doit être démontrée avant intégration.

### Mythologie
Une créature ou un récit est étudié par son contexte, ses variantes et sa fonction symbolique. Une proposition pour LITD doit produire une création originale cohérente avec la Terre des Cendres, plutôt qu'une copie superficielle.

### Physique
Une méthode de simulation de corde, cape, fumée, lumière, débris ou propagation sonore doit être comparée aux alternatives et évaluée en qualité visuelle/ludique, déterminisme, complexité et coût de performance.

## États d'une connaissance

`DISCOVERED → VERIFIED → COMPARED → CHALLENGED → LIBRARY_ACCEPTED → LITD_RELEVANCE_REVIEW → PROPOSAL → CORE_CHANGE_CANDIDATE (si nécessaire) → IMPLEMENTED_EXPERIMENT → TESTED → MEASURED → ACCEPTED | REJECTED | NEEDS_MORE_EVIDENCE`

Une information rejetée n'est pas supprimée : le motif du rejet reste conservé afin d'éviter de répéter inutilement la même recherche.
