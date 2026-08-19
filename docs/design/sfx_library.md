# Bibliothèque de bruitages — Light in the Dark

## Intention

Le sound design doit soutenir la lisibilité tactique, la narration et l'identité du monde. Un bruitage ne doit pas seulement "faire réaliste" : il doit indiquer une matière, une distance, une menace, une action ou un état psychologique sans écraser le dialogue ni la musique.

Cette passe crée un catalogue de production et un contrat de sélection. Elle **n'importe aucun binaire audio**. Un fichier n'est considéré comme intégré qu'après vérification de sa licence, archivage de la preuve, calcul du hash, préparation technique et test dans Godot.

## Sources retenues

### Sonniss GameAudioGDC
Archive de bruitages offerte pour le jeu vidéo avec usage commercial royalty-free et sans attribution obligatoire selon la page officielle de l'archive. Source privilégiée pour foley, impacts, armes, environnements, créatures et matières. Chaque fichier sélectionné doit conserver son année, sa bibliothèque et son fournisseur d'origine.

### Freesound
Freesound mélange plusieurs licences. Seuls les fichiers **CC0** entrent directement en vert. Les fichiers **CC BY** restent ambre parce qu'ils imposent l'attribution. Les fichiers **CC BY-NC** sont interdits pour une sortie commerciale. L'URL exacte, l'uploader, l'ID du son et la version de licence doivent être conservés.

### Pixabay Sound Effects
Compatible comme source de candidats, mais classée ambre : la Content License permet usage et adaptation sous conditions, interdit notamment la redistribution standalone et rappelle que des droits tiers peuvent exister. Chaque asset exact doit donc être re-vérifié et sa preuve archivée.

### OpenGameArt
Aucune licence globale n'est supposée. Nous retenons uniquement les pages d'assets explicitement **CC0**. La bibliothèque référence déjà des pas, impacts d'armes médiévales et bruitages variés comme premiers pools vérifiés.

### itch.io CC0
Uniquement des packs dont la page indique explicitement CC0 et usage commercial. Les premiers pools documentés incluent Basic Spell Impacts, plusieurs volumes HZSMITH, Nox Essentials et Mix of SFX.

## Couverture sonore

La taxonomie couvre actuellement 12 domaines et plus de 80 familles :

- surfaces et pas : cendre, pierre, bois, boue, eau, métal ;
- foley de personnages : tissus, cuir, sangles, armures légères et lourdes ;
- combat : dégainé, lames, contondant, perforation, parade, bouclier, armure, critique, démembrement, fractures, whooshes et télégraphes ;
- magie et ultimes ;
- familles de créatures et présence de boss ;
- Peur, Panique, Espoir et mémoire ;
- vents, tempêtes de cendre, feux, pluie, tonnerre et grottes ;
- portes, chaînes, gravats et structures ;
- Sanctuaire, Taverne, Forge, Chapelle et Mémorial ;
- interactions de terrain, campement, pièges et ressources ;
- UI : journal, carte, inventaire, compétences, quêtes, capture ;
- silence narratif volontaire.

## Règles de direction

Les télégraphes de combat passent avant le spectacle. Un boss peut secouer toute l'arène, mais jamais au prix de masquer une attaque lisible. Les pas doivent dépendre de la surface et du poids du personnage ; l'armure est une couche indépendante. Un même bruitage très fréquent ne doit pas être répété mécaniquement : plusieurs variantes et une micro-variation contrôlée sont nécessaires.

Les boss, ultimes et grandes créatures devront posséder une **signature sonore originale LITD**. Les sons stock servent de matière première, pas d'identité finale reconnaissable.

La Peur est subjective : cœur, respiration, acouphène ou compression perceptive peuvent apparaître selon le héros concerné, mais sans recouvrir tout le jeu. L'Espoir ne doit pas être un jingle positif ; il doit créer momentanément plus d'espace, d'air et de clarté.

Le démembrement reste brutal mais sérieux. On évite le gore sonore exagéré qui transformerait une mécanique tactique sombre en effet comique.

## Voix et êtres vivants

Une licence permissive ne suffit pas toujours pour une voix humaine. Tout cri, effort, respiration ou murmure identifiable doit aussi avoir une provenance appropriée. Les dialogues, murmures narratifs et mots intelligibles ne proviennent jamais d'une banque de sons stock : ils doivent être originaux, enregistrés pour LITD ou contractuellement autorisés.

Les créatures conscientes ne doivent pas sonner systématiquement comme des animaux. Leur design acoustique doit préserver une impression d'intelligence ou d'intention.

## Spatialisation

Le monde, les pas, créatures, portes, impacts, forge et environnements utilisent normalement de l'audio 3D. Les signaux purement UI et certains effets subjectifs utilisent du 2D. Les couches subjectives ne doivent pas remplacer la source réelle : une parade conserve son impact spatial même si un feedback 2D très discret renforce la lisibilité.

## Priorité du mix

Ordre de priorité : dialogue critique → télégraphe de combat → action joueur → action ennemie → interaction → UI → voix de créatures → foley → ambience → musique.

Le but n'est pas d'avoir tout fort en permanence. Le silence et l'espace dynamique font partie du design.

## Ingestion d'un fichier

Pour chaque fichier retenu :

1. ouvrir la page exacte le jour du téléchargement ;
2. vérifier l'usage commercial jeu vidéo ;
3. archiver URL, auteur, licence/version, date et preuve ;
4. conserver le nom de fichier et le pack d'origine ;
5. calculer le SHA-256 ;
6. vérifier la provenance des voix humaines ;
7. préparer les variantes, boucles et niveaux sans détruire le master ;
8. tester dans Godot contre musique, dialogues et télégraphes ;
9. tester sur haut-parleur iPhone et casque ;
10. renseigner `local_path` seulement quand le binaire vérifié existe réellement.

## Convention de nommage

`sfx_<domain>_<family>_<material_or_actor>_<variant>.<ext>`

Exemples :

- `sfx_move_footstep_ash_01.ogg`
- `sfx_combat_parry_steel_03.ogg`
- `sfx_creature_ghoul_breath_02.ogg`
- `sfx_ui_journal_page_01.ogg`

## Licences refusées

CC BY-NC, licence inconnue, editorial-only, contenu reconnaissable provenant d'une franchise protégée et voix humaines non vérifiées sont refusés. Le terme « royalty-free » seul n'est jamais une preuve suffisante.
