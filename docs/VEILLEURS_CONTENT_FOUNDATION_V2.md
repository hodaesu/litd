# LITD : Les Veilleurs — Fondation de contenu v2

Cette couche raccorde les décisions de contenu de **Les Veilleurs** à l’architecture déjà présente dans `data/veilleurs/`.

## Déjà autoritaire dans le dépôt

- quatre Veilleurs : Nayra Orun, Tarek Senn, Aïsha Maren, Idris Vael ;
- 3 arbres de 15 compétences par Veilleur, soit 180 compétences ;
- contrats de verticale `vs001_*` ;
- contrats de finition, accessibilité et parité mobile/PC.

Les fichiers de compétences existants ne doivent pas être dupliqués.

## Fondation canonique ajoutée

### Bestiaire

La référence actuelle attend :

- 24 espèces ordinaires ;
- 8 familles de combat :
  1. Déliés
  2. Pèlerins Fendus
  3. Gardiens de Pierre
  4. Bêtes de Suie
  5. Silencieux
  6. Veines
  7. Porte-Cendres
  8. Gardiens de Version

Les anciennes structures 5/25, 6/24 et 7/15 sont explicitement rejetées par `content_foundation_v2.json`.

**Important :** la liste nominale complète des 24 espèces n’est pas présente de façon récupérable sur `main` au moment de ce lot. Aucun nom de remplacement ne doit être inventé. Elle doit être restaurée depuis la dernière source canonique avant création d’un catalogue autoritaire.

### Rencontres

Contrat :

- 64 compositions canoniques ;
- 4 ennemis standards maximum ;
- 1 ennemi Mémoriel maximum ;
- une Némésis n’est jamais créée artificiellement par le générateur ;
- pas deux fois le même template de suite ;
- après deux occurrences dans les cinq dernières salles, poids ×0,4 ;
- génération reproductible par seed ;
- la Rémanence est projetée après le layout.

### Synergies ennemies

Cible : 21 synergies canoniques. Toute synergie doit être :

- visible ;
- compréhensible ;
- cassable ;
- munie d’un trigger explicite ;
- munie d’une condition de rupture ;
- munie d’un feedback observable.

La liste nominale complète des 21 synergies doit être récupérée avant population : aucun placeholder n’est autorisé.

### Boss

Cinq slots canoniques :

1. Ishar
2. Orateur
3. Mère
4. Porte-Cendres
5. Copiste

Boss et mini-boss ne sont pas recrutables.

### Recrutement et Refuge

- équipe : 4 combattants maximum ;
- au moins 1 Veilleur ;
- Refuge : 12 recrues maximum ;
- voies de ralliement : soumission, reddition, sauvetage, pacte, apprivoisement ;
- pas de pourcentage de capture affiché ;
- l’UI expose les états observables : Volonté, blessures, posture, relation, contexte de ralliement.

### Rémanence

Rangs :

`Normal → Mémoriel → Vétéran → Élite → Némésis`

Une adaptation ennemie doit provenir de faits réellement vécus. La mémoire omnisciente est interdite. Les cicatrices du monde sont stockées comme états/flags/références, jamais comme snapshots complets de scènes.

## Fichiers

- `data/veilleurs/content_foundation_v2.json`
- `data/veilleurs/recruitment_refuge_contract_v1.json`
- `data/veilleurs/remanence_entity_contract_v1.json`
- `data/veilleurs/encounter_generation_contract_v1.json`
- `tests/test_veilleurs_content_foundation_v2.py`

## Ordre de continuation

1. Restaurer la liste canonique complète des 24 espèces.
2. Restaurer les 64 templates nominaux.
3. Restaurer les 21 synergies nominales.
4. Brancher les catalogues sur le générateur hybride.
5. Brancher recrutement et persistance d’identité.
6. Ajouter le Refuge et les Archives à la verticale jouable.
7. Faire passer les tests Godot + Python + QA avant fusion.
