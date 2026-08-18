# Combat — familles ennemies et réactions aux démembrements

Le combat v6 de **Light in the Dark** ajoute une identité tactique aux grandes familles ennemies sans remplacer les couches précédentes :

`v6 familles ennemies → v5 déplacements forcés → v4 démembrements → v3 rangs/synergies → v2 rounds à quatre héros`.

## Principe

Une famille n'est pas seulement une apparence. Elle définit **comment l'ennemi cherche à casser la formation** et quel membre rend cette manœuvre possible.

La perte du membre critique n'inflige pas une mort automatique : elle supprime ou transforme le comportement de famille.

## Familles génériques

### Humanoïdes — Ligne disciplinée

Exemples : Goule, Cultiste, Chevalier déchu, Oni, Tengu, prêtres, gardiens, Nonne renversée.

- Cadence : tous les 3 rounds.
- Manœuvre : repousse le héros de rang 1 d'un rang.
- Membre critique : **bras d'attaque**.
- Démembrement : la perte du bras supprime la manœuvre de poussée.

### Bêtes — Charge bestiale

Exemples : Minotaure, Chien d'Os, Charognard cuirassé, Loup du Voile.

- Cadence : tous les 2 rounds.
- Manœuvre : charge la première ligne et la repousse.
- Membre critique : **membre antérieur**.
- Démembrement : la charge est perdue et la bête recule d'un rang au moment de la blessure.

### Arachnides — Fil de rappel

Exemples : Jorōgumo, Veuve du Voile.

- Cadence : tous les 2 rounds.
- Manœuvre : attire le héros de rang 4 vers la mêlée.
- Membre critique : **appendice venimeux**.
- Démembrement : la traction disparaît.

### Aberrations — Décalage de chair

Exemples : Ver des profondeurs, Mange-Rêves, Sangsue royale, Dévoreur de lumière, Moiré, Colosse sans nom.

- Cadence : tous les 3 rounds.
- Manœuvre : permute les rangs 2 et 3 de la compagnie.
- Membre critique : **appendice d'ancrage**.
- Démembrement : l'aberration perd sa capacité de décalage et son propre corps est ramené vers la première ligne.

### Constructions — Onde d'impact

Exemples : Scarabée funéraire, Éclat vivant, Miroir mort.

- Cadence : tous les 3 rounds.
- Manœuvre : onde qui repousse la première ligne.
- Aucun membre organique critique obligatoire.
- Les formes explicitement non démembrables conservent donc une identité tactique sans forcer une anatomie artificielle.

## Élites et boss

### Mini-boss sans manœuvre dédiée — Bris de formation

- Cadence : tous les 3 rounds.
- Permute les rangs 2 et 3.
- Utilise son **bras d'attaque** quand son anatomie le permet.
- La perte de ce membre neutralise la manœuvre.

### Boss sans manœuvre dédiée — Pression de phase

- Cadence : tous les 3 rounds.
- Échange les rangs 1 et 4.
- Utilise le **membre de soutien**.
- Sa perte neutralise la pression de formation.

Les boss possédant déjà une manœuvre spécifique — par exemple le Général de Silex, la Frontière qui marche, le Consensus Brisé ou la Rupture Commune — **ont priorité** et ne déclenchent pas une seconde manœuvre familiale dans le même tour.

## Couverture actuelle

Les 37 ennemis génériques non-boss de `data/enemies.json` sont tous classés exactement une fois entre les cinq familles de base. Les mini-boss et boss utilisent ensuite les catégories `elite` ou `boss`, sauf lorsqu'une mécanique spécifique possède la priorité.

## QA

`python -m tools.qa.enemy_family_tactics_audit`

L'audit vérifie notamment :

- couverture complète et sans doublon des ennemis génériques ;
- sept comportements de famille ;
- cadence et effets reconnus ;
- existence des membres critiques dans les profils anatomiques ;
- priorité des mécaniques spécifiques de boss ;
- réactions fonctionnelles aux démembrements ;
- routage du combat principal par `main_v6.gd`.
