# Contrat Core ⇄ Trieur canonique LITD

## Principe

Le trieur n'est pas un outil de nettoyage isolé. Il est un capteur et un exécutant contrôlé du **LITD Development Intelligence System**.

Boucle vivante :

**Bibliothèque de savoir ⇄ Core ⇄ Trieur ⇄ dépôt Git/Godot réel ⇄ CI/tests/mesures ⇄ Core ⇄ Bibliothèque**

Tout bouge : le canon, les dépendances, les références, les implémentations et les preuves peuvent évoluer. Le trieur doit donc réobserver l'état réel avant chaque décision et ne jamais considérer une ancienne classification comme une vérité permanente.

## Responsabilités

### Bibliothèque de savoir
Conserve les recherches, ADR, décisions, preuves, incidents, contradictions, états de connaissance et raisons d'obsolescence.

### Core
Croise le savoir avec l'état réel. Il fournit au trieur les décisions canoniques, invariants, dépendances connues, niveaux de confiance et politiques Guardian. Il reçoit en retour les anomalies et observations du dépôt.

### Trieur
Observe et rapporte : fichiers, références par chemin et UID, doublons, familles de versions, collisions de casse, compagnons Godot, historique Git et candidats à révision. Il peut recommander, mais une heuristique ne peut jamais autoriser seule une suppression.

### Guardian
Autorise, demande des preuves supplémentaires ou bloque selon le risque. Une contradiction avec le canon, une référence active, une preuve insuffisante ou une ambiguïté critique doit empêcher la suppression.

### Git
Est l'autorité d'exécution et le mécanisme de retour arrière. Toute suppression suivie passe par la procédure Git-backed et sa simulation préalable.

### CI / tests / runtime
Apportent les preuves reproductibles que le dépôt reste cohérent après une décision.

## Contrat de données minimal

Chaque observation importante du trieur doit pouvoir exposer :
- sujet/fichier ;
- état observé ;
- statut proposé ;
- confiance ;
- raisons ;
- références et dépendances ;
- preuves ;
- contradictions ;
- remplacement éventuel ;
- tests/validations associés ;
- date/head Git de l'observation.

Chaque décision Core consommée par le trieur doit être traçable vers une source de connaissance ou une règle explicite.

## Règle de décision

**Le trieur observe et recommande. Le Core raisonne et gouverne. Le Guardian autorise ou bloque. Git exécute et permet le retour arrière. La CI apporte la preuve. La Bibliothèque conserve ce qui a été appris.**

Un nom `v50`, une date récente, un faible nombre de références ou un doublon exact ne suffisent jamais isolément à déclarer un fichier obsolète.

## Boucle de rétroaction

1. Le trieur observe le head Git courant.
2. Il compare l'état réel au canon et aux règles fournies par le Core.
3. Les divergences deviennent des observations, jamais des suppressions automatiques.
4. Le Core relie l'observation au Knowledge Graph et recherche les connaissances proches.
5. Si l'incertitude le justifie, le Research & Evidence Engine déclenche une recherche adaptée R0–R4 et recherche une opposition pertinente.
6. Le Guardian évalue invariants, risque, confiance et preuves.
7. Une décision structurée peut alors promouvoir un fichier canonique, conserver un fichier actif, demander une revue ou déclarer une obsolescence.
8. Le trieur reconstruit un plan depuis le nouvel état réel.
9. Les gates de sûreté, Git, tests et CI valident l'action.
10. Résultat, preuves, incident éventuel et apprentissage retournent dans la Bibliothèque/Core.

## Interdictions

- Pas de suppression fondée uniquement sur une heuristique.
- Pas de décision fondée uniquement sur « version la plus récente ».
- Pas de cache de canon considéré éternellement valide.
- Pas de contournement d'une règle Guardian pour obtenir une CI verte.
- Pas de suppression si les preuves ne correspondent plus au head Git audité.
- Pas de perte silencieuse d'une contradiction : elle doit être remontée au Core.

## Évolution

Ce contrat est lui-même une connaissance vivante. Toute modification importante doit suivre la boucle LITD : 5W → savoir existant → recherche adaptée → opposition → petit changement → tests → mesure → preuve → mise à jour du graphe.
