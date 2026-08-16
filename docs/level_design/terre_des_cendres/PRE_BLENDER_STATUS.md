# Terre des Cendres — état Pré-Blender

## Décisions verrouillées
- Exploration en véritable environnement 3D avec caméra 2.5D isométrique/semi-isométrique.
- Caméra principalement authored par zone, pitch de référence ~40°.
- Taille moyenne de référence ~100 × 100 m, avec formes adaptées à chaque lieu.
- 15 zones : 13 principales + 2 secrètes.
- Les raccourcis persistent entre les expéditions.
- Les voiles de cendres peuvent masquer ennemis ordinaires, ressources et butin, jamais boss ou mini-boss.
- Les mini-boss sont uniques, non recrutables, facultatifs, mobiles entre les expéditions et doivent toujours pouvoir être évités par un autre chemin.
- Le mini-boss secret alterne entre les deux zones secrètes.
- Feux de camp aux zones 3, 6, 9 et 12 ; repos utile mais coûteux.
- Le Sanctuaire est la seule source fiable de ravitaillement complet.
- Les cadavres peuvent fournir des ressources selon leur type (ex. corbeau → viande + plumes).

## Implémenté dans Godot avant Blender
- Manifeste de blockout des 15 zones.
- 15 scènes de zone chargées à partir du même constructeur de blockout.
- Sol, limites et collisions de placeholder.
- Profils de géométrie distincts pour les 15 zones (relief, murs, plateformes et landmark de référence).
- Points d'entrée et sorties physiques.
- Routeur de scènes entre zones.
- Contrôleur d'exploration CharacterBody3D.
- Caméra isométrique 3D de placeholder.
- HUD d'expédition.
- Volumes de cendres fonctionnels.
- Emplacements d'ennemis/rencontres.
- Rotation déterministe des mini-boss par graine d'expédition.
- Ressources interactives et persistantes.
- Fouille/récolte de cadavres.
- Feux de camp et coût de repos.
- Provisions détaillées : nourriture, eau, bandages, lumière, outils de camp, médecine.
- Raccourcis persistants.
- Téléporteur Abbaye ↔ Crypte avec coût prévu.
- Sauvegarde de l'état des zones, raccourcis, ressources, rencontres, provisions et rotation mini-boss.
- Tests Python et smoke test Godot de contrat Pré-Blender, incluant la couverture des profils de géométrie.
- Plans d'implantation authored pour les 15 zones : route principale, voie de contournement, rencontres, ressources, cendres, raccourcis, feux et boss.
- Marqueurs de navigation générés dans Godot à partir de ces plans, prêts pour le bake après playtest des volumes gris.
- Profil NavigationMesh préconfiguré pour le groupe (rayon, hauteur, pente, marche et résolution de bake).
- Retour exploration → combat → même zone et même position, y compris dans la sauvegarde en cours de combat.
- Sonde de performance par zone (FPS, temps de frame, objets, nœuds, draw calls et mémoire vidéo).
- Commandes d'exploration mobiles adaptatives : déplacement, course, interaction et zoom, ancrées aux bords de l'écran.
- Occultation multi-obstacles appliquée aux bâtiments, murs, reliefs et landmarks du blockout.
- Ambiance pré‑Blender par zone : éclairage, brume, particules de cendres et contrats audio placeholders.
- Contrat Blender → Godot versionné : échelle, axes, nommage, GLB, LOD, matériaux, collisions, sockets et budgets mobiles.
- Kit 3D cible attribué à chacune des 15 zones et registre runtime prêt à charger progressivement les futurs GLB.
- Métadonnées de remplacement sur chaque volume architectural avec conservation des collisions jusqu'à approbation.
- Profils de caméra authored pour les 15 zones : angle, orientation, cadrage, zoom et intention de lisibilité propres à chaque espace.
- Zoom orthographique corrigé pour modifier réellement le cadrage sur clavier et écran tactile.
- Outil de playtest intégré aux builds debug : navigation entre les 15 zones, validation route/détour/caméra/mobile et capture des performances.
- Rapport pré‑Blender persistant généré dans `user://ashlands_preblender_playtest.json` avec progression globale par zone.

## À tester/peaufiner dans Godot avant production 3D finale
- Ajustement manuel fin des plans authored après parcours en jeu ; le placement circulaire provisoire n'est plus utilisé lorsque le plan de zone est présent.
- Bake des NavigationMesh après stabilisation des volumes gris.
- Valeurs d'attrition et équilibrage des ressources après playtests.
- Position exacte des routes d'évitement des mini-boss.
- Validation de l'ergonomie tactile sur les tailles réelles d'iPhone et d'iPad.
- Réglage artistique final de l'occultation et des densités de cendres après playtest.
- Remplacement des contrats audio placeholders par les boucles et stingers définitifs.
- Mesure sur appareils iOS cibles et ajustement des budgets de la sonde après playtests.

## Ce qui exige réellement Blender
- Meshes finaux des héros, ennemis, mini-boss et boss.
- Kits architecturaux finaux des 15 zones.
- Retopologie, UV, baking et textures finales.
- Armatures, skinning et déformations finales.
- Animations finales.
- Props détaillés et variantes visuelles.
- Export GLB définitif et vérification des matériaux.

Principe de production : le gameplay et le level design doivent être validés sur blockout avant de remplacer les volumes temporaires par des assets Blender.
