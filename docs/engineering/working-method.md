# Méthode d’ingénierie LITD — V2

- Statut : active candidate
- Confiance : high
- Domaine : ingénierie / qualité / gouvernance
- Date : 2026-09-11
- Remplace : proposition historique PR #254 après revalidation sur le `main` courant
- Décisions liées : ADR-0001, ADR-0004
- Contrats liés : `docs/architecture/CORE_CONTRACT.md`, `docs/knowledge/LIVING_LIBRARY_PROTOCOL.md`

## Objectif

Réduire les régressions, raccourcir les diagnostics et rendre chaque changement explicable, reproductible, mesurable et réversible, sans figer LITD dans une méthode devenue obsolète.

Cette méthode applique l’architecture vivante :

**Bibliothèque de savoir ⇄ Core ⇄ Réalisation réelle ⇄ tests/mesures ⇄ preuves ⇄ Bibliothèque**

## Boucle de changement par défaut

1. **Observer** le besoin, l’incident ou l’écart réel.
2. Appliquer **Qui ? Quoi ? Où ? Pourquoi ? Comment ?**
3. Charger les connaissances, décisions, dépendances et incidents proches.
4. Définir le comportement attendu et les invariants à préserver.
5. Évaluer **impact × risque × incertitude × coût d’erreur**.
6. Rechercher au niveau R0–R4 adapté ; pour une décision importante, chercher une contre-preuve.
7. Formuler les hypothèses et choisir le plus petit changement cohérent.
8. Implémenter sans masquer les erreurs ni créer un second état canonique.
9. Exécuter les validations adaptées au risque.
10. Mesurer le résultat réel, y compris la valeur joueur quand elle est concernée.
11. Enregistrer décision, preuves, limites, conséquences et réversibilité.
12. Réévaluer lorsque le code, le canon, les dépendances ou les preuves évoluent.

## Responsabilités

- **Bibliothèque** : conserve sources, connaissances, décisions, incidents, preuves et contradictions.
- **Core** : porte les règles, états canoniques, transitions et contrats indépendants de la présentation.
- **Knowledge Graph** : relie sujets, dépendances, risques, décisions et preuves.
- **Guardian** : autorise, demande des preuves supplémentaires ou bloque selon les invariants et le risque.
- **Réalisation réelle** : code, données, scènes, ressources et outils effectivement utilisés.
- **CI, tests, profilage et playtests** : produisent des preuves reproductibles ; un statut vert n’est jamais obtenu en masquant une erreur.
- **Retour d’expérience** : réinjecte les résultats dans la Bibliothèque et peut faire évoluer la méthode.

## Niveaux de validation

### L0 — statique et import

Syntaxe, encodage, JSON/YAML, ressources, imports, autoloads, contrats de données et règles Guardian automatisables.

### L1 — unité et invariants

Règles pures ou presque pures : structure des arbres, exclusivité, rangs, capture, déterminisme, sauvegarde et migrations.

### L2 — intégration de domaine

Interactions à l’intérieur d’un domaine : combat, progression, persistance, UI, narration, audio, monde, génération ou pipeline d’assets.

### L3 — parcours joueur / E2E

Chemins critiques réellement jouables. Ils prouvent un flux complet mais ne doivent pas être le premier endroit où une petite règle est diagnostiquée.

### L4 — exhaustif, nocturne ou expérimental

Matrices longues, simulations d’équilibrage, contrôles visuels coûteux, fuzzing, compatibilité étendue et campagnes de playtest.

Le niveau requis dépend du risque. Toutes les modifications n’exigent pas L3 ou L4, mais une règle critique ne peut rester sans preuve adaptée.

## CI par domaines et filet complet

L’ADR-0004 fait autorité :

- domaines actuels : `core-world`, `audiovisual`, `runtime`, `veilleurs`, `ui-qa` ;
- `fail-fast: false` pour conserver le diagnostic des domaines indépendants ;
- CI monolithique conservée comme filet de sécurité tant qu’une couverture équivalente n’est pas démontrée ;
- aucune suppression de test pour obtenir artificiellement un statut vert ;
- les listes de tests, durées et taux de flakiness doivent être mesurés pour éviter leur dérive.

## Déterminisme et reproduction

Toute défaillance stochastique doit fournir ce qui permet de la rejouer, selon le contexte :

- seed et état RNG ;
- test, scène, domaine et niveau de validation ;
- quatuor/roster, équipement et état pertinent ;
- version de schéma et snapshot compact ou sauvegarde lorsque possible ;
- logs et, pour l’UI/visuel, capture utile.

Une défaillance aléatoire non reproductible est un diagnostic incomplet, pas une justification pour relâcher l’invariant.

## Architecture

Direction cible : `data -> core -> présentation/adaptateurs`.

- Préférer les données validées et les exécuteurs génériques pour le contenu objectivable.
- Une information métier possède une seule source canonique.
- Les transitions significatives passent par une API, commande, événement ou contrat identifiable.
- La présentation consomme le Core ; le Core de production ne dépend pas de l’UI.
- Les exceptions sont documentées, limitées, testées et réexaminables.
- Les règles détaillées du Core restent définies par `CORE_CONTRACT.md`.

## Petits changements et réversibilité

Une PR doit avoir une raison principale identifiable. Séparer refactorisation et changement comportemental lorsque cela améliore le diagnostic. Préférer un changement minimal, mais jamais au prix d’un système incohérent ou d’une preuve insuffisante.

Git est le mécanisme de retour arrière par défaut. Toute migration irréversible ou coûteuse exige un plan de repli explicite.

## Definition of Done

Un changement est terminé lorsque tous les éléments applicables sont satisfaits :

- besoin et comportement attendu explicités ;
- invariants et dépendances identifiés ;
- hypothèses, risque et contre-preuve traités au niveau nécessaire ;
- réalisation complète, sans fallback masquant une erreur ;
- tests ciblés et intégrations pertinents verts ;
- parcours joueur validé si le flux runtime ou l’UI l’exige ;
- résultat reproductible et preuves liées au SHA audité ;
- effets de performance mesurés si concernés ;
- valeur joueur et compromis explicités pour une évolution majeure ;
- documentation, données, Core et Bibliothèque cohérents ;
- risques résiduels, réversibilité et conditions de réexamen enregistrés ;
- Guardian non bloquant et CI requise verte.

## Performance

Profiler avant d’optimiser. Définir des budgets mesurables : latence d’entrée en combat, résolution d’un tour, génération de donjon, sauvegarde/chargement, mémoire, objets/nœuds et fréquence d’images sur le matériel cible. Conserver mesures avant/après et contexte de mesure.

## Standard de PR

Une PR non triviale indique :

- pourquoi elle existe et sa valeur joueur/technique ;
- ce qui change réellement ;
- domaines, invariants et dépendances touchés ;
- recherches, alternatives et contre-preuves pertinentes ;
- tests, mesures et preuves ;
- risques, migrations et retour arrière ;
- éléments visuels lorsque l’UI ou l’art changent ;
- SHA auquel les preuves s’appliquent.

## Hygiène des sources

UTF-8, fins de ligne normalisées, conventions cohérentes et validations mécaniques automatisées. Une heuristique peut signaler un fichier à examiner ; elle ne peut jamais autoriser seule une suppression. Le trieur canonique, Git et le Guardian conservent leurs garde-fous propres.

## Évolution de la méthode

Cette méthode est une connaissance vivante. Elle doit évoluer par petit changement justifié, avec preuve, contradiction recherchée, mesure et historique. Une pratique ancienne n’est pas conservée par inertie ; une pratique nouvelle n’est pas adoptée par intuition seule.
