# LITD : Les Veilleurs — BLOCKED AT GODOT

Date : 2026-09-03

## État

La préparation éditoriale et statique utile sans moteur est terminée pour le corpus combat/rencontres retrouvé.

Le pack canonique est identifié, extrait, hashé et validé statiquement. Les contrats source/runtime et squelettes d'intégration sont versionnés. La prochaine preuve utile exige désormais un exécutable Godot et le projet sur Windows.

## Ce qui a déjà été prouvé sans Godot

- source canonique récupérée ;
- pack ZIP intègre ;
- 33 feuilles actuelles + 1 legacy exportées ;
- 12 arbres / 180 compétences / 12 ultimes Veilleurs ;
- 29 entités ennemies/boss ;
- 87 arbres / 1 305 compétences / 87 ultimes ennemis/boss ;
- 99 arbres / 1 485 compétences normales / 99 ultimes au total ;
- 15 compétences par arbre ;
- progression 1–50 cohérente ;
- 64 rencontres ;
- 16 phases boss ;
- 12 dangers ;
- 48 tests source ;
- roster/ralliement actuel séparé du legacy 25/75 ;
- ancien stade 315 explicitement supersédé ;
- particularité des IDs Acte I documentée et résoluble par clé composite `(Entité, ID)` ;
- script Python de validation statique fourni.

## Ce qui NE PEUT PAS être déclaré validé sans Godot

### Compilation

- syntaxe GDScript réelle des squelettes ;
- disponibilité exacte des APIs selon la version Godot du projet ;
- autoloads, resources, typed arrays, signals et chemins `res://` / `user://`.

### CombatResolver

- ordre réel ActionIntent -> armor -> tissue -> lesion -> fonction -> incapacité/mort ;
- interactions de timeline ;
- réactions ;
- ciblage anatomique ;
- démembrement causal ;
- variantes blessé/équipement ;
- précision et valeurs du référentiel.

### IA / SPE

- perception sans omniscience ;
- baisse de certitude ;
- intentions ;
- mémoire individuelle ;
- adaptation mémorielle ;
- coût CPU sur mobile.

### Rencontres

- lecture des 64 templates ;
- profondeur/budget ;
- limite standard mobile de quatre ennemis ;
- anti-répétition ;
- insertion mémorielle ;
- dangers persistants ;
- déterminisme du flux ENCOUNTER.

### Boss

- interprétation des conditions de transition ;
- Ishar 3 phases ;
- Orateur 3 ; Mère 3 ; Porte-Cendres Blanc 3 ; Copiste 4 ;
- conservation des blessures/cicatrices entre phases ;
- absence d'exceptions cachées au resolver.

### Sauvegarde

- transaction A/B réelle ;
- interruption pendant écriture ;
- reprise iOS ;
- migrations ;
- non-duplication et non-résurrection.

### UI / mobile

- taille tactile ;
- cible anatomique au pouce ;
- lisibilité des intentions ;
- performance ;
- mémoire ;
- chargements ;
- haptique ;
- suspension/reprise.

### Tests

Les 48 cas existent dans la source, mais ils restent marqués comme devant être automatisés dans Godot et complétés par playtest tactile. Les compter n'est pas les exécuter.

## Première session PC — ordre obligatoire

1. matérialiser le pack canonique ;
2. vérifier SHA-256 ;
3. exécuter `tools/validate_canonical_pack.py` ;
4. identifier la version Godot réellement utilisée ;
5. compiler les squelettes un par un ;
6. corriger uniquement les incompatibilités moteur, sans changer les règles de contenu ;
7. intégrer le loader ;
8. porter le validateur G0/G0B ;
9. créer le CombatResolver minimal ;
10. lancer les premiers tests bloquants du catalogue `Tests_48` ;
11. construire la verticale Acte I ;
12. exporter tôt sur iPhone/iPad.

## Règle de reprise

Ne pas commencer par importer les 1 485 compétences dans des scènes Godot individuelles.

Commencer par prouver le pipeline avec un sous-ensemble explicitement marqué `prototype_subset`, tout en validant statiquement que le corpus complet existe et reste accessible.

## Conclusion

À partir d'ici, produire davantage de logique GDScript sans compilation augmenterait le risque plus vite que la valeur. Le projet a donc atteint sa frontière pré-PC réelle.
