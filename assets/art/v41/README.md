# LITD : Les Veilleurs — Pipeline d’assets canonique v41

Ce dossier est le point d’entrée de la passe artistique définitive. Les scripts de gameplay ne doivent jamais dépendre du nom physique d’un asset : ils utilisent les slots déclarés dans `res://data/canonical_art_v41.json`.

## Structure cible

- `backgrounds/` : écrans 16:9 et variantes assombries.
- `portraits/` : portraits de héros humanoïdes, nommés par `entity_id`.
- `creatures/` : portraits des créatures recrutables, nommés par `entity_id`.
- `anatomy/` : schémas anatomiques par morphologie réelle.
- `ui/` : cadres, nine-patches, ornements, séparateurs et emblème sans texte.
- `icons/body/` : icônes de zones corporelles.
- `PRODUCTION_MANIFEST.csv` : ordre de production, IDs stables, chemins cibles et statut légal.

## Priorités de production

Ne pas remplacer mécaniquement les 64 anciens assets dans l’ordre des dossiers.

- **P0** : emblème sans texte, Sanctuaire, Sahen Varo, Mira Sen, Narem Osh, Ysra Nahal, cadre de combat, cadres UI et anatomie humanoïde.
- **P1** : vertical slice définitive — fonds secondaires, Goule affamée, Oni, Jorōgumo, anatomies complémentaires et icônes corporelles.
- **P2** : extension du contenu, variantes, écrans secondaires et polish.

Le détail est documenté dans `res://docs/art/FINAL_ASSET_REPLACEMENT_PLAN.md`.

## Règle de remplacement

Un asset peut passer de `missing` à `placeholder`, `candidate`, `approved`, puis `final` sans modifier le gameplay. Le runtime cherche d’abord le chemin principal du slot, puis son fallback. Si aucun fichier n’existe, l’interface garde un fallback procédural ou textuel au lieu de casser.

Chaque remplacement doit conserver le ratio et l’intention du slot. Les changements de dégâts, précision, coût d’action, capture, mort permanente, blessures, compétences, économie et sauvegarde sont interdits dans cette couche.

## Gate juridique

Chaque asset de production reçoit son ID depuis `PRODUCTION_MANIFEST.csv` et une fiche construite à partir de `res://legal/PROVENANCE_TEMPLATE.md`.

Règles :

- `candidate` : provenance en cours de documentation acceptable pour build de revue ;
- `approved` / `final` : statut juridique **GREEN obligatoire** ;
- le wordmark commercial reste bloqué tant que le titre n’a pas passé la clearance requise ;
- les anciens binaires non documentés restent des placeholders de développement, pas des assets de release par défaut.

## Morphologie et blessures

Le schéma anatomique doit correspondre à la morphologie réelle de l’entité. Une créature serpentine, amorphe, insectoïde ou quadrupède ne doit jamais recevoir un mannequin humanoïde par défaut.

Les états fonctionnels visuels suivent le contrat F0–F4 : F3 conserve le membre mais le montre inutilisable ; F4 retire visuellement le segment détruit/amputé et modifie obligatoirement la silhouette. Le portrait, le modèle principal, le schéma anatomique et l’équipement doivent être cohérents entre eux.

Pour un humanoïde, si le bras qui porte l’arme passe F3/F4 et que l’autre bras reste fonctionnel, la présentation visuelle doit transférer l’arme à la main opposée. Pour les morphologies non humanoïdes, le transfert n’est autorisé que vers un appendice explicitement compatible.

## Critères d’approbation

Avant passage à `approved` ou `final`, vérifier : silhouette, lisibilité mobile, lisibilité PC, cohérence lore, alignement anatomique, visibilité des blessures/amputations, budget de performance et droits d’utilisation.

Les références artistiques servent à analyser puis recomposer ; elles ne doivent pas être copiées trait pour trait. Voir `res://data/art_reference_library.json`.
