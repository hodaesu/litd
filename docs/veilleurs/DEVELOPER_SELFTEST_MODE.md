# LITD : Les Veilleurs — mode d’auto-test développeur

## Pourquoi ce mode existe

Le mode développeur sert à éliminer les blocages évidents de la verticale du Chapitre I avant d’exposer la build aux cinq testeurs naïfs. Il ne remplace jamais un playtest humain et ne peut promouvoir aucun gate joueur.

## Modélisation requise

L’auto-test utilise volontairement une **modélisation greybox représentative** :

- volumes et routes 3D Godot ;
- caméra isométrique ;
- collisions ;
- points d’intérêt et interactions ;
- rencontres ;
- ressources ;
- feu de camp quand nécessaire ;
- boss/élite ;
- HUD et UI réels ;
- combat tactique réel ;
- sauvegarde/reprise réelle.

Les Terres de Cendre disposent déjà d’un générateur de blockout Godot (`ashlands_blockout_builder.gd`) capable de produire sol, limites, routes, slots de rencontres, ressources, lore, campfire, boss, personnage placeholder, HUD et probes de performance. Blender n’est donc pas requis pour ce jalon.

La modélisation finale n’est pas une condition d’entrée en auto-test. Un asset final n’est produit maintenant que s’il est indispensable pour juger une décision, une silhouette ou une information que le greybox ne permet pas d’évaluer.

## Tranche à parcourir

Le contrat machine est :

`data/veilleurs/developer_selftest_contract.json`

Le parcours cible reste :

1. Sanctuaire / préparation ;
2. exploration courte ;
3. combat A — lecture de base ;
4. combat B — position + anatomie ;
5. Peur / Folie ;
6. élite / mini-boss ;
7. décision finale ;
8. retour au Sanctuaire.

Durée cible : **30 à 45 minutes**.

## Lancer l’auto-test

Sous Windows :

```bat
tools\workstation\LITD_VEILLEURS_FIRST_PLAYTEST.cmd
```

Sans argument, l’identifiant est `developer-selftest`.

Le runner :

1. exécute le préflight ;
2. prépare une session locale ;
3. exporte la build Windows debug ;
4. lance la build avec `--developer-selftest` après le séparateur d’arguments Godot `--` ;
5. active l’overlay développeur uniquement dans ce mode.

Pour un testeur naïf :

```bat
tools\workstation\LITD_VEILLEURS_FIRST_PLAYTEST.cmd naive-01
```

Dans ce cas l’overlay développeur n’est pas activé.

## Overlay

L’overlay affiche :

- étape actuelle ;
- question de test ;
- cible de durée ;
- chronomètre ;
- écran courant ;
- champ de note rapide ;
- bouton pour consigner un problème ;
- progression vers l’étape suivante.

`F10` masque ou réaffiche l’overlay.

Le rapport local est écrit dans :

`user://veilleurs_developer_selftest.json`

Il enregistre les changements d’écran, étapes, notes et temps. Il contient explicitement `human_gate_promotion_allowed=false`.

## Ce que le développeur doit chercher

Priorité :

- **P0** : crash, soft-lock, perte de sauvegarde, impossibilité de finir la boucle ;
- **P1** : règle centrale incompréhensible, ciblage incohérent, action sans explication, conséquence essentielle invisible ;
- ensuite seulement P2/P3.

Le test n’a pas pour but de vérifier les 45 compétences d’un Veilleur, l’ensemble des chapitres ou la richesse du contenu. Il doit répondre à :

> Le cœur de LITD fonctionne-t-il assez clairement pour mériter cinq vrais testeurs ?

## Critère de sortie

L’auto-test est prêt à céder la place à `naive-01` lorsque :

- la boucle peut être terminée ;
- aucun P0 n’est ouvert ;
- les P1 évidents ont été corrigés ou documentés ;
- sauvegarde/reprise ne casse pas la session ;
- combat, anatomie et Peur/Folie produisent au moins une décision observable chacun ;
- le retour au Sanctuaire montre une conséquence ;
- la build et la CI restent vertes.

L’auto-test développeur ne doit pas être répété indéfiniment pour chercher le polish. Une fois ces conditions réunies, la prochaine source d’information doit être un joueur naïf.
