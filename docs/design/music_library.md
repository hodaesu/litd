# Bibliothèque musicale — Light in the Dark

## Objectif

La musique doit accompagner la narration, l'exploration et le combat sans décider à la place du joueur de ce qu'il doit ressentir ou juger. Cette bibliothèque sert de catalogue de production : elle associe des morceaux candidats à des usages dramatiques, garde leur statut juridique visible et prépare l'arrivée ultérieure de compositions originales propres à Light in the Dark.

Le dépôt ne prétend pas contenir les fichiers audio tant qu'ils n'ont pas été réellement téléchargés, vérifiés, archivés puis importés. `data/music_library.json` garde donc `local_path` vide pour tous les morceaux de cette première passe.

## Principe de licence

« Libre de droits » n'est pas traité comme une licence unique. Chaque morceau possède sa source, sa licence, son statut Content ID et un niveau de risque :

- **vert** : candidat dont la page et la licence ont été vérifiées et qui n'affichait pas de badge Content ID lors de la revue ; il doit tout de même être recontrôlé le jour du téléchargement ;
- **ambre** : utilisation potentiellement possible mais demandant une étape supplémentaire — Content ID, attribution, vérification de plateforme ou vérification morceau par morceau ;
- **rouge** : ne doit pas entrer dans une build expédiée.

Même pour un morceau vert, on archive la page source, la licence et la preuve disponible au moment du téléchargement. Cela permet de retrouver l'état exact dans lequel le morceau a été acquis.

### Pixabay

Pixabay constitue actuellement la majorité du premier vivier. Les morceaux restent incorporés au jeu ; ils ne doivent pas être redistribués comme fichiers musicaux autonomes. Les morceaux signalés `Content ID Registered` restent en ambre même lorsque la licence générale permet l'utilisation : ils doivent être testés et leur preuve de licence doit être conservée.

### CC0

Une version réellement publiée sous CC0 est la classe préférée lorsque sa qualité musicale correspond au besoin. Il faut vérifier la licence de **l'enregistrement**, pas seulement l'ancienneté de la composition.

### CC BY / Incompetech

Les morceaux CC BY peuvent être très utiles pour les prototypes et la recherche musicale, mais ils exigent une attribution complète. La distribution mobile et ses éventuelles restrictions techniques doivent être examinées avant de classer ces morceaux comme définitifs. `MusicLibrary.credits_lines()` prépare déjà les lignes nécessaires pour les candidats qui exigent une attribution.

### Musopen

Musopen est utilisé comme source de recherche pour le répertoire classique. Une composition ancienne et un enregistrement récent ne sont pas la même chose juridiquement : chaque enregistrement doit donc être contrôlé avant ingestion.

### Mixkit : interdit dans cette bibliothèque

La bibliothèque musicale Mixkit indique actuellement que sa musique ne peut pas être utilisée dans les **jeux vidéo**. Elle est donc explicitement classée rouge et exclue de Light in the Dark malgré le vocabulaire « royalty free » du site. Aucun morceau Mixkit ne doit entrer dans le jeu sans changement de licence ou accord direct séparé.

## Familles musicales

Le catalogue ne classe pas seulement les morceaux par genre. Il les classe par **fonction dramatique**. Les familles couvrent notamment :

- exploration des Terres de Cendre, ruines et zones sous menace ;
- combat courant, élite, boss, entrée et changement de phase ;
- perte, Mémorial, retraite, victoire coûteuse ;
- retrouvailles, Espoir, scènes avec créatures conscientes ;
- Sanctuaire de jour et de nuit, Taverne et Chapelle ;
- tension politique, archives anciennes et révélation ;
- Peur/Panique et traces de Folie ;
- transitions de chapitres, choix final et générique.

Une scène peut changer de famille sans changer de lieu. Une exploration de ruine calme peut glisser vers `exploration_threat`, puis vers `combat_normal`, alors que le timbre et certains motifs restent liés à la zone.

## Première sélection

La première passe contient des candidats pour chaque grande fonction : ambient sombre pour les souterrains, pièces orchestrales de tension pour les combats, piano et cordes pour les pertes, musique plus chaude pour le Sanctuaire et quelques morceaux médiévaux pour la Taverne. Les morceaux Content ID sont conservés dans le catalogue mais séparés du groupe vert.

Les candidats issus de Pixabay comprennent notamment **Caves of Dawn**, **Sacred Garden**, **Rest of The Fallen**, **Near Danger**, plusieurs thèmes de combat orchestraux, des pistes de piano triste et des boucles médiévales. Les candidats Incompetech restent en ambre car ils utilisent CC BY 4.0 et demandent attribution et revue de distribution.

Un morceau dont les tags ou la présentation reposent trop fortement sur des franchises reconnaissables peut être refusé même si sa licence semble utilisable. La cohérence juridique ne suffit pas : Light in the Dark doit garder sa propre identité.

## Règles de mise en scène musicale

La musique est une couche de mise en scène, pas un commentaire permanent.

1. **Exploration** — conserver de l'espace sonore. Le joueur doit entendre le lieu et pouvoir sentir une menace arriver avant que la musique ne devienne une marche de combat.
2. **Combat** — le rythme doit aider la tension, jamais masquer les télégraphes, impacts, confirmations d'interface ou réactions vocales importantes.
3. **Boss** — utiliser une structure reconnaissable : attente, apparition, engagement, changement de phase, résolution. Une phase mécanique majeure mérite une transformation musicale perceptible.
4. **Peur** — réduire l'espace mental, dérégler ou raréfier les éléments plutôt que simplement augmenter le volume.
5. **Espoir** — créer une ouverture temporaire. L'Espoir de LITD n'est pas une jauge et sa musique ne doit pas devenir un hymne triomphal permanent.
6. **Tristesse** — laisser exister le silence. Une scène de mort ou de Mémorial peut être plus forte si la musique entre après la première réplique ou disparaît avant la dernière.
7. **Politique** — éviter le raccourci « majeur = bon / mineur = mauvais ». La partition doit porter l'incertitude et les intérêts en conflit sans désigner le bon choix.
8. **Créatures conscientes** — conserver l'étrangeté. Une rencontre empathique ne transforme pas automatiquement la créature en figure innocente ou sacrée.
9. **Sanctuaire** — donner du repos tout en conservant une légère mémoire du monde extérieur. Le refuge n'est jamais une bulle totalement déconnectée.
10. **Finale** — avant le choix final, la musique ne doit pas annoncer quelle option serait moralement correcte.

## Dialogue et musique

La nouvelle bibliothèque de dialogues et la bibliothèque musicale doivent fonctionner ensemble. Quand une scène contient une information essentielle, la musique baisse. Deux valeurs de départ sont enregistrées dans les données : réduction standard pour un dialogue et réduction plus forte pour une ligne critique. Ces valeurs devront être réglées sur appareil réel, pas considérées comme des constantes artistiques définitives.

Les silences d'un dialogue font également partie de la musique : on ne remplit pas automatiquement chaque pause avec une montée orchestrale.

## Combat et lisibilité

Les télégraphes de combat et les sons de validation UI sont prioritaires sur la musique. Une belle partition qui masque un changement de rang, un démembrement, un cri de Panique ou l'entrée dans une phase de boss est une mauvaise intégration.

Pour les pistes bouclables, la présence du mot « loop » sur une page source ne suffit pas : le point de boucle doit être contrôlé à l'échantillon, puis testé dans Godot et sur iPhone pour éviter clics, blanc ou rupture de tempo.

## Pipeline d'ingestion

Avant d'ajouter un MP3/OGG dans `assets/music/` :

1. rouvrir la page exacte du morceau ;
2. vérifier à nouveau la licence et les éventuelles restrictions ajoutées par le créateur ;
3. noter le statut Content ID ;
4. conserver page/licence/certificat ou capture équivalente dans l'archive de production ;
5. télécharger le master autorisé ;
6. calculer son SHA-256 ;
7. créer ensuite la version OGG destinée à Godot ;
8. régler manuellement les boucles ;
9. tester masquage du dialogue, télégraphes et niveau de crête ;
10. seulement ensuite renseigner `local_path` dans le catalogue.

Le catalogue empêche donc de confondre **« nous avons identifié un morceau »** avec **« cet asset est réellement intégré et juridiquement archivé »**.

## Vers une identité musicale propre à Light in the Dark

Les musiques stock constituent un très bon moyen de prototyper le rythme des scènes et de trouver ce qui fonctionne. Elles ne doivent cependant pas devenir par défaut toute l'**identité musicale** de Light in the Dark.

À mesure que les chapitres se stabilisent, les meilleurs usages du catalogue doivent être transformés en briefs de composition originaux : motifs de la Chute, du Sanctuaire, du Voile, des Trois Éveils, des créatures conscientes, de la Peur et des grandes civilisations. Les thèmes pourront alors revenir sous des formes différentes entre exploration, combat, Mémorial et fin de campagne.

Le but final est qu'un joueur puisse reconnaître Light in the Dark en quelques mesures, même sans voir l'écran.
