# LITD : Les Veilleurs — Reset puis réattribution canonique du quatuor de départ

Date : 2026-09-09
Statut : **RESET TERMINÉ — NOUVEAU QUATUOR CANONIQUE ATTRIBUÉ**

## Nouveau quatuor de départ

1. **Mathilde** — `mathilde` — Duelliste
2. **Marec** — `marec` — Briseur
3. **Anouk** — `anouk` — Mystique
4. **Aurélien** — `aurelien` — Chirurgien

Les quatre sont déjà membres des **Sept Héros légendaires**. Leurs fiches techniques, planches, silhouettes, armes, palettes, histoires et documents de production existants restent les références. **Aucun redesign n'est demandé par cette migration.**

## Compositions historiques invalidées

Ces compositions ne sont plus le roster de départ :

1. Nayra Orun / Tarek Senn / Aïsha Maren / Idris Vael
2. Sahen Varo / Mira Sen / Narem Osh / Ysra Nahal
3. Aurélien / Malvor / Lysandra / Darius

L'invalidation porte sur les **compositions historiques**, pas nécessairement sur l'existence de chaque personnage dans LITD Universe. En particulier, Aurélien est explicitement réattribué au nouveau quatuor.

## Règle Aurélien supersédée

L'ancienne règle selon laquelle Aurélien, parce qu'il était déjà un Héros légendaire, ne devait jamais rejoindre le quatuor de `LITD : Les Veilleurs`, est **supersédée par la décision canonique du 2026-09-09**.

Nouvelle règle :

> Aurélien fait partie du quatuor de départ de `LITD : Les Veilleurs` avec Mathilde, Marec et Anouk.

Toute bible ou documentation antérieure contenant l'ancienne interdiction doit être considérée comme historique jusqu'à sa prochaine régénération.

## Ce qui n'est pas hérité des anciens quatuors

Le nouveau quatuor ne reprend aucun nom, visage, silhouette, origine, classe, rôle tactique, équipement, compétence, personnalité, relation ou histoire personnelle de Sahen/Mira/Narem/Ysra ni des autres anciennes compositions.

Les quatre nouveaux membres réutilisent **leurs propres éléments déjà établis comme Héros légendaires**.

## Références techniques actives

Le roster machine est défini dans :

- `data/heroes.json`
- `data/veilleurs/canonical_roster.json`

Ordre canonique de démarrage :

`Mathilde → Marec → Anouk → Aurélien`

Mapping gameplay actuel :

- Mathilde → `duelist`
- Marec → `breaker`
- Anouk → `mystic`
- Aurélien → `surgeon`

Les valeurs de PV et les états psychologiques placés dans `data/heroes.json` servent de baseline runtime de départ ; ils ne remplacent pas les fiches d'identité ou de progression déjà produites.

## Contraintes du monde conservées

- LITD reste cosmopolite ;
- forte base culturelle et visuelle asiatique, principalement chinoise ;
- diversité ethnique humaine réelle ;
- monde post-guerre sombre et fragile ;
- aucune occidentalisation ou uniformisation du casting par cette migration.

## Règle de production

À partir de cette décision :

- les planches existantes de Mathilde, Marec, Anouk et Aurélien sont les références de production ;
- les jobs Blender et références Godot doivent utiliser leurs IDs canoniques ;
- les tests ne doivent plus dépendre des shells `malvor`, `lysandra`, `darius` ni des identités Sahen/Mira/Narem/Ysra ;
- toute réapparition d'un ancien quatuor comme roster de départ est une régression ;
- aucune nouvelle planche de ces quatre héros n'est requise uniquement pour effectuer la migration technique.
