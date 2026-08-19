# Pass 21 — Audio narratif, dialogues et Sanctuaire

## Intention

Cette passe relie les bibliothèques musicales et de bruitages à la narration déjà présente dans Light in the Dark. Le but n'est pas d'ajouter du son partout, mais de décider ce qui mérite d'être entendu pendant une conversation, une révélation, un choix ou un retour au Sanctuaire.

Le système repose sur `NarrativeAudioDirector`, au-dessus de `AudioDirector`, `MusicLibrary`, `SfxLibrary`, `PrototypeAudioBank` et `SfxRuntime`.

## Dialogue ducking

`begin_dialogue()` et `end_dialogue()` appliquent une couche de mixage temporaire sans détruire le mix de base d'`AudioDirector`.

- la musique recule nettement ;
- l'ambiance et le foley reculent modérément ;
- le bus Dialogue reste au premier plan ;
- Combat et Creatures ne sont que légèrement réduits pour que les télégraphes restent lisibles si une réplique survient pendant une situation tendue ;
- la restauration utilise le mix courant d'`AudioDirector`, donc la Peur ou un changement de contexte peuvent continuer d'exister sous la conversation.

La Taverne utilise déjà ce mécanisme lorsqu'une rumeur est réellement racontée.

## Sanctuaire sonore

Les principaux écrans du Sanctuaire ont maintenant un contexte audio propre.

| Espace | Musique | Boucle d'ambiance |
|---|---|---|
| Sanctuaire / communauté / compagnie / marché / infirmerie / préparation d'expédition | `sanctuary_day` | `sanctuary_crowd` |
| Taverne | `tavern` | `tavern_roomtone` |
| Chapelle | `chapel` | `chapel_roomtone` |
| Mémorial | `memorial` | `memorial_roomtone` |
| Créatures | `creature_empathy` | `sanctuary_crowd` |

L'entrée principale du Sanctuaire peut produire `bell_sanctuary`. Les prototypes sont volontairement sobres et remplaçables par les masters finaux sans changer les cue IDs.

## Silence scénarisé

`scripted_silence()` rend le silence explicite et testable. Par défaut il retire Music et Ambience pendant une durée bornée, puis restaure progressivement les niveaux calculés par `AudioDirector`.

Le silence peut précéder :

- une révélation ;
- une perte ;
- un choix lourd ;
- une scène du Mémorial ;
- une phrase qui doit tomber sans accompagnement.

Il ne coupe pas automatiquement Combat ni les télégraphes tactiques.

## Beats narratifs

`trigger_beat()` propose un vocabulaire simple pour la mise en scène audio :

- `rumor` : court ducking de dialogue + `memory_echo` discret ;
- `revelation` : silence, puis `discovery_revelation` ;
- `choice` : bref poids sonore neutre, sans signaler de bonne réponse morale ;
- `loss` : silence puis `sadness_loss` ;
- `reunion` : `emotional_reunion` ;
- `relationship` : ponctuation très discrète d'une scène entre compagnons, sans désigner de gagnant ;
- `quest_accept` : petit signal de mise à jour + motif propre à la quête ;
- `quest_complete` : silence court, résolution discrète + retour du motif.

Les appels sont volontairement data-driven via `data/narrative_audio.json`.

## Mémoire musicale des quêtes

Les quêtes émergentes existantes reçoivent un motif stable :

- `q_iven_erased_days` → `ancient_archive` ;
- `q_yoren_false_exit` → `discovery_revelation`.

Le motif peut donc revenir lorsque l'histoire est acceptée, recontextualisée ou accomplie. Il ne sert pas de jingle de récompense ; il sert de mémoire.

## Prototypes locaux

`PrototypeAudioBank` est étendu avec :

- `sanctuary_crowd` ;
- `tavern_roomtone` ;
- `chapel_roomtone` ;
- `memorial_roomtone` ;
- `bell_sanctuary` ;
- `memory_echo` ;
- les premiers lits `sanctuary_day`, `tavern`, `chapel`, `memorial`, `ancient_archive` et `discovery_revelation`.

Ces sons sont générés localement et ne contiennent aucun matériau tiers. Ils existent pour valider la mise en scène, le routage, les transitions et le mixage. Ils ne constituent pas l'identité sonore finale du jeu.

## Règles de narration sonore

1. Le dialogue doit rester intelligible sans rendre le monde muet.
2. Le silence est un choix de mise en scène, pas un défaut de contenu.
3. Une révélation n'a pas besoin d'un énorme sting ; elle peut commencer par le retrait du son.
4. Un choix peut sembler lourd sans que la musique désigne une option comme bonne ou mauvaise.
5. Un motif de quête doit rappeler une histoire, pas seulement une récompense.
6. Les espaces du Sanctuaire doivent être reconnaissables à l'oreille tout en laissant de la place aux conversations.
7. Les télégraphes tactiques restent prioritaires sur le spectacle narratif.
8. Les prototypes procéduraux sont remplaçables sans changer l'API ni les cue IDs.
9. Un hook sonore ne doit être branché que sur une scène réellement présente dans le runtime jouable ; les futurs types de scènes restent sans liaison tant que leur gameplay n'existe pas.

## Pass 22 — Connexion aux scènes réelles

Le pass 22 ne crée pas une nouvelle couche de narration abstraite. Il relie les beats précédents aux événements qui existent déjà réellement dans le jeu grâce à `scene_hooks` et à `NarrativeAudioDirector.trigger_scene_hook()`.

### Enquête et révélation

Deux preuves réelles du Chapitre III sont maintenant reliées aux histoires émergentes du Sanctuaire :

- `ev_korem_redaction` déclenche la révélation de **Les jours qu'on a effacés** et rappelle le motif `ancient_archive` d'Iven ;
- `ev_purge_protocol` déclenche la révélation de **La route qui n'était pas une sortie** et rappelle le motif `discovery_revelation` de Yoren.

Le signal `Chapter03Runtime.evidence_discovered` est utilisé directement. La musique n'est donc pas déclenchée parce qu'un texte d'interface est affiché, mais parce que la preuve a réellement été collectée par le runtime.

### Compagnons

`RelationshipRuntime.relationship_changed` pilote désormais les scènes de relation déjà jouables au Sanctuaire :

- `sanctuary_reconcile` : deux compagnons mettent des mots sur leur conflit ;
- `sanctuary_opening` : deux compagnons restent à parler après le départ des autres.

Ces scènes utilisent le beat `relationship`, volontairement sans résolution triomphante ni gagnant musical. Le dialogue est légèrement mis au premier plan, puis le mix revient à l'ambiance du lieu.

La chute réelle d'un héros, déjà produite par `RelationshipRuntime.on_hero_fallen()`, émet un `relationship_moment`. Quand ce moment commence par la chute du compagnon, le directeur audio déclenche `loss` : silence, puis espace sonore de deuil. Il n'ajoute aucune jauge de relation ou de moralité.

### Retours et retrouvailles

Le retour réel de Mara, Yoren et Iven par `c03_survivor_outpost:returned` déclenche désormais `reunion`. Il s'agit ici d'une vraie retrouvaille de survivants déjà présente dans `FieldEncounterRuntime`, pas d'une scène de famille inventée pour satisfaire le système audio.

Les futures familles séparées pourront utiliser le même contrat lorsqu'elles existeront réellement dans le gameplay : `field:<event_id>:<outcome>` ou un hook plus spécifique. Tant que ces rencontres n'existent pas, aucun faux événement de famille n'est créé.

### Décision politique

Les décisions de la Concorde sont reliées au son à l'endroit exact où le joueur valide un choix dans `PoliticalUI._take_decision()`.

Le hook `political:*` produit le beat `choice` avec la règle `neutral_weight_no_moral_answer`. Le son souligne donc le poids politique d'une décision sans suggérer qu'accueillir, refuser, punir, libérer ou négocier serait la réponse moralement correcte.

### Contrat data-driven

Les hooks sont définis dans `data/narrative_audio.json` sous la forme :

`type:identifiant[:résultat] → beat + motif éventuel + durée de parole + règle de mise en scène`.

Le runtime possède une résolution exacte puis un wildcard par famille, ce qui permet par exemple à toutes les décisions politiques existantes de partager une grammaire sonore neutre sans recopier une entrée par choix.

## Validation

L'audit Python vérifie maintenant que les hooks pointent vers de vraies données du jeu : preuves du Chapitre III, rencontres de terrain, événements de relation et quêtes politiques. Le smoke Godot `NARRATIVE_AUDIO_SMOKE_OK` couvre en plus les signaux réels de preuve, relation, chute d'un héros, retour des Trois Marques et décision politique.

La validation couvre donc :

- contexte sonore du Sanctuaire ;
- boucle de Taverne ;
- Chapelle et Mémorial ;
- ducking et restauration du dialogue ;
- silence scénarisé ;
- motifs des quêtes ;
- beat de choix sans morale numérique ;
- révélation avec silence puis transition musicale ;
- scènes réelles d'enquête ;
- scènes entre compagnons ;
- perte d'un héros ;
- retrouvailles de survivants ;
- décision politique réellement validée par le joueur.
