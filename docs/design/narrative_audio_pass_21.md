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

## Validation

La passe ajoute un audit Python et un smoke Godot `NARRATIVE_AUDIO_SMOKE_OK` couvrant :

- contexte sonore du Sanctuaire ;
- boucle de Taverne ;
- Chapelle et Mémorial ;
- ducking et restauration du dialogue ;
- silence scénarisé ;
- motifs des quêtes ;
- beat de choix sans morale numérique ;
- révélation avec silence puis transition musicale.
