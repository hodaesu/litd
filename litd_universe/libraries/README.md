# LITD Universe — Bibliothèques communes

Ce dossier est la base de connaissance, de référence et d’assets partagés de toute la licence LITD. Tout jeu LITD actuel ou futur doit consulter ces bibliothèques au lieu de créer une base isolée.

## Principe fondamental

Les références extérieures sont des **sources d’inspiration uniquement**. Elles ne doivent jamais être copiées, reproduites servilement, décalquées, remodélisées à l’identique ou utilisées comme assets de production sans droits explicites.

La réutilisation directe entre jeux est réservée aux assets :
- créés et détenus par LITD, avec statut `LITD_ORIGINAL_REUSABLE` ;
- ou tiers dont la licence autorise explicitement l’usage prévu, avec statut `LICENSED_REUSABLE`.

Tout droit inconnu, ambigu ou non documenté entraîne automatiquement `REFERENCE_ONLY`.

## Bibliothèques

1. `artistic_references` — œuvres et références artistiques
2. `cultures_architecture` — cultures et architectures
3. `sculptures` — sculptures
4. `paintings` — peintures
5. `mosaics_drawings` — mosaïques et dessins
6. `materials_textures` — matériaux et textures
7. `environments` — environnements
8. `vegetation` — végétation
9. `creatures` — créatures
10. `anatomy` — anatomie
11. `clothing_armor` — vêtements et armures
12. `weapons_objects` — armes et objets
13. `sound_music` — sons et musiques de référence
14. `animation_movement` — animations et mouvements
15. `visual_effects` — effets visuels
16. `shared_lore` — lore commun
17. `symbols` — symboles
18. `philosophies` — philosophies
19. `technologies` — technologies

## Couverture mondiale

Les bibliothèques culturelles et artistiques doivent rechercher des références sur tous les continents, toutes les grandes périodes historiques et une pluralité de traditions. Aucune région n’est la norme par défaut. Les références sacrées, funéraires, rituelles ou culturellement sensibles doivent être signalées et traitées avec contexte et respect.

## Schéma minimal d’une entrée

```yaml
id:
library:
name:
creator_or_culture:
region:
period:
medium_or_type:
source:
rights_status:
usage_class: REFERENCE_ONLY
inspiration_axes: []
must_not_copy: []
transformation_notes:
relevant_games: []
```

Pour un asset réutilisable :

```yaml
asset_origin:
owner:
license:
reuse_scope:
attribution_required:
source_file:
```

## Règle de production

Une référence peut inspirer des principes : rythme, silhouette, fonction, matière, lumière, composition abstraite, mécanique, contexte historique ou symbolique. Le résultat LITD doit être une création originale issue d’une transformation et d’une synthèse, idéalement de plusieurs influences indépendantes.
