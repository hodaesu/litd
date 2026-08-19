# Pass 26 — Vertical slice visuel : préparation avant Blender

## Objectif

Valider **Darius contre une Goule affamée dans une petite arène des Terres de Cendre** avant de produire le reste du casting 3D. Le test ne cherche pas encore la finition finale : il doit prouver que la direction artistique approuvée survit au passage concept art → 3D → caméra de jeu → Godot.

La référence supérieure est l'Art Bible validée avec l'utilisateur. Si un ancien asset du dépôt contredit cette bible, la bible gagne.

## Ce qui est déjà préparé sans PC

- contrat visuel central : `data/visual_vertical_slice.json` ;
- jobs Blender dédiés : `data/blender/visual_vertical_slice_jobs.json` ;
- générateur déterministe : `tools/blender/generate_visual_vertical_slice_jobs.py` ;
- shader cel shading Godot : `shaders/litd_cel.gdshader` ;
- outline optionnel : `shaders/litd_outline.gdshader` ;
- scène proxy Godot : `scenes/visual/visual_vertical_slice_proxy.tscn` ;
- proxy Darius avec masses bouclier / armure lamellaire / épée / lanterne ;
- proxy Goule avec posture voûtée / bras allongés / griffes ;
- arène proxy 20 × 30 m avec zone de combat dégagée ;
- caméra et éclairage froid + accent chaud ;
- tests Python, audit QA et smoke Godot.

Aucun de ces proxies ne doit être confondu avec un modèle final.

## Règle de détail

La silhouette et les grandes masses passent avant les détails. Les détails doivent se concentrer sur quelques zones focales : visage, équipement signature, mains/griffes, emblèmes ou usure principale. Les grandes plaques, pans de tissu, bottes, dos et surfaces de peau restent volontairement plus simples.

Le rendu ne doit pas dériver vers :

- une armure fantasy occidentale générique ;
- du micro-détail uniforme ;
- du PBR photoréaliste ;
- des noirs sans information ;
- des motifs chinois ajoutés comme de simples stickers ;
- des effets lumineux néon trop présents.

## Première session PC

### 1. Mettre le dépôt à jour

```bash
git checkout main
git pull
python tools/blender/generate_visual_vertical_slice_jobs.py --check
```

### 2. Ajouter les références graphiques validées

Créer si nécessaire :

```text
docs/art/reference/
```

Puis placer manuellement les images validées sous les noms :

```text
docs/art/reference/litd_art_bible_master.png
docs/art/reference/darius_master_sheet.png
docs/art/reference/hungry_ghoul_master_sheet.png
```

Ces trois fichiers deviennent les références visuelles de production. Ne jamais remplacer silencieusement une référence validée par un ancien concept art.

### 3. Vérifier les plans avant Blender

```bash
python tools/blender/generate_visual_vertical_slice_jobs.py
python tools/blender/generate_visual_vertical_slice_jobs.py --check
```

### 4. Ouvrir le proxy Godot avant toute modélisation poussée

Ouvrir :

```text
scenes/visual/visual_vertical_slice_proxy.tscn
```

Vérifier d'abord :

- distance de caméra ;
- lecture du bouclier de Darius ;
- lecture de la posture de la Goule ;
- séparation personnages / fond ;
- équilibre entre lumière froide et accent chaud ;
- densité du décor.

Corriger ces points avant de détailler les modèles.

### 5. Produire les blockouts Blender

Darius en premier, puis la Goule, puis l'arène. Pour les personnages, utiliser le contrat de rig et de sockets déjà présent dans `build_character_scene.py`. Ne pas ajouter de micro-détails tant que les turntables proxy ne sont pas validés.

Le premier export GLB ne se fait qu'après revue visuelle du proxy.

### 6. Remplacer progressivement les proxies dans Godot

Ordre :

1. Darius ;
2. Goule ;
3. arène ;
4. caméra ;
5. lumière ;
6. animations minimum ;
7. VFX minimum ;
8. audio minimum.

À chaque remplacement, comparer la scène avec l'Art Bible plutôt qu'avec le proxy précédent.

## Critère de validation final

Le vertical slice est validé seulement si une capture d'écran représentative du combat peut être placée à côté de l'Art Bible sans sembler appartenir à une autre direction artistique.

En particulier :

- Darius doit rester identifiable à la vraie distance de combat ;
- la Goule doit fonctionner en silhouette seule ;
- les ombres doivent rester en grandes masses propres ;
- les noirs doivent garder du volume ;
- l'influence chinoise doit exister dans la construction des formes et du décor ;
- les télégraphes d'attaque doivent être lisibles ;
- le décor doit encadrer le combat, pas l'étouffer.

## Ce qui attend volontairement

- autres héros ;
- Oni, Jorōgumo et boss finalisés ;
- cinématiques ;
- vêtements/cheveux très complexes ;
- météo avancée ;
- destruction avancée ;
- démembrements visuels finaux ;
- ultimes définitifs ;
- optimisation mobile finale.

Ces éléments ne doivent commencer qu'après validation du langage visuel de ce slice.
