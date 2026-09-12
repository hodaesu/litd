# LITD1 — Production 3D des cinq héros

## Référence maîtresse
Les cinq planches approuvées sont les model sheets maîtresses. Elles fixent silhouette, proportions apparentes, visage, coiffure, costume, armure, armes, accessoires, matériaux, palette et symboles. Les dessins d'UV et de rig visibles sur les planches ne sont pas des données techniques exploitables : UV, topologie, squelette et skinning doivent être construits sur les meshes réels.

## Héros
- Ilyan Orme — silhouette sombre et stratifiée, arc court + dague.
- Sela Vën — gardienne rituelle claire, bâton rituel + accessoire cérémoniel.
- Varek Sorn — guerrier-forgeron lourd, marteau de guerre + bouclier lourd.
- Nara Deilen — stratège politique, éventails de guerre + lame courte.
- Èffrie — 1,80 m, guerrière politique du Pacte, inspiration amazone cuir/métal, lance + dague, cheveux rouge feu avec nuances or.

## Pipeline obligatoire
1. Blockout anatomique à l'échelle réelle en A-pose.
2. Blockout des vêtements et armures en volumes séparés.
3. Armes, accessoires, bijoux et symboles.
4. High-poly et détails de surface utiles au bake.
5. Retopologie game-ready avec priorité visage, mains, épaules, hanches et articulations.
6. UV réels, densité cohérente et îlots adaptés aux matériaux.
7. Bake et textures PBR metallic/roughness : Base Color, Normal, Roughness, Metallic, AO.
8. Cheveux game-ready en conservant la silhouette approuvée.
9. Rig humanoïde avancé, skinning, doigts, sockets d'armes et solution faciale.
10. Expressions : neutre, colère, concentration, douleur, peur/alerte, détermination.
11. Locomotion, réactions, mort, attaques d'armes et compétences signatures.
12. LOD0 à LOD3 en protégeant visage, mains, arme signature et silhouette.
13. Export GLB/glTF et validation Godot 4.3+.

## Contrôle qualité commun
Chaque héros doit passer une comparaison face/dos/profil avec sa planche. Aucun changement de silhouette, costume, coiffure ou arme signature ne doit être introduit pour faciliter la modélisation sans décision artistique explicite. Les vêtements et plaques doivent fonctionner pendant les amplitudes de combat sans intersections majeures.

## Èffrie
Sa chevelure doit rester un élément de silhouette majeur : rouge feu dominant, nuances or visibles dans les mèches, grandes boucles et tresses conservées. Son équipement reste amazone fonctionnel, mi-cuir mi-métal, sans transformation en armure lourde. Sa lance reste son arme iconique.

## Handoff Godot
À l'import, contrôler systématiquement : unité/échelle, orientation, squelette, noms d'animations, matériaux, transparence des cheveux, sockets d'armes, LOD et absence de clipping sur les poses critiques.
