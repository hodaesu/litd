# Pass 27 — Vertical slice visuel : runtime prêt avant Blender

## Objectif

Préparer tout le runtime et les garde-fous qui peuvent être développés sans ouvrir Blender ni faire de validation visuelle locale. Le vertical slice reste **Darius contre une Goule affamée dans une petite arène des Terres de Cendre**.

La référence supérieure reste l'Art Bible approuvée. Aucun ancien concept art ni asset du dépôt ne peut la remplacer silencieusement.

## Ce qui est désormais préparé sans PC

- contrat visuel central v2 : `data/visual_vertical_slice.json` ;
- jobs Blender dédiés : `data/blender/visual_vertical_slice_jobs.json` ;
- générateur déterministe : `tools/blender/generate_visual_vertical_slice_jobs.py` ;
- shader cel shading : `shaders/litd_cel.gdshader` ;
- outline optionnel : `shaders/litd_outline.gdshader` ;
- scène proxy : `scenes/visual/visual_vertical_slice_proxy.tscn` ;
- runtime mini-combat : `scripts/visual/visual_slice_runtime.gd` ;
- contrôleur d'animations avec fallback sans clips : `scripts/visual/visual_slice_animation_controller.gd` ;
- loader GLB validé avec remplacement de proxy : `scripts/visual/validated_glb_loader.gd` ;
- VFX temporaires procéduraux : `scripts/visual/visual_slice_vfx.gd` ;
- audio de slice branché via les runtimes audio déjà présents quand disponibles ;
- budgets iPhone ;
- validateur d'assets 3D hors Blender ;
- modèle de revue Art Bible ↔ capture ;
- script de première session Blender ;
- contrats du reste du casting, sans autoriser leur production finale avant validation du slice.

Les proxies restent des masses de lecture et ne doivent jamais être traités comme des modèles finaux.

## Contrat d'import GLB

Les fichiers finaux attendus sont :

```text
assets/3d/characters/darius/darius.glb
assets/3d/characters/enemies/hungry_ghoul.glb
assets/3d/environments/ashlands/vertical_slice_arena.glb
```

Le loader n'instancie un GLB que s'il existe et passe les validations disponibles. En cas d'absence ou d'échec, le proxy reste affiché. Cela permet de travailler progressivement sans casser la scène.

Pour les personnages, les sockets attendus sont :

```text
SOCKET_weapon_r
SOCKET_weapon_l
SOCKET_head
SOCKET_back
SOCKET_fx_root
```

Le squelette minimal conserve le contrat humanoïde déjà utilisé par le pipeline Blender.

## Contrôleur d'animations

Le runtime connaît dès maintenant les états nécessaires :

### Darius

```text
idle
walk
tactical_step
attack_light
attack_heavy
guard
hit
stagger
death
```

### Goule affamée

```text
idle
crawl_walk
lunge
claw_1
claw_2
hit
stagger
death
```

Quand un vrai `AnimationPlayer` est disponible dans un GLB, le contrôleur joue le clip correspondant. Sinon, il émet quand même l'état logique afin que le mini-combat et les tests puissent fonctionner avant les animations définitives.

## Mini-combat de validation

Le combat de slice n'est pas un nouveau système de combat complet. C'est un banc d'essai isolé qui permet de vérifier rapidement :

- attaque légère de Darius ;
- attaque lourde ;
- garde ;
- dégâts reçus ;
- stagger ;
- mort de Darius ;
- griffes de la Goule ;
- bond de la Goule ;
- mort de la Goule ;
- déclenchement des VFX et sons associés.

Il reste volontairement découplé de la campagne et ne modifie aucune sauvegarde.

## VFX temporaires

Six familles sont préparées :

```text
sword_impact
ash_step_puff
subtle_attack_trail
metal_sparks
restrained_blood
lantern_light
```

Elles servent uniquement à tester timing, taille d'effet et lisibilité. Elles ne représentent pas les VFX finaux.

## Audio du slice

Le runtime demande les familles suivantes :

```text
footstep_ash
combat_telegraph
weapon_impact
ghoul_vocal
ashlands_wind
combat_music
```

Il tente de déléguer aux directeurs audio existants et reste silencieux si une famille n'a pas encore de fichier final. Aucun nouveau binaire audio propriétaire n'est ajouté.

## Budgets iPhone du vertical slice

### Personnage, par modèle

- LOD0 : maximum 60 000 triangles ;
- LOD1 : maximum 30 000 ;
- LOD2 : maximum 12 000 ;
- maximum 3 matériaux ;
- maximum 80 os ;
- maximum 3 meshes skinnés ;
- textures : 2048 px maximum sur ce slice.

### Arène visible

- 180 000 triangles visibles maximum ;
- 18 matériaux visibles maximum ;
- aucune texture 4K ;
- un seul directional shadowed ;
- deux omni dynamiques maximum, sans ombres ;
- objectif : 60 fps en paysage, validation minimale à 50 fps ;
- objectif draw calls : 220 maximum.

Ces nombres sont des **budgets de départ**, pas des garanties de performance. Ils devront être révisés après mesure sur appareil réel.

## Revue Art Bible ↔ capture

Le rapport de revue note sur 5 :

- silhouette ;
- lisibilité des valeurs ;
- correspondance palette ;
- masses d'ombres cel shading ;
- influence chinoise structurelle ;
- lisibilité des télégraphes ;
- densité du décor ;
- équilibre froid/chaud ;
- lisibilité des matériaux ;
- appartenance à la même famille visuelle que l'Art Bible.

La moyenne cible est 4/5. Les critères silhouette, valeurs, influence chinoise structurelle, télégraphes et appartenance à la famille Art Bible sont bloquants.

## Première session PC

```bash
git checkout main
git pull
python tools/blender/vertical_slice_session.py --preflight
```

Puis :

1. copier les trois références approuvées dans `docs/art/reference/` ;
2. ouvrir `scenes/visual/visual_vertical_slice_proxy.tscn` ;
3. valider caméra et lisibilité ;
4. générer le blockout Darius ;
5. lancer le validateur 3D ;
6. rendre le turntable ;
7. remplir la revue ;
8. seulement ensuite autoriser l'export GLB ;
9. refaire la séquence pour la Goule ;
10. refaire la séquence pour l'arène.

## Reste du casting

Les contrats de production peuvent être préparés pour Aurélien, Malvor, Lysandra, Oni, Jorōgumo et Ange inversé, mais aucun modèle final ne doit être produit avant la validation du langage visuel du vertical slice.

## Critère de validation final

Le slice est validé uniquement si une capture de combat représentative peut être placée à côté de l'Art Bible sans sembler appartenir à une autre direction artistique. Le résultat doit rester lisible à la vraie caméra de jeu et non uniquement dans un turntable rapproché.
