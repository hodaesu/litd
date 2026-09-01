# LITD 2 — Pack de production officiel des Archives de Rémanence

> Statut : **OFFICIEL / PRODUCTION**  
> Portée : **LITD 2 uniquement**. Ne pas importer ces mécaniques ou cette direction UI dans LITD 1 sans décision explicite.

## 1. Objectif

Ce document transforme la direction artistique et UX des Archives de Rémanence en feuille de route de production exploitable dans Unreal Engine. Toute décision de fabrication des assets d’Archives doit rester compatible avec ce contrat.

L’intention générale est : **mémoire fracturée, cendre, connaissance reconstruite, gravité, lisibilité et prestige discret**.

À éviter : interface futuriste, fantasy magique générique, fanfare de loot, surcharge décorative, manuscrit illisible, couleurs néon, feedback arcade.

## 2. Palette canonique

- Fond principal : noir cendré / brun-noir fumé / gris poussière sombre.
- Texte principal : ivoire usé / beige parchemin / gris chaud clair.
- Corps : rouge sombre / cuivre.
- Esprit : ivoire lumineux / blanc froid.
- Politique : or vieilli.
- Médecine : blanc cassé / rouge profond.
- Technologie : argent vieilli.
- Personnes : ambre doux.
- Lieux : pierre froide / gris bleuté.
- Contradictions : rouge sec, sombre et nerveux.

## 3. Typographie

Trois niveaux sont obligatoires :

1. **Titres** — capitales élégantes, sobres, lisibles, sans surcharge ornementale.
2. **Sous-titres / états / catégories** — compacts, nets, immédiatement lisibles.
3. **Texte documentaire** — lecture confortable sur plusieurs lignes, jamais pseudo-manuscrite.

Les polices définitives devront être choisies et importées dans Unreal avec licences compatibles. Les fichiers de police eux-mêmes ne sont pas stockés ici tant que leur statut de droits n’est pas documenté.

## 4. Structure de l’écran

L’écran principal contient :

- un header avec **ARCHIVES DE RÉMANENCE** ;
- une constellation interactive occupant la majorité de l’écran ;
- un panneau documentaire à droite ;
- un footer discret rappelant les contrôles ;
- une révélation plein écran courte pour les reconstructions.

Navigation minimale : clic pour inspecter, glisser pour déplacer, molette pour zoomer, retour immédiat au jeu.

## 5. Nœuds

États : `INCONNU`, `TRACE`, `DOCUMENTE`, `RECONSTRUIT`, `CONTESTE`.

- INCONNU : sombre, faible halo, titre masqué ou `?`.
- TRACE : contour incomplet, lumière fragile.
- DOCUMENTE : contour stable, nom lisible.
- RECONSTRUIT : halo plus affirmé, ancrage visuel fort.
- CONTESTE : tension visuelle, accent rouge, vibration ou double lecture subtile.

Chaque catégorie garde son accent chromatique sans sacrifier la lisibilité.

## 6. Liens

- Liens normaux : fins, doux, légèrement instables.
- Liens établis : plus stables et un peu plus lumineux.
- Contradictions : brisées, irrégulières, rouge sombre.
- Les fils doivent sembler respirer ou circuler très légèrement, jamais clignoter.

## 7. FX

FX recommandés :

- cendre et poussière lente en arrière-plan ;
- halos locaux autour des nœuds actifs ;
- convergence de fils lors d’une reconstruction ;
- pulse court lors d’une découverte ;
- rupture visuelle locale lors d’une contradiction.

Niagara est autorisé quand il apporte une vraie valeur visuelle. Ne jamais ajouter un système Niagara uniquement pour remplacer un effet Slate/UMG moins coûteux.

## 8. Audio

Quatre cues principaux :

- `REM_ARCHIVE_OPEN`
- `REM_ARCHIVE_SELECT`
- `REM_ARCHIVE_CONTRADICTION`
- `REM_ARCHIVE_RECONSTRUCT`

Leur direction détaillée est définie dans `unreal/LITD2/Data/Remanence/archive_audio_direction.json`.

Règle absolue : l’UI audio reste plus discrète que les dialogues et ne masque jamais une information lisible.

## 9. Assets de production

Les noms canoniques et statuts sont définis dans :

`unreal/LITD2/Data/Remanence/archive_asset_manifest.json`

Familles obligatoires :

- textures ;
- matériaux ;
- Widget Blueprints ;
- sons ;
- Niagara optionnel ;
- styles typographiques ;
- validation multi-résolution.

## 10. Règles UX

- lisibilité avant décoration ;
- richesse sans surcharge ;
- aucune monnaie de Rémanence ;
- chaque déblocage explique sa cause historique ;
- aucune reconstruction importante ne dépend d’un drop à très faible probabilité ;
- les contradictions doivent être compréhensibles sans tutoriel lourd ;
- la reconstruction doit être satisfaisante sans ressembler à un écran de niveau gagné.

## 11. Validation Unreal obligatoire

Avant passage au statut `VALIDATED`, vérifier au minimum :

- 1920×1080 ;
- 2560×1440 ;
- 3840×2160 ;
- drag fluide ;
- zoom confortable ;
- lecture du panneau documentaire ;
- lisibilité des catégories ;
- contradictions immédiatement identifiables ;
- audio non intrusif ;
- performance stable ;
- comportement correct à l’ouverture et à la fermeture ;
- aucune dépendance involontaire à LITD 1.

La matrice versionnée se trouve dans :

`unreal/LITD2/Data/Remanence/archive_validation_matrix.json`

## 12. États de production

États autorisés :

- `TODO` — pas encore fabriqué ;
- `READY` — spécification prête, fabrication possible ;
- `IMPLEMENTED` — présent dans Unreal mais non validé final ;
- `VALIDATED` — testé visuellement et fonctionnellement dans l’éditeur ou le jeu ;
- `BLOCKED` — dépendance externe documentée manquante.

Un asset ne passe à `VALIDATED` qu’après test dans Unreal, jamais uniquement parce que sa spécification texte existe.

## 13. Droits

Tout asset final doit être :

- `LITD_ORIGINAL_REUSABLE`, ou
- `LICENSED_REUSABLE` avec source/licence documentée.

Les références externes non licenciées restent `REFERENCE_ONLY` et ne doivent pas être importées comme assets de production.

## 14. Définition de terminé

Le système Archives est considéré **production-ready** quand :

1. tous les assets `required: true` du manifest sont `VALIDATED` ;
2. toutes les cases `required: true` de la matrice de validation sont validées ;
3. l’écran est testable dans une build LITD 2 ;
4. les sons définitifs sont branchés ;
5. la lisibilité 1080p/1440p/4K est confirmée ;
6. la branche de Sarei est entièrement parcourable ;
7. une reconstruction complète fonctionne du fragment à l’affichage de la récompense historique.
