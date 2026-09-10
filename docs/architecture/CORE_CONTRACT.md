# LITD Core Contract — V1

## Rôle

Le Core de LITD contient les règles, états, orchestrations et contrats qui doivent rester valides indépendamment de la présentation visuelle.

Le Core n'est pas un dossier « tout ce qui est important ». Il doit rester le noyau stable, testable et explicable du jeu.

## Appartient au Core

- règles de gameplay et transitions d'état ;
- état canonique d'une run, d'un combat, d'un personnage ou d'un système persistant ;
- orchestration déterministe ou reproductible des systèmes ;
- politiques et décisions runtime qui ne dépendentent pas de l'UI ;
- validation des invariants ;
- sérialisation/sauvegarde et migrations de données ;
- seed, RNG contrôlé et déterminisme lorsque le système l'exige ;
- événements/signaux métier ;
- adaptation audio/narrative uniquement sous forme de décision ou d'état abstrait, la restitution restant hors Core ;
- contrats permettant aux couches UI, scène, audio et outils de consommer l'état du jeu.

## N'appartient pas au Core

- widgets, menus, HUD, animations UI ;
- mise en page ou logique liée à une résolution d'écran ;
- chargement de scènes destiné uniquement à la présentation ;
- effets visuels, shaders, particules et composition graphique ;
- code de debug ponctuel non réutilisable ;
- contenu de gameplay qui peut être décrit dans `data/` ;
- dépendance runtime de production directe vers `scripts/ui/`.

Les harnesses de smoke/intégration actuellement rangés dans `scripts/core/` peuvent dépendre de l'UI lorsqu'ils testent explicitement la frontière Core ↔ présentation. Cette exception ne leur donne pas le statut de module Core de production et doit rester identifiable par leur nom (`*_smoke_test.gd`, `*_smoke_bootstrap.gd`). À terme, ces harnesses pourront être déplacés dans une arborescence de tests dédiée sans modifier l'invariant architectural.

## Direction des dépendances

Direction cible :

`data -> core -> présentation/adaptateurs`

La présentation peut dépendre du Core. Le Core de production ne doit pas dépendre de la présentation.

Les exceptions de production doivent être explicites, documentées par ADR, limitées et accompagnées d'un plan de suppression ou d'une justification durable.

## Invariants architecturaux V1

### CORE-INV-001 — indépendance UI

Aucun module Core de production ne doit charger directement un fichier situé dans `scripts/ui/`. Les harnesses de smoke/intégration identifiés comme tels sont hors périmètre de cet invariant lorsqu'ils exercent volontairement l'intégration UI.

### CORE-INV-002 — données hors code quand objectivables

Les listes de héros, ennemis, compétences, loot, paramètres d'équilibrage et contenu répétitif doivent vivre dans `data/` lorsqu'ils peuvent être représentés sans logique procédurale.

### CORE-INV-003 — état canonique unique

Pour une information métier donnée, une seule source canonique doit exister. Les couches de présentation peuvent dériver ou mettre en cache un affichage, mais ne doivent pas créer un second état concurrent.

### CORE-INV-004 — transitions explicites

Les changements d'état significatifs doivent passer par une fonction, commande, événement ou contrat identifiable. Éviter les mutations dispersées impossibles à tracer.

### CORE-INV-005 — déterminisme contrôlé

Tout système utilisant du hasard et nécessitant reproductibilité, sauvegarde, audit, loot persistant ou test doit exposer/consommer un seed ou un état RNG contrôlé.

### CORE-INV-006 — sauvegarde versionnée

Tout état persistant doit être sérialisable avec une version de schéma et une stratégie de migration ou de compatibilité.

### CORE-INV-007 — erreurs visibles

Le Core ne doit pas masquer silencieusement un invariant violé par un fallback qui donne l'impression que le système fonctionne. Les fallbacks autorisés doivent être intentionnels, observables et testés.

### CORE-INV-008 — tests par risque

Chaque règle critique doit avoir au moins une preuve adaptée : test Python/statique, smoke Godot, test de données, test de sauvegarde, simulation ou playtest selon la nature du risque.

### CORE-INV-009 — séparation décision / restitution

Un directeur Core peut décider **quoi** doit se produire (état musical, intensité, événement narratif, feedback requis), mais la couche de restitution décide **comment** l'afficher, le jouer ou l'animer.

### CORE-INV-010 — évolution traçable

Toute modification d'un invariant Core doit être reliée à une décision, une preuve ou une connaissance de la Living Library et revalidée après intégration.

## Critères pour ajouter un nouveau module Core

Un nouveau fichier de production dans `scripts/core/` doit répondre à au moins une de ces questions :

1. Porte-t-il un état canonique ?
2. Applique-t-il une règle métier/gameplay ?
3. Orchestre-t-il plusieurs systèmes sans dépendre de leur présentation ?
4. Protège-t-il un invariant ?
5. Fournit-il un contrat stable à plusieurs consommateurs ?

Si aucune réponse n'est oui, le module appartient probablement à une autre couche.

## Definition of Done — module Core

Un module Core est considéré terminé lorsque :

- sa responsabilité est unique et documentée ;
- ses entrées/sorties sont explicites ;
- ses dépendances sont compatibles avec ce contrat ;
- son état persistant est versionné si nécessaire ;
- son hasard est contrôlé si nécessaire ;
- au moins un test couvre son risque principal ;
- les erreurs importantes sont observables ;
- la documentation/Knowledge Library concernée est à jour.

## Évolution

Ce contrat est vivant. Il peut évoluer si des preuves issues du code, des tests, du profilage ou des playtests montrent qu'une autre frontière produit un meilleur système. Toute modification doit préserver l'historique de la décision et éviter les changements purement esthétiques d'architecture.
