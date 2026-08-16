# Terre des Cendres — plan de production 3D

Le plan machine `data/levels/ashlands_blender_jobs.json` contient un ordre de fabrication pour chacune des 15 zones. Il est généré depuis les manifestes de blockout, les profils de layout et le contrat Blender → Godot.

## Priorités

- **P0** : zones 1, 4, 7, 12 et 13. Elles valident respectivement l'entrée de biome, la nature, les grands espaces, l'architecture monumentale et le boss final.
- **P1** : zones 2, 3, 8, 9, 14 et 15. Elles couvrent les villages, les intérieurs souterrains et les zones secrètes.
- **P2** : zones restantes, produites après validation des kits précédents.

## Contenu de chaque ordre

- kit visuel et profil de layout ;
- dimensions de la zone et landmark principal ;
- quantité de bâtiments, murs, bloqueurs et plateformes ;
- emplacements de gameplay à préserver ;
- politique LOD et collisions ;
- dossier de sortie ;
- critères d'approbation avant import dans Godot.

## Utilisation

```bash
python tools/blender/generate_ashlands_jobs.py > /tmp/ashlands_blender_jobs.json
python tools/blender/generate_ashlands_jobs.py --check
```

Le second appel échoue si les données de level design ont changé sans régénération du plan. Ce fichier constitue également l'entrée prévue pour le futur logiciel d'automatisation Blender.
