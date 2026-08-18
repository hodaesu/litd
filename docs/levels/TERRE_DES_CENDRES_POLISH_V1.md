# Terre des Cendres — Polish V1

Cette passe sert à valider le niveau **avant Blender**. Les modèles finaux ne doivent pas dicter le level design.

## Parcours cible
1. Village ravagé — onboarding, première décision de route, première capture possible.
2. Forêt morte — désorientation, folie/stress, premier vrai embranchement.
3. Cimetière — attrition, narration environnementale, choix raccourci/détour.
4. Abbaye — compression, combat difficile, dernier point de préparation.
5. Clocher — climax et boss.

## Règles de rythme
- Ne pas enchaîner deux gros combats obligatoires sans respiration.
- Chaque zone possède au moins une décision spatiale ou un choix risque/récompense.
- Chaque zone possède au moins un élément de narration environnementale significatif.
- La pression de folie/stress augmente de zone en zone, avec une respiration contrôlée dans la Forêt ou l'Abbaye.
- Le joueur doit comprendre le système de capture avant le boss.

## Travail Godot avant Blender
- blockout spatial avec primitives ;
- collisions et navigation temporaires ;
- marqueurs de rencontres ;
- marqueurs d'interaction ;
- volumes de caméra ;
- volumes de lumière/brume ;
- événements audio/VFX placeholders ;
- points de repos ;
- raccourcis et embranchements ;
- transitions entre zones ;
- sauvegarde de progression dans le niveau ;
- instrumentation de durée, dégâts subis, stress gagné et combats évités/engagés.

## Ce qui reste volontairement ouvert
Le roster exact de chaque rencontre, les valeurs de difficulté et le boss définitif doivent être branchés via les données validées. Le level design ne doit pas les figer dans les meshes.

## Critère de validation
Le niveau est prêt pour Blender lorsqu'il est amusant et lisible avec des formes simples, que son rythme peut être testé de bout en bout, et que remplacer chaque placeholder par un asset final ne nécessite aucune modification structurelle du parcours.
