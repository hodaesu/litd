# Incident — runtime-player-smoke equipment

## Qui ?
Le smoke test joueur `runtime_player_smoke_test.gd`, `EquipmentManager` et les données d’équipement du quatuor de départ.

## Quoi ?
Le test échouait sur `A rare party weapon must be generated`.

## Où ?
`EquipmentManager.grant_random_party_weapon()` pouvait sélectionner Mathilde (`duelist`), Anouk (`mystic`) ou Aurélien (`surgeon`), alors que `data/equipment.json` ne contenait aucun équipement `test_level` pour ces classes.

## Pourquoi ?
La migration du quatuor canonique avait mis à jour `data/heroes.json` sans compléter le matériel de niveau test correspondant. Seul Marec (`breaker`) disposait déjà de candidats.

## Comment ?
Ajouter deux armes et une armure `test_level` pour chacune des trois classes manquantes, les charger avec les données d’équipement et ajouter un test Python vérifiant que chaque héros de départ possède au moins deux armes et une armure.

## Prévention
Le test `tests/test_starting_quartet_equipment.py` devient le garde-fou anti-régression pour ce contrat.
