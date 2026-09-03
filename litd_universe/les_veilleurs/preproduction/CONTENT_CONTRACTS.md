# LITD : Les Veilleurs — Contrats de contenu V1

## Progression 1-50

La progression ne doit jamais annuler l'importance des blessures, de l'armure ou du terrain. Monter de niveau augmente surtout maîtrise, options, fiabilité, spécialisation et capacité à exploiter le système.

Bandes fonctionnelles des Veilleurs, tant que les niveaux de nœuds exacts ne sont pas revalidés :

- 1-9 : fondations, lecture du rôle, actions fiables.
- 10-19 : identité de l'arbre et engagement tactique.
- 20-29 : maîtrise et premières interactions systémiques complexes.
- 30-39 : conséquences avancées, contre-jeu, exploitation du terrain/anatomie/SPE.
- 40-49 : expertise de haut niveau, fortes synergies et coûts réels.
- 50 : accomplissement du parcours, sans immunité aux règles du monde.

Chaque arbre contient exactement 15 compétences et possède un UltimateDefinition séparé. Les cadences précises d'acquisition et le nombre d'usages d'ultime restent PROTOTYPE jusqu'à validation du rythme de run.

Recrues : L5 adaptation ; L10 orientation ; L15 modification native ; L20 transformation fonctionnelle ; L25 passive majeure ; L30 seconde transformation ; L35 amélioration signature ; L40 maîtrise ; L45 trait exceptionnel ; L50 forme accomplie.

## Chorégraphie des 21 ultimes

Toute chorégraphie suit cinq beats :

1. Déclaration/lecture : le joueur comprend l'intention.
2. Engagement : l'utilisateur s'expose ou consomme une opportunité réelle.
3. Contact/phénomène : interaction avec géométrie, cible et environnement.
4. Conséquence : anatomie, position, volonté, terrain, réseau ou information changent réellement.
5. Après-coup : repositionnement, fatigue, ouverture, trace ou effet de monde.

Un ultime doit être signature de son arbre, pas une version avec plus de dégâts. Il peut être interrompu uniquement selon des règles déclarées. Il ne garantit jamais un démembrement impossible anatomiquement.

## Équipement

Armes : exigences de prise et fonctions corporelles, portée, masse, modes d'attaque, types d'impact, pénétration, précision, durabilité, bruit, vibration, usages environnementaux.

Armures : couverture par zone, matériau, rigidité, absorption, déflexion, résistance à pénétration, état, mobilité, bruit et éventuels effets thermiques/respiratoires.

Une armure endommagée peut créer une faiblesse locale persistante pendant l'expédition. Une pièce lourde peut sauver un membre tout en rendant une approche discrète plus difficile. Les valeurs numériques exactes restent PROTOTYPE.

## Résolution des dégâts et du gore

Aucune compétence ne dit directement « coupe un bras » sans résolution. Le moteur vérifie contact, armure, tissus, état préalable, puissance, type d'impact et éligibilité anatomique. Les conséquences fonctionnelles ont priorité sur une simple perte de HP.

Le jeu doit savoir produire : contusion, lacération, perforation, fracture, luxation, rupture musculo-tendineuse, saignement externe/interne, brûlure, écrasement, section et traumatisme d'organe, lorsque l'anatomie de l'espèce le permet.

Les causes terminales peuvent provenir de destruction vitale, hémorragie, insuffisance respiratoire, choc ou atteinte d'organe majeure, mais le modèle doit rester lisible comme jeu et non devenir une simulation médicale exhaustive.

## Génération hybride des donjons

Structure : auteur pour la macro-dramaturgie ; procédural pour modules et variations ; Rémanence pour réinjecter l'histoire.

RoomTags V1 : TRAVERSAL, COMBAT, AMBUSH, REFUGE, LORE, HAZARD, VERTICAL, ACOUSTIC, BIOLOGICAL, ASH, BOSS_APPROACH, EXTRACTION.

Pipeline : CampaignSeed -> AuthoredMacroGraph -> ZoneConstraints -> RoomModuleSelection -> ConnectivityValidation -> PersistentScarInjection -> FactionEcologyState -> EncounterDirector -> ResourcePlacement -> NarrativeAnchors -> ExtractionValidation -> ConsistencyPass.

Contraintes fortes : toujours au moins un chemin légal jusqu'à un état d'extraction ; aucune cicatrice persistante ne doit rendre une campagne impossible sans route alternative explicitement gérée ; les salles importantes restent identifiables malgré la variation procédurale ; les Némésis et cadavres persistent via ancrages plutôt que coordonnées fragiles.

## Directeur de rencontres

Entrées : profondeur, état de la zone, bruit/alertes récents, faction/écologie, cicatrices, ennemis mémoriels disponibles, composition du groupe, événements narratifs autorisés.

Le directeur ne doit pas contrer artificiellement la composition du joueur. Il crée un monde cohérent puis laisse les forces/faiblesses de la composition produire les conséquences.

Pas de rubber band caché transformant chaque rencontre en matchup parfait.

## Boss et mini-boss

Boss et mini-boss : jamais ralliables dans le bestiaire V1. Leur identité vient d'une doctrine et d'une fonction, non d'un multiplicateur de PV.

Un boss peut changer de phase lorsque : fonction corporelle détruite, relais coupé, support environnemental perdu, doctrine invalidée, objectif secondaire accompli, terrain transformé. Un seuil de PV peut exister si physiquement justifié, mais ne doit pas être le principe par défaut.

Le boss respecte le même moteur d'anatomie. Une anatomie spéciale doit être déclarée, jamais codée comme exception cachée.

Cartographe Retourné et Conservateur sont réservés comme références de contenu déjà travaillées ; leurs données finales doivent être récupérées et validées avant implémentation afin d'éviter une réécriture contradictoire.

## Économie d'expédition

Ressources : Or, Provisions, Matériaux, Remèdes. Connaissance qualitative.

Arbitrages de chargement : provisions, équipement, traitement/stabilisation, moyens de contention lorsqu'ils sont nécessaires, capacité de loot et marge pour extraire un blessé/un corps.

Sources : exploration, objectifs, récupération, démontage cohérent, commerce, rôles du Refuge, connaissance qui ouvre de nouvelles possibilités.

Sinks : préparation, soins, réparation, équipement, améliorations et adaptations du Refuge.

Anti-softlock : une suite d'échecs ne doit pas rendre la prochaine expédition mathématiquement impossible. Prévoir un plancher de récupération, des options de mission à faible engagement et des solutions de réparation/soin basiques. Les quantités restent PROTOTYPE.

## Paquet narratif obligatoire par zone

Chaque zone majeure renseigne : visible_problem, hidden_human_truth, historical_layer, philosophical_question, ecology_rule, gameplay_rule, rally_discovery, boss_thesis, remanence_scar, litd2_echo, litd1_echo.

La narration ne doit pas expliquer la philosophie par monologue si une situation de jeu peut la faire vivre. Les choix doivent produire conséquences et mémoire plutôt qu'une jauge morale.

## Marches du Sanctuaire — axe de travail

Axe compatible avec le bestiaire actuel : fonctions de protection, conservation, surveillance et mémoire qui survivent à leur intention initiale ; début de la Concorde et institutions encore incomplètes ; rencontres qui obligent à distinguer monstre, survivant, organisme et fonction héritée.

Ce texte est une direction, pas un verrouillage de scènes précises. Les scènes canoniques déjà écrites doivent primer lors de l'ingestion finale.

## Interconnexion Universe

Les Veilleurs montrent des pratiques encore émergentes : observation structurée, ralliement, cohabitation, traitement des altérés, premières règles du Refuge et mise en commun de connaissances. LITD1 peut montrer des versions institutionnalisées, simplifiées ou déformées de ces pratiques. La connexion doit être reconnaissable sans réduire Les Veilleurs à une préquelle explicative.

## Règle de contenu avant expansion

Chaque nouvelle compétence, ennemi, salle, objet ou scène doit démontrer au moins une contribution claire à un pilier du jeu et utiliser les systèmes transversaux plutôt que créer une exception spéciale. Si un contenu exige un nouveau système, il doit justifier son coût mobile et sa valeur de réutilisation.
