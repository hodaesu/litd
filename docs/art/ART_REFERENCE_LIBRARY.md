# Bibliothèque d’inspiration picturale de LITD

La bibliothèque centrale se trouve dans `data/art_reference_library.json`. Elle rassemble des peintures, estampes, enluminures, fresques et mosaïques issues de collections institutionnelles en accès ouvert.

Elle sert à préparer :

- les œuvres originales visibles dans les cités et Sanctuaires ;
- les mosaïques, fresques, rouleaux et manuscrits du monde ;
- la composition, la lumière et la palette d’un lieu ou d’un donjon ;
- les cadrages de cinématiques et la mise en scène des combats ;
- les motifs du journal, du codex et des factions.

## Méthode obligatoire

Une création LITD combine au moins trois références. L’équipe relève des principes abstraits — rythme, profondeur, contraste, matière, hiérarchie, rapport entre figures et architecture — puis transforme la composition, les motifs, la palette et le contexte narratif.

Une référence n’est jamais un modèle à reproduire. Sont interdits : calque, copie trait pour trait, reprise d’un personnage identifiable et imitation d’une signature.

Le statut juridique indiqué facilite la présélection, mais la fiche du musée doit être vérifiée avant d’intégrer une image source au pipeline. Les URL institutionnelles sont conservées pour cette vérification.

## Recherche

```bash
python tools/art/search_reference_library.py --use donjon
python tools/art/search_reference_library.py --culture Japon
python tools/art/search_reference_library.py --category mosaique
python tools/art/search_reference_library.py --preset donjon_du_voile
```

Les résultats donnent les principes à étudier et les usages LITD suggérés. Ils ne téléchargent aucune image et n’ajoutent donc aucun fichier lourd ni ambigu juridiquement au dépôt.
