# Architecture CI/CD

## Barrières de qualité

1. Validation JSON et cohérence des identifiants.
2. Résolution des références `res://`.
3. Vérification des illustrations et des bornes de gameplay.
4. Tests Python reproductibles.
5. Import du projet avec l’éditeur Godot officiel en mode headless.
6. Smoke test GDScript.
7. Export uniquement après réussite de toutes les étapes.

## Artifacts

- rapport QA HTML et JSON ;
- journaux d’importation et smoke test ;
- build Web ;
- build Windows ;
- build Linux ;
- build Android debug via workflow manuel.
