# Light in the Dark — Campagne principale

> Statut : canon narratif et structure de progression de référence.

## Principe

La campagne principale suit dix chapitres. Chaque chapitre doit produire au moins une évolution du monde, une révélation vérifiée par plusieurs sources et une décision qui prépare les chapitres suivants.

Le jeu évite deux raccourcis :

1. révéler toute la vérité dans un unique document ou dialogue ;
2. transformer la fin en simple combat contre une divinité maléfique.

La progression est : survivre → soupçonner → identifier les responsables → découvrir l'histoire profonde → rencontrer les Absents → confronter les responsables vivants → traverser vers le monde extérieur → comprendre partiellement le Voile → décider collectivement de l'avenir.

## Chapitres

### I — Survivre aux Terres de Cendre
Le joueur découvre le Sanctuaire, la Folie, les créatures, les réfugiés et les premières traces impossibles à expliquer par la Chute actuelle.

### II — Les traces d'avant la Chute
Des dispositifs et archives prouvent que des anomalies furent observées avant la catastrophe et que des relais avaient été préparés.

### III — Le Projet Seuil
Le Pacte de l'Horizon Fermé, les commanditaires et les six acteurs majeurs du Projet Seuil deviennent identifiables.

### IV — La Première Rupture
Les Ashaï de Nhal révèlent que le Voile avait déjà été rencontré environ 3 700 ans auparavant.

### V — Or-Silex et la Grande Fermeture
Le joueur découvre la militarisation ancienne du Voile puis le réseau de confinement des Veilleurs de Saan et son prix humain.

### VI — Les Absents
Les populations disparues pendant la Grande Fermeture pourraient encore exister. Les créatures conscientes peuvent devenir des médiatrices avec certaines zones du Voile.

### VII — Les responsables vivants
Le joueur confronte plusieurs acteurs du Projet Seuil. La justice de la Concorde doit fonctionner précisément lorsqu'elle est la plus difficile à respecter.

### VIII — Le monde extérieur
Varkhane, Namar, Azravel et Kor-Em deviennent accessibles. Le joueur découvre des victimes, dissidents et complices au sein des mêmes sociétés.

### IX — Ce qu'est réellement le Voile
Les données antiques, modernes, étrangères, humaines et non humaines convergent vers une compréhension partielle : le Voile agit sur la cohérence de la réalité partagée, sans que son origine ultime soit connue.

### X — La lumière mérite d'être défendue
Le choix final est collectif. Les orientations proposées dépendent de ce que le joueur a réellement rendu possible pendant la campagne.

## Orientations finales

Six grandes orientations peuvent être disponibles :

- La Grande Fermeture nouvelle ;
- La Concorde des deux rives ;
- Les Portes gardées ;
- Ramener les Absents ;
- La Concorde restaurée ;
- La Quatrième Veille.

Aucune n'est intrinsèquement parfaite. Chacune possède des conditions, des coûts, une forme responsable et une dérive possible.

Une partie qui n'a pas construit les conditions nécessaires peut aboutir à une survie fragmentée ou à d'autres états de monde moins favorables. Il ne s'agit pas de punir un alignement moral mais de faire suivre aux décisions leurs conséquences.

## Variables transversales

Les fins et certains embranchements utilisent notamment :

- confiance, tension et réputation ;
- Corps, Esprit et Cité ;
- qualité des relations avec les créatures ;
- contact avec les Absents ;
- alliances étrangères ;
- intégrité de la justice ;
- connaissance du Voile ;
- nombre de nœuds de stabilisation sécurisés.

## Journal

Le journal affiche le chapitre actuel, les quêtes principales actives, les révélations confirmées, les décisions locales et l'état du Sanctuaire. Le HUD de jeu reste contextuel et n'est pas utilisé comme support permanent de progression narrative.

## Données et runtime

- `data/world/main_campaign.json` : chapitres, quêtes, boss, personnages et révélations.
- `data/world/main_campaign_endings.json` : orientations finales et conditions.
- `scripts/core/campaign_state.gd` : progression persistante, métriques et déblocage des fins.
