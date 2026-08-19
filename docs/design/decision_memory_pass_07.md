# Mémoire des décisions et convictions — Pass 07

## Intention

Les relations entre héros ne naissent plus seulement des combats. Les décisions politiques importantes deviennent des souvenirs persistants que chaque héros interprète selon ses propres convictions. Une même décision peut donc renforcer certains liens et en tendre d'autres sans être classée globalement comme « bonne » ou « mauvaise ».

## Convictions

Huit axes servent de vocabulaire interne : solidarité, sécurité, procédure commune, clémence, ouverture, pragmatisme, autonomie et justice. Les quatre héros du niveau d'essai ont des profils distincts. Ces valeurs ne sont jamais affichées sous forme de statistiques numériques : le joueur les découvre dans les réactions et les souvenirs.

## Mémoire d'une décision

Lorsqu'une décision de Concorde est prise, chaque héros vivant présent reçoit une mémoire contenant : la décision, le chapitre, son jugement initial, les convictions qui ont le plus pesé et les réévaluations ultérieures.

Les héros qui interprètent la décision dans le même sens peuvent gagner un peu de confiance. Deux héros qui la vivent de manière opposée peuvent développer de la méfiance ou, dans les désaccords les plus forts, du ressentiment.

## Changer d'avis

Un jugement n'est pas définitif. Les événements sociaux déjà présents dans le Sanctuaire peuvent revenir sur une ancienne décision : rumeurs xénophobes après l'accueil des réfugiés, bol refusé à la Taverne, débat autour d'une créature consciente, tentative de lynchage ou demande de pouvoir d'urgence.

Ces événements ne réécrivent pas artificiellement l'opinion de tous. Ils sont comparés aux convictions de chaque héros. Un héros préoccupé par la sécurité peut voir ses doutes confirmés ; un autre attaché à la solidarité peut au contraire considérer que le même incident rend le choix initial encore plus nécessaire.

Si deux héros autrefois opposés convergent après les événements, une partie de leur méfiance et de leur ressentiment peut diminuer. S'ils divergent plus fortement, une petite tension supplémentaire apparaît.

## Persistance

Convictions et mémoires sont stockées directement dans les dictionnaires des héros, donc dans `GameState.party`, déjà sérialisé par la sauvegarde. Les anciennes sauvegardes reçoivent automatiquement les profils manquants et le bridge politique peut reconstruire les mémoires correspondant aux décisions déjà enregistrées dans `PoliticalState`.

## Interface

`main_v19.gd` ajoute à la Taverne un bloc **MÉMOIRES DE DÉCISION** écrit uniquement en prose. Il n'expose ni score de conviction, ni valeur d'approbation, ni nouvelle jauge.

Exemples de formulations :

- « Darius n'a toujours pas accepté… »
- « Lysandra continue d'approuver… »
- « Malvor reste partagé… »

Les événements différés écrivent aussi une courte trace dans le journal lorsque l'opinion d'un héros change ou lorsqu'une ancienne décision revient dans les conversations.

## Architecture

- `DecisionMemoryRuntime` : interprétation, mémoire, réévaluation et effets relationnels ;
- `DecisionMemoryBridge` : observe les décisions et événements déjà gérés par `PoliticalState` sans modifier son contrat historique ;
- `data/hero_decision_memory.json` : profils, vecteurs des choix et conséquences différées ;
- `main_v19.gd` : restitution narrative au Sanctuaire.

## Validation

Le pass est couvert par un smoke Godot dédié, un audit QA, des contrats Python et la CI stricte existante. La validation vérifie aussi qu'aucune nouvelle jauge de HUD n'est introduite.
