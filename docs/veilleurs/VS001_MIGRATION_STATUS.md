# VS001 — état de migration et frontière de compatibilité

## Statut

VS001 n'est plus une entrée joueur de LITD : Les Veilleurs. La surface canonique est le flux v0.9, avec `scripts/world/veilleurs_playable_bridge.gd` et `scenes/veilleurs/vertical_slice.tscn`.

VS001 reste temporairement une couche de compatibilité pour les anciennes sauvegardes et l'ancien monde nécessaire à leur reprise. Aucune nouvelle fonctionnalité ne doit être développée sur VS001.

## Inventaire vérifié

L'audit de septembre 2026 a trouvé neuf scripts `scripts/world/veilleurs_vs001_*.gd`.

Le premier passage statique avait identifié `scripts/world/veilleurs_vs001_room_sensor.gd` comme candidat orphelin. La CI globale a ensuite détecté la référence active que la recherche de code n'avait pas remontée : `scripts/world/veilleurs_vs001_playable_world.gd` précharge ce script, l'instancie pour chaque salle et connecte son signal `party_entered`. Le fichier a donc été restauré et classé comme dépendance legacy requise.

Conclusion de l'inventaire actuel : **aucun des neuf scripts VS001 du runtime monde n'est prouvablement orphelin**. Ils restent volontairement présents jusqu'à la validation PC de migration des anciennes sauvegardes :

- `veilleurs_vs001_blockout_builder.gd` — construction de la scène legacy ;
- `veilleurs_vs001_corpse_proxy.gd` — proxy utilisé par le monde legacy ;
- `veilleurs_vs001_interaction_proxy.gd` — proxy utilisé par le monde legacy ;
- `veilleurs_vs001_persistence_bridge.gd` — migration/reprise des anciennes sauvegardes ;
- `veilleurs_vs001_persistence_layer.gd` — persistance du monde legacy ;
- `veilleurs_vs001_playable_bridge.gd` — entrée de compatibilité pour une ancienne sauvegarde ;
- `veilleurs_vs001_playable_world.gd` — monde legacy chargé pendant la compatibilité ;
- `veilleurs_vs001_room_sensor.gd` — détection des salles instanciée par le playable world legacy ;
- `veilleurs_vs001_world_runtime.gd` — runtime legacy encore requis par cette reprise.

Les deux scènes de compatibilité restent :

- `scenes/world/veilleurs/voices_under_sanctuary_playable.tscn` ;
- `scenes/world/veilleurs/voices_under_sanctuary_blockout.tscn`.

Les deux autoloads restent également en place tant que le test PC n'est pas validé :

- `VeilleursVS001WorldRuntime` ;
- `VeilleursVS001PlayableBridge`.

## Garde-fou automatique

`data/veilleurs/vs001_legacy_contract.json` décrit explicitement toute la surface VS001 encore autorisée.

`tools/qa/veilleurs_vs001_legacy_audit.py` échoue si :

- un nouveau script runtime `veilleurs_vs001_*.gd` apparaît sans être déclaré ;
- un script déclaré disparaît avant la validation de migration ;
- un autoload legacy requis disparaît avant le test PC ;
- la surface joueur v0.9/canonique reprend une dépendance directe sur VS001 ;
- les clés de sauvegarde `veilleurs_vs001` (legacy) et `veilleurs` (canonique) sont modifiées dans le contrat ;
- la politique autorise à nouveau l'expansion de VS001.

Les tests `tests/test_veilleurs_vs001_legacy_audit.py` exécutent ce garde-fou dans la suite Python générale de la CI.

## Porte de suppression finale

Les neuf scripts restants ne doivent pas être supprimés uniquement sur une recherche de symbole : ils sont encore atteignables depuis le chemin de compatibilité.

La suppression finale exige un test réel sous Godot 4.7 sur PC :

1. charger une véritable sauvegarde utilisant `veilleurs_vs001` ;
2. migrer son état vers la clé canonique `veilleurs` ;
3. sauvegarder ;
4. recharger cette sauvegarde canonique ;
5. vérifier le monde, la progression et l'interface, ainsi que les états persistants applicables (blessures, corps, recrues, Rémanence, etc.) ;
6. seulement après validation, retirer les deux autoloads et recalculer les dépendances ;
7. supprimer chaque scène/script VS001 dont le nombre de dépendances actives devient nul ;
8. resserrer le contrat jusqu'à une surface runtime VS001 nulle.

## Règle de développement

VS001 est gelé. Les corrections qui ne concernent pas strictement la lecture/migration d'une ancienne sauvegarde doivent être faites dans les systèmes canoniques v0.9 ou ultérieurs.
