# LITD : Les Veilleurs — Intentions, rencontres narratives et Rémanence v1

## Source

Cette couche utilise exclusivement le pack canonique Pré-PC du 3 septembre 2026, SHA-256 `0739666c23b6aad99d79128147b84322155bbdd5ff49c62b0990eaf11fec8919`.

Les 1 305 compétences ennemies/boss proviennent de :

- `comp_bestiaire_585.json` : 585 lignes ;
- `comp_ii_v_720.json` : 720 lignes.

Soit 29 entités × 3 arbres × 15 compétences = 1 305 compétences normales.

## Huit familles d’intentions

1. Assaut
2. Contrôle
3. Repositionnement
4. Défense
5. Soutien
6. Environnement
7. Chasse/Embuscade
8. Fuite/Cession/Recrutement

Les sept premières familles décrivent les actions tactiques. La huitième est une intention d’état de combat : quitter réellement le combat, céder ou ouvrir une résolution capture/ralliement. Une technique de recul ou de fuite tactique qui reste dans le combat demeure donc du Repositionnement.

Les 87 arbres possèdent un binding primaire et éventuellement secondaire. Deux rôles de nœud ont priorité sur le binding d’arbre :

- `Contrôle` → Contrôle ;
- `Interaction monde` → Environnement.

Les passifs conservent une famille d’intention pour la connaissance et l’IA, mais ne sont jamais affichés comme action en attente.

## Télégraphie et connaissance

Les états épistémiques canoniques restent :

`UNKNOWN → SUSPECTED → OBSERVED → CONFIRMED → UNDERSTOOD`.

Les degrés 0–5 servent uniquement au détail de présentation de l’intention. Ils ne sont pas une seconde progression de connaissance.

La lumière et la perception réduisent uniquement ce qui est affiché maintenant :

- visibilité claire : 0 niveau perdu ;
- lumière faible : -1 ;
- visibilité critique : -2 ;
- obscurité : -3.

Formule runtime : `display_detail = clamp(stored_detail - perception_penalty, 0, 5)`.

La connaissance stockée n’est jamais effacée par une mauvaise perception temporaire.

## Normalisation des IDs de compétences

Le référentiel contient 1 305 lignes mais seulement 1 275 IDs courts distincts. Trente IDs entrent en collision :

- `DÉL-CHA-01..15` entre Délié Affamé / Chair ouverte et Délié Boursouflé / Chair de réserve ;
- `POR-PRO-01..15` entre Porte-Cendres Blanc / Procession immobile et Porte-Signe / Procession muette.

Les IDs source sont conservés tels quels. Le runtime et la sauvegarde utilisent donc :

`{entity_id}:{source_skill_id}`

Cette combinaison est unique pour les 1 305 compétences.

## 64 rencontres : narration + récompenses + capture

Les feuilles `Compositions_64`, `Rencontres_narratives_64` et `Recompenses_capture` contiennent les mêmes 64 noms dans le même ordre. Le runtime ne dépend pourtant jamais du numéro de ligne : la jointure se fait par nom de rencontre.

Chaque rencontre reçoit :

- introduction ;
- beat en combat ;
- texte de victoire ;
- texte de retraite ;
- indice de Rémanence ;
- menace ;
- or cible ;
- essence cible ;
- Rémanence cible ;
- butin ;
- règle de capture ;
- bonus de connaissance.

Une rencontre absente ou dupliquée est une erreur bloquante. Capture ≠ recrutement ; l’espèce et sa condition spécifique doivent être admissibles ; aucun boss n’est recruté ; aucun pourcentage de capture n’est affiché.

## Rémanence : promotions par histoire vécue

Les rangs restent : Normal → Mémoriel → Vétéran → Élite → Némésis.

Les huit événements de promotion canoniques sont : survie, meurtre d’un Veilleur, mutilation, fuite, capture échouée, objet important pris/récupéré, retraite provoquée, rencontres répétées.

Quatre canaux de mémoire bornée sont conservés, un slot actif par canal :

- famille de menace ;
- positionnement ;
- capture ;
- relation.

### Normal → Mémoriel

Un événement réellement vécu doit créer une histoire partagée vérifiable. Le simple spawn ne compte pas.

### Mémoriel → Vétéran

Un enseignement issu d’un événement vécu doit être réutilisé lors d’une rencontre ultérieure et modifier réellement une décision tactique.

### Vétéran → Élite

L’individu doit utiliser un enseignement vécu pour influencer concrètement un allié, une formation ou la logique de la rencontre avec une capacité déjà présente dans son propre arbre.

### Élite → Némésis

Une histoire partagée rare et saillante doit exister, puis une nouvelle confrontation directe doit avoir lieu. Un ancrage majeur est requis : meurtre d’un Veilleur, capture échouée suivie d’un retour, mutilation partagée, objet important ou retraite provoquée.

Une Némésis n’est jamais tirée au hasard par le générateur. Elle conserve ses vraies blessures, n’obtient pas d’immunité scriptée, ne lit pas le build global du joueur et n’est jamais définie comme un simple sac à PV.

## Génération vérifiable

`tools/veilleurs/build_runtime_bindings_from_prepc_pack.py` valide le SHA du pack et produit :

- `data/veilleurs/generated/enemy_skill_intent_binding_1305_v1.json` ;
- `data/veilleurs/generated/encounter_narrative_reward_64_v1.json`.

Il refuse : SHA incorrect, entité inconnue, arbre non lié, type d’action inconnu, ID runtime dupliqué, rencontre absente/dupliquée ou divergence d’ordre/acte entre les trois feuilles canoniques.

## Bloc PC / Godot suivant

La conception data-driven est prête. Le runtime doit maintenant implémenter : IntentResolver, affichage progressif des télégraphes, machine de sortie/capture, injection des hooks Rémanence dans l’IA, génération des fichiers runtime à partir du pack, puis playtests tactile/PC.
