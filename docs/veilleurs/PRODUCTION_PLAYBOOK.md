# LITD : Les Veilleurs — Production Playbook

## Objectif

Ce document transforme les bonnes pratiques de production en **règles de travail concrètes pour Les Veilleurs**. Il complète les audits et pipelines déjà présents sans les remplacer.

Le but est d'éviter deux dérives :

- produire trop tôt un grand volume de contenu non validé ;
- considérer qu'un système est « terminé » parce qu'il existe dans les données ou passe la CI.

---

## 1. Ordre de travail par défaut

Toute nouvelle idée suit cet ordre :

`intention joueur -> hypothèse -> prototype -> playtest -> décision -> production -> intégration -> QA -> validation appareil -> verrouillage`.

Si une étape échoue, on corrige ou on réduit le périmètre avant de poursuivre.

---

## 2. Les quatre preuves obligatoires

Une fonctionnalité majeure n'est pas considérée comme validée tant qu'elle ne possède pas les quatre preuves suivantes.

### Preuve A — Design

- le problème ou l'intention est défini ;
- le pilier LITD servi est identifié ;
- la mécanique et la dynamique attendue sont décrites ;
- le risque principal est connu.

### Preuve B — Joueur

- un joueur peut la comprendre sans explication externe excessive ;
- le résultat observé correspond à l'expérience recherchée ;
- les problèmes récurrents de lisibilité sont documentés.

### Preuve C — Technique

- intégration Godot réelle ;
- pas seulement une donnée ou un mockup ;
- smoke/test associé ;
- sauvegarde et rémanence vérifiées si concernées ;
- budget de performance respecté si concerné.

### Preuve D — Production

- le procédé peut être répété ;
- les assets ont une nomenclature et une source canonique ;
- le coût de création est compatible avec le volume prévu ;
- la QA peut détecter les régressions.

---

## 3. Gates de production

### Gate 0 — Intention

Questions :

- Pourquoi cette fonctionnalité existe-t-elle ?
- Quel comportement du joueur voulons-nous provoquer ?
- Quel pilier sert-elle ?
- Quelle fonctionnalité existante pourrait déjà répondre au besoin ?

Sortie : fiche de mécanique courte.

### Gate 1 — Prototype

Conditions de passage :

- hypothèse testable ;
- prototype minimal ;
- test d'au moins un scénario normal et un scénario limite ;
- décision : garder / modifier / supprimer.

### Gate 2 — Verticale

Conditions :

- gameplay réel ;
- UI réelle ;
- feedback audio/visuel suffisant pour juger ;
- sauvegarde ;
- performance mesurée ;
- test tactile sur cible dès que matériel disponible.

### Gate 3 — Production

Conditions :

- pipeline d'asset et de données stable ;
- conventions validées ;
- budgets connus ;
- duplication interdite si un système générique existe ;
- Definition of Done appliquée.

### Gate 4 — Alpha

Conditions :

- boucle principale jouable de bout en bout ;
- systèmes majeurs présents ;
- aucune dépendance critique manquante ;
- sauvegarde/reprise robuste ;
- bugs bloquants tracés.

### Gate 5 — Beta

Conditions :

- scope quasi gelé ;
- optimisation ;
- accessibilité ;
- compatibilité appareils ;
- localisation ;
- équilibrage ;
- tests de longue session ;
- tests de reprise après interruption mobile.

### Gate 6 — Release Candidate

Conditions :

- CI et audits verts ;
- validation matériel ;
- crash/ANR et mémoire sous contrôle ;
- conformité stores ;
- migration de sauvegarde testée ;
- notes de version ;
- procédure de rollback/correctif.

---

## 4. Workflow d'une mécanique

Template obligatoire :

```text
Nom :
Problème / intention joueur :
Pilier LITD :
Hypothèse :
Mechanics :
Dynamics attendues :
Aesthetics / émotion recherchée :
Interactions systèmes :
Feedback visuel :
Feedback sonore :
Feedback haptique :
Risques :
Cas limites :
Mesure / observation playtest :
Critères d'acceptation :
Critères de suppression :
Tests automatisables :
Tests matériels :
```

---

## 5. Workflow d'un asset

`brief -> références multiples -> silhouette -> valeurs -> palette -> matière -> version jeu -> test scène -> test mobile -> optimisation -> validation`.

Un asset n'est jamais validé uniquement sur fond neutre.

Checklist :

- silhouette lisible à la taille réelle ;
- hiérarchie visuelle correcte ;
- palette canonique respectée ;
- matériaux cohérents ;
- pas de détail inutile invisible sur mobile ;
- pas de référence unique trop reconnaissable ;
- coût GPU/mémoire acceptable ;
- nommage et dossier corrects ;
- source et runtime séparés si nécessaire ;
- variantes contrôlées par données quand pertinent.

---

## 6. Workflow UI/UX

Ordre :

1. tâche joueur ;
2. hiérarchie d'information ;
3. wireframe ;
4. prototype interactif ;
5. intégration Godot ;
6. test tactile ;
7. DA ;
8. accessibilité ;
9. performance ;
10. régression.

Règles :

- aucune information essentielle par couleur seule ;
- zones tactiles larges et espacées ;
- état sélectionné/pressé visible ;
- éviter les couches de menus inutiles ;
- objectifs et conséquences visibles avant validation d'une action importante ;
- actions destructives confirmées ;
- réglages sauvegardés ;
- safe areas validées sur appareils réels.

---

## 7. Workflow combat

Toute modification du combat doit tester au minimum :

- lecture des tours ;
- ciblage ;
- positions/rangs ;
- blessures ;
- Peur/Folie ;
- capture ;
- compagnon ;
- boss ;
- interaction équipement ;
- sauvegarde/reprise ;
- lisibilité tactile.

Les tests doivent chercher les stratégies dominantes, boucles infinies, soft-locks, actions sans contrepartie et situations où l'interface masque l'état réel du combat.

---

## 8. Playtest continu

### Avant le test

Définir une question unique prioritaire.

### Pendant

Ne pas expliquer ce que le jeu devrait faire. Observer ce qu'il fait comprendre.

### Après

Classer les problèmes :

- bloquant ;
- compréhension ;
- friction ;
- rythme ;
- balance ;
- émotion ;
- préférence individuelle.

On corrige d'abord les patterns répétés et les blocages objectifs.

---

## 9. Budgets mobile

Les budgets précis seront verrouillés après mesures sur appareils, mais chaque scène doit déjà suivre :

- objectif FPS stable ;
- frame time mesuré ;
- mémoire surveillée ;
- draw calls surveillés ;
- transparence/overdraw limités ;
- shaders et post-traitements justifiés ;
- temps de chargement tracé ;
- chauffe testée sur session longue ;
- profil faible/médian/cible.

Les valeurs deviennent contractuelles seulement après benchmark matériel.

---

## 10. Definition of Ready

Une tâche entre en production seulement si :

- objectif joueur clair ;
- dépendances identifiées ;
- owner identifié ;
- critères d'acceptation écrits ;
- test prévu ;
- risques connus ;
- données/assets requis identifiés ;
- périmètre assez petit pour être revu.

---

## 11. Definition of Done

Une tâche est « done » seulement si :

- intégrée en jeu ;
- critères d'acceptation satisfaits ;
- tests pertinents passés ;
- documentation canonique à jour ;
- rapports disponibles ;
- pas de régression critique ;
- accessibilité vérifiée si concernée ;
- performance vérifiée si concernée ;
- sauvegarde/migration vérifiée si concernée ;
- visuel/audio validés en contexte si concernés ;
- matériel réel validé si l'étape l'exige.

---

## 12. Discipline de scope

Avant d'ajouter une fonctionnalité, choisir explicitement une option :

- **ajouter** ;
- **remplacer** ;
- **fusionner** ;
- **différer** ;
- **supprimer**.

Une fonctionnalité ajoutée sans coût de maintenance estimé est considérée comme non prête.

---

## 13. Priorité actuelle Les Veilleurs

L'ordre recommandé est :

1. prouver la boucle de combat et sa lisibilité réelle ;
2. prouver la boucle exploration -> combat -> conséquence -> Sanctuaire ;
3. verrouiller l'UX mobile ;
4. verrouiller la DA en contexte de jeu ;
5. établir les budgets performance sur appareils ;
6. stabiliser la verticale du Chapitre I ;
7. seulement ensuite accélérer la production de contenu répétitif.

Ce playbook ne réduit pas l'ambition de LITD. Il empêche l'ambition de se transformer en dette de production.
