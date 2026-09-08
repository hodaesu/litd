# LITD Les Veilleurs — Blender Modeling Runbook v52

Ce runbook transforme les plans `data/blender/modeling_plans_v52/` en ordre d'exécution PC. Il ne remplace pas le travail artistique Blender et ne doit jamais être utilisé pour déclarer un modèle terminé tant que le vrai `.blend` n'existe pas et n'a pas été validé dans Godot.

## Ordre verrouillé

1. `humanoid_standard`
2. `construct_biped`
3. `humanoid_massive`
4. `quadruped`
5. `insectoid`
6. `serpentine`
7. `amorphous`
8. `boss_ishar`
9. `boss_orateur_sans_voix`
10. `boss_mere_des_veines`
11. `boss_porte_cendres_blanc`
12. `boss_le_copiste`

Ne passer au maître suivant qu'après la validation complète du précédent, sauf blocage artistique explicite documenté.

## Boucle Blender à répéter pour chaque maître

1. Ouvrir ou créer exactement le `source_blend` défini par son plan v52.
2. Régler Blender en métrique, unité 1 m, appliquer les transforms.
3. Créer les collections `00_REFERENCE` à `90_EXPORT` du common contract.
4. Faire le blockout dans l'ordre du plan et valider la silhouette à distance de caméra gameplay.
5. Séparer les objets `BODY_*` exactement selon le plan. Les frontières de dégâts sont fonctionnelles et ne doivent jamais être fusionnées dans les LOD.
6. Créer les géométries `STUMP_*`/cassures/cicatrices réelles avant le skin final.
7. Construire le rig dans `rig_build_order`, puis les contrôles d'authoring nécessaires. Le premier os reste `ROOT`.
8. Skinner avec maximum quatre influences par sommet; privilégier les poids rigides pour plaques de construct.
9. Créer sockets, équipements et contrôles secondaires prévus par le plan.
10. Tester F0, puis tous les scénarios `f3_tests`, puis tous les `f4_tests`. Aucun F4 ne peut être recréé par une Action ou une transition de phase.
11. Produire matériaux/UV dans la direction v51/v52. Les détails sous l'échelle de lecture gameplay passent en textures plutôt qu'en micro-géométrie.
12. Construire LOD1/LOD2; conserver silhouette, sockets et limites BODY/STUMP.
13. Seulement après validation du modèle/rig, authorer les vraies Actions P0 exigées par v47/v48. Aucun placeholder n'est accepté.
14. Exporter en GLB avec animations, noms canoniques et transforms préservés.
15. Forcer l'import Godot, exécuter le validateur v49, le pipeline v50 puis un contrôle visuel humain sur cadrage mobile.

## Contrôles spéciaux

**Ishar** : aucune forme robotique moderne. Basalte/obsidienne, fer forgé, bronze terni, quatre ancres indépendantes. Le noyau mémoire doit lire comme un reliquaire sacré ancien. Aucun câble, piston, arme à feu, exosquelette sci-fi ou néon.

**Mère des Veines** : toute nouvelle croissance doit utiliser une géométrie distincte. Une croissance ne peut jamais restaurer un segment F4 détruit.

**Porte-Cendres Blanc** : manteau et diffuseurs sont de vraies zones systémiques. Les simulations de tissu/cendre doivent avoir un fallback mobile bake/simplifié.

**Le Copiste** : zéro violet, pourpre, magenta ou lilas dans matériaux, textures, lumières, VFX, phases ou LOD. La COPY_MATRIX est un reliquaire manuscrit/sceau d'encre ancien, jamais un réacteur. Une technique copiée ne peut jamais inventer un membre absent.

## Définition de fini

Un maître est fini uniquement si : le vrai `.blend` existe au chemin canonique; sa géométrie et son rig sont artistiques et exploitables; BODY/STUMP/F3/F4 sont testés; LOD0/1/2 sont présents; les Actions P0 contiennent de vrais keyframes; l'export GLB passe v49/v50; et le rendu est approuvé visuellement dans Godot sur un cadrage mobile représentatif.
