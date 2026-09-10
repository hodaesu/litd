# ADR-0004 — CI Godot par domaines avec filet monolithique

- Statut : active
- Confiance : very_high
- Domaine : ingénierie / CI / qualité
- Date : 2026-09-10
- Niveau de recherche : R2

## Qui ?
Les développeurs LITD, GitHub Actions, les suites Godot et les futures évolutions du dépôt.

## Quoi ?
La CI Godot est organisée en deux niveaux complémentaires :
- une CI monolithique conservée comme filet de sécurité complet ;
- cinq domaines parallèles : `core-world`, `audiovisual`, `runtime`, `veilleurs`, `ui-qa`.

## Où ?
`.github/workflows/ci.yml`, `.github/workflows/ci-godot-domains.yml` et `tools/build/run_godot_ci_domain.sh`.

## Pourquoi ?
Réduire le temps de diagnostic et localiser rapidement une régression sans diminuer la couverture de la CI complète.

## Comment ?
- les domaines s'exécutent en parallèle ;
- `fail-fast: false` permet d'obtenir le diagnostic de tous les domaines même si l'un échoue ;
- les contrôles stricts Godot/GDScript/autoload et les timeouts restent actifs ;
- seuls les runs PR devenus obsolètes peuvent être annulés automatiquement ;
- la CI monolithique n'est pas supprimée par cette architecture.

## Alternatives considérées
- Remplacer entièrement la CI monolithique par des jobs fragmentés : rejeté à ce stade, risque de perte de couverture.
- Garder uniquement la CI monolithique : rejeté, diagnostic trop lent et trop peu localisé.
- Ajouter une couche de domaines tout en gardant le filet complet : retenu.

## Éléments de preuve
- PR #253 fusionnée : introduction des cinq domaines et conservation explicite de la CI existante.
- PR #257 fusionnée : extension de l'annulation des runs PR obsolètes à Balance Telemetry et Remanence Smoke sans interrompre arbitrairement les runs manuels.
- PR #242 fusionnée : banc d'auto-test développeur déterministe qui complète la CI sans remplacer les preuves runtime Godot.

## Contre-preuves / tentative de réfutation
La duplication de certains tests entre domaines et CI complète augmente le coût compute. Cette duplication est acceptée tant qu'elle apporte une meilleure détection/localisation des régressions ; elle devra être mesurée avant toute simplification.

## Décision
Toute optimisation future de la CI doit préserver la couverture réellement démontrée. Une suppression de test ou de workflow doit être justifiée par une preuve de couverture équivalente ou meilleure.

## Dépendances impactées
Workflows GitHub, scripts de build/test, temps de feedback développeur, observabilité des régressions.

## Risques
- Duplication et coût de runners.
- Divergence des listes de tests entre domaines et suite complète.
- Faux sentiment de couverture si un domaine ne contient pas les tests attendus.

## Tests et métriques
- Durée totale et durée avant premier diagnostic utile.
- Nombre de domaines rouges par régression.
- Flakiness par job.
- Écart de couverture entre CI de domaines et CI monolithique.
- Nombre de runs obsolètes annulés.

## Valeur joueur
Indirecte : moins de régressions et cycles de correction plus courts permettent de préserver plus vite les comportements validés du jeu.

## Réversibilité / plan de retour arrière
Les jobs de domaines sont une couche additive : ils peuvent être modifiés ou retirés sans retirer la CI monolithique tant que celle-ci reste le filet de sécurité.

## Conditions de réexamen
Lorsque les métriques montrent un coût disproportionné, lorsque la couverture devient strictement équivalente ailleurs, ou lorsque l'architecture du dépôt change suffisamment pour rendre les cinq domaines obsolètes.

## Relations Knowledge Graph
- depends_on: méthode d'ingénierie LITD
- influences: vitesse de diagnostic, qualité, observabilité, coût CI
- validated_by: PR #253, PR #257, PR #242
- tested_by: workflows GitHub Actions
- measured_by: durée CI, taux d'échec, flakiness, couverture par domaine
