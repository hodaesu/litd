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

Les anciennes structures 5/25, 6/24 et 7/15 sont rejetées.

`species_catalog_recovered_v1.json` restaure les 16 noms canoniques actuellement récupérables :

- Silencieux : Écouteur Creux, Porte-Signe, Marcheur Aphone, Reteneur de Souffle ;
- Veines : Veine Rampante, Nœud-Écorché, Porte-Sang, Germe Artériel ;
- Porte-Cendres : Marche-Pâle, Porte-Linceul, Effaceur de Traces, Dormeur de Cendre ;
- Gardiens de Version : Copie Lacunaire, Rature Vivante, Archiviste de Version, Double du Seuil.

Les noms des 8 espèces restantes des familles Déliés, Pèlerins Fendus, Gardiens de Pierre et Bêtes de Suie ne sont pas verrouillés dans la source récupérable. Aucun placeholder n’est autorisé.

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

Cible : 21 synergies canoniques. Toute synergie doit être visible, compréhensible et cassable, avec trigger, condition de rupture et feedback observable.

La liste nominale complète des 21 synergies doit encore être restaurée depuis sa source canonique. Aucun nom provisoire n’est autorisé.

### Boss

Canon actuel :

1. Ishar I — **Le Veilleur des Seuils**
2. Orateur II — **La Voix Incarnée**
3. Mère III — **La Matrice des Refuges**
4. Porte-Cendres IV — **Le Gardien de la Cendre**
5. Copiste V — **L’Archiviste des Cicatrices**

Les cinq boss sont **recrutables**, mais uniquement selon leur règle narrative canonique. Les mini-boss restent non recrutables.

### Recrutement et Refuge

- équipe : 4 combattants maximum ;
- au moins 1 Veilleur ;
- Refuge : 12 recrues maximum ;
- voies de ralliement : soumission, reddition, sauvetage, pacte, apprivoisement ;
- pas de pourcentage de capture affiché ;
- l’UI expose les états observables : Volonté, blessures, posture, relation, contexte de ralliement ;
- les boss utilisent une condition narrative dédiée plutôt qu’un ralliement générique.

### Rémanence

Rangs :

`Normal → Mémoriel → Vétéran → Élite → Némésis`

Une adaptation ennemie doit provenir de faits réellement vécus. La mémoire omnisciente est interdite. Les cicatrices du monde sont stockées comme états/flags/références, jamais comme snapshots complets de scènes.

## Fichiers

- `data/veilleurs/content_foundation_v2.json`
- `data/veilleurs/species_catalog_recovered_v1.json`
- `data/veilleurs/recruitment_refuge_contract_v1.json`
- `data/veilleurs/remanence_entity_contract_v1.json`
- `data/veilleurs/encounter_generation_contract_v1.json`
- `tests/test_veilleurs_content_foundation_v2.py`

## Ordre de continuation sans inventer le canon

1. Restaurer les 8 noms d’espèces encore non verrouillés.
2. Restaurer les 64 templates nominaux.
3. Restaurer les 21 synergies nominales.
4. Brancher les catalogues sur le générateur hybride.
5. Brancher recrutement et persistance d’identité.
6. Ajouter le Refuge et les Archives à la verticale jouable.
7. Faire passer les tests Godot + Python + QA avant fusion.
