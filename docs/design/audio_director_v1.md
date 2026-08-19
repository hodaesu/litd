# AudioDirector v1 — exploration, combat, Peur et boss

## Objectif

Cette passe transforme les bibliothèques `MusicLibrary` et `SfxLibrary` en un premier système audio réactif. Le directeur ne prétend pas que les fichiers audio sont déjà présents : il sélectionne des cues, applique un mix réel via `AudioServer`, et joue automatiquement une piste uniquement lorsqu'un `local_path` vérifié existe réellement.

## Architecture

Flux principal :

`événement de jeu -> AudioDirector -> état audio -> MusicLibrary/SfxLibrary -> bus Godot -> lecture si asset local vérifié`

L'AudioDirector est un autoload persistant. Il observe les signaux déjà existants des Terres de Cendre, du pont de combat et de la psychologie, puis reconstruit un état audio qualitatif.

### Bus runtime

Huit bus sont créés si nécessaire : `Music`, `Ambience`, `Foley`, `Combat`, `Creatures`, `Psychology`, `Dialogue`, `UI`.

Ils sont envoyés vers `Master`. La v1 pilote réellement leur niveau en dB avec des presets distincts pour exploration, combat et boss. `Dialogue` et `UI` sont déjà isolés afin que les prochaines passes puissent ajouter ducking, scènes narratives et priorités plus fines sans casser le mix existant.

## Exploration

Une entrée ou transition de zone sélectionne une famille musicale. Les identifiants contenant archive, ruine, relais, complexe ou vestige privilégient `exploration_ruins`. Les lieux indiquant ravage, seuil, brèche ou champ de bataille privilégient `exploration_threat`. Le reste utilise `exploration_ashlands`.

L'ambiance de base des Terres de Cendre expose `wind_ashlands`. Ce cue est un plan de sound design tant qu'aucun asset exact n'a été ingéré et vérifié.

## Combat

`AshlandsCombatBridge.ashlands_combat_started` est directement relié au directeur :

- rencontre normale -> `combat_normal` ;
- mini-boss -> `combat_elite` ;
- boss -> `combat_boss` + `boss_presence`.

Le mix place alors `Combat` et `Creatures` au premier plan et réduit l'ambiance. La priorité reste la lisibilité tactique, conformément aux bibliothèques musicales/SFX.

À la fin d'un combat, le directeur demande `victory_costly` ou `defeat_retreat`. La prochaine entrée/transition de zone reprend ensuite une musique d'exploration appropriée.

## Boss

La v1 ne dépend pas d'un seul script de boss. Tant qu'un combat est classé `boss`, le directeur inspecte `GameState.battle_enemies` et lit `chapter_phase`. Une hausse de phase déclenche `boss_phase_change`.

Le Témoin des Cendres fonctionne donc immédiatement avec son runtime existant, et les autres boss peuvent utiliser le même contrat dès qu'ils renseignent leur phase dans les données de combat.

## Peur

La Peur est traitée comme une couche subjective indépendante, calculée à partir du héros vivant ayant la Peur la plus élevée :

- 0–24 : calme, couche psychologique silencieuse ;
- 25–49 : souffle léger ;
- 50–74 : souffle + battement ;
- 75–99 : souffle + battement + acouphène bref, musique davantage reculée ;
- 100 : profil Panique avec `panic_sting`, musique fortement reculée mais informations de combat préservées.

L'objectif n'est pas d'ajouter du bruit. Plus la Peur augmente, plus le mix devient subjectif tout en laissant les télégraphes et actions importantes lisibles.

## Sélection de ressources

La musique est sélectionnée dans les candidats verts de `MusicLibrary`. Si le candidat contient un `local_path` `res://` réellement existant et chargé comme `AudioStream`, l'AudioDirector peut le jouer immédiatement sur le bus `Music`.

Pour les SFX, la bibliothèque actuelle référence surtout des packs et familles plutôt que des fichiers exacts. Le directeur émet donc `cue_requested` avec les packs compatibles, la spatialisation attendue et le contexte dramatique. Une future couche d'ingestion pourra convertir ce contrat en lectures 2D/3D réelles sans modifier le gameplay.

## État observable

`snapshot()` expose : mode, zone, rencontre, phase de boss, profil de Peur, cue musical, candidat musical sélectionné, SFX actifs et niveaux des bus. Un historique borné conserve les transitions significatives pour les tests et le débogage.

## Limites volontaires de la v1

Cette première version ne fait pas encore : crossfade par stems, dialogue ducking automatisé, ambiance du Sanctuaire, météo/heure, sons de relations, mémoire sonore de quête, spatialisation concrète des SFX par émetteurs 3D, ni orchestration de scènes narratives complexes.

Ces éléments viennent ensuite. La priorité de cette passe est d'avoir un noyau déterministe, testable et branché sur de vrais événements existants.
