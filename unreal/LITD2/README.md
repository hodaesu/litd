# LITD 2 — Unreal Engine

Projet Unreal séparé de LITD 1. Les mécaniques présentes ici sont propres à **LITD 2** et ne doivent pas être raccordées au projet Godot ou au prototype comparatif `LITDValidation` sans décision explicite.

## Fondation actuelle

La première fondation C++ met en place les **Archives de Rémanence** :

- types de données pour les nœuds, sources, contradictions et reconstructions ;
- état de découverte persistant ;
- exigences de reconstruction avec sources alternatives ;
- déblocages de gameplay data-driven ;
- branche d'amorçage de Sarei décrite dans `Data/Remanence/sarei_seed.json`.

Les assets UMG, Data Assets `.uasset`, cartes et contenus binaires devront être créés/importés dans l'éditeur Unreal. Les classes C++ et données texte de ce dossier constituent le contrat d'implémentation versionné.

## Principes verrouillés

- pas de boucle temporelle ;
- pas de monnaie de Rémanence ;
- la progression persistante porte d'abord sur les connaissances et les possibilités ;
- les reconstructions importantes acceptent des voies de preuve alternatives ;
- Corps, Esprit, Politique et Serments restent indépendants des Archives ;
- LITD 1 et LITD 2 restent techniquement et ludiquement séparés.
