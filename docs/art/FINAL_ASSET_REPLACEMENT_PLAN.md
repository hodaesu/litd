# LITD : Les Veilleurs — Plan de remplacement des assets définitifs

Date : 2026-09-08

Objectif : remplacer les anciens visuels juridiquement non documentés sans bloquer le gameplay et verrouiller la direction artistique à partir d'un petit nombre d'assets structurants.

## Principe

Ne pas refaire les 64 placeholders dans l'ordre des dossiers.

On remplace d'abord les images qui définissent :

1. le monde ;
2. les silhouettes des quatre Veilleurs ;
3. le langage UI ;
4. la lecture du combat ;
5. la représentation systémique du corps et des blessures.

Puis seulement les créatures, variantes et écrans secondaires.

## P0 — DA structurante

### 1. Emblème sans texte — `ART-LITD-V41-SYM-001`

But : posséder immédiatement une signature visuelle indépendante du futur titre commercial.

Contraintes :

- aucune mention `Light in the Dark` dans l'image ;
- symbole simple lisible à 48 px ;
- compatible icône mobile, splash PC, favicon et watermark ;
- charbon / os / bronze usé ;
- éviter rune fantasy générique et imitation d'un symbole existant.

### 2. Sanctuaire — `ART-LITD-V41-BG-001`

C'est l'asset environnemental prioritaire.

Il doit fixer :

- architecture post-Chute ;
- matériaux ;
- traitement de la lumière ;
- palette ;
- échelle humaine ;
- présence de la politique, de la mémoire et de la reconstruction ;
- navigation par lieux et non par panneaux flottants.

Critère de réussite : une capture sans HUD doit être reconnaissable comme LITD.

### 3–6. Quatre Veilleurs

- `ART-LITD-V41-HERO-001` — Sahen Varo
- `ART-LITD-V41-HERO-002` — Mira Sen
- `ART-LITD-V41-HERO-003` — Narem Osh
- `ART-LITD-V41-HERO-004` — Ysra Nahal

Chaque héros doit être reconnaissable en silhouette seule.

Vérifications :

- origine culturelle et morphologie cohérentes avec le lore ;
- aucun des quatre n'est Aurélien ;
- armes/équipement compatibles avec le système de blessures ;
- bras, mains et équipement permettent les états F3/F4 ;
- les quatre silhouettes ne doivent pas être quatre variantes du même archétype ;
- lisibilité sur écran mobile paysage.

### 7. Cadre de combat — `ART-LITD-V41-BG-002`

But : rendre la boucle centrale crédible sans sacrifier la lisibilité.

Doit réserver visuellement :

- espace aux combattants ;
- zones de dégâts/blessures ;
- informations critiques ;
- sang/cadavres sans masquer les cibles ;
- profondeur suffisante pour la lecture des rangs.

### 8–9. Cadres UI

- `ART-LITD-V41-UI-001` — panel frame
- `ART-LITD-V41-UI-002` — tooltip/context frame

Ce duo doit devenir la grammaire de base de tous les écrans.

À éviter :

- cartes rectangulaires de jeu mobile générique ;
- néon ;
- plastique ;
- surcharge de dorures ;
- textures trop détaillées derrière le texte.

### 10. Anatomie humanoïde — `ART-LITD-V41-BODY-001`

Prioritaire parce que le gore systémique n'est pas seulement décoratif.

Doit rendre lisibles :

- F0 fonctionnel ;
- F1 dégradé ;
- F2 très dégradé ;
- F3 inutilisable mais présent ;
- F4 détruit/amputé avec modification de silhouette.

## Gate P0

P0 est validé uniquement si :

- les quatre héros forment un groupe immédiatement distinctif ;
- Sanctuaire + combat + UI semblent appartenir au même monde ;
- la palette canonique fonctionne sur mobile et PC ;
- blessures et anatomie restent lisibles ;
- chaque asset a une fiche `legal/PROVENANCE_TEMPLATE.md` complétée ;
- aucun asset n'est `approved` sans droits documentés.

Tant que P0 n'est pas approuvé, ne pas produire massivement les 39 créatures.

## P1 — Vertical slice définitive

### Environnements

- `ART-LITD-V41-BG-003` — fond titre, sans wordmark définitif tant que le nom n'est pas cleared ;
- `ART-LITD-V41-BG-004` — fiche personnage ;
- `ART-LITD-V41-BG-005` — archive/bestiaire ;
- `ART-LITD-V41-BG-006` — expédition.

### Créatures de validation

- `ART-LITD-V41-CREA-001` — Goule affamée ;
- `ART-LITD-V41-CREA-002` — Oni ;
- `ART-LITD-V41-CREA-003` — Jorōgumo.

Pourquoi ces trois :

- Goule = créature organique de base + évolution ;
- Oni = masse/armure/rupture ;
- Jorōgumo = morphologie qui force le pipeline à sortir du mannequin humanoïde.

### Anatomie et feedback

- `ART-LITD-V41-BODY-002` — humanoïde massif ;
- `ART-LITD-V41-BODY-003` — insectoïde ;
- `ART-LITD-V41-ICON-001` — famille d'icônes corporelles.

Gate P1 : le vertical slice doit démontrer héros, créature standard, créature massive et morphologie non humanoïde sans contradiction entre portrait, anatomie, combat et blessures.

## P2 — Extension du contenu

Après validation P0/P1 :

- reste des créatures du premier niveau ;
- boss ;
- variantes évoluées ;
- anatomies restantes ;
- états de blessures supplémentaires ;
- équipements visibles ;
- résultats ;
- overlays ;
- sanctuaire assombri ;
- effets de transition ;
- assets promotionnels.

## Branding / nom

Le wordmark `ART-LITD-V41-TXT-001` reste volontairement `blocked_name_clearance`.

La production peut avancer avec :

- un emblème sans texte ;
- l'appellation interne `LITD : Les Veilleurs` ;
- aucun logo final utilisant `Light in the Dark` tant que la clearance n'est pas terminée.

## Décision économique

Un ancien placeholder dont la provenance reste impossible à établir n'a pas besoin d'être « sauvé » si sa version définitive doit de toute façon être redessinée.

Règle :

**si le coût de recherche de provenance dépasse le coût de remplacement propre, remplacer.**
