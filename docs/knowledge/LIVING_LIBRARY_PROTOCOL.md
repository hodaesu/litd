# LITD — Living Library Protocol

## But

Faire de `docs/knowledge/` une mémoire de production active : chaque recherche, décision, incident, test et retour joueur important doit pouvoir modifier le Core, l'implémentation ou une question de recherche, avec une preuve et une date de revalidation.

## Chaîne canonique

`Source -> Connaissance -> Hypothèse -> Décision -> Core -> Implémentation -> Test -> Mesure -> Preuve -> Réévaluation`

Une étape peut être sautée uniquement si elle n'est pas pertinente ; la raison doit alors être explicite.

## Quand créer une entrée

Créer ou mettre à jour une entrée quand un changement :

- modifie un invariant, un pilier, une règle de gameplay ou une convention technique ;
- résout un incident susceptible de se reproduire ;
- repose sur une recherche externe non triviale ;
- révèle une contradiction entre documentation, données, code, test ou expérience joueur ;
- invalide ou remplace une connaissance active ;
- produit une mesure qui change une décision.

## Métadonnées minimales

Toute nouvelle connaissance durable doit identifier :

- `status`: active, experimental, revalidate, superseded, obsolete ou rejected ;
- `confidence`: low, medium, high ou very_high ;
- `domain` ;
- `date` ;
- `revalidate_when` ou `revalidate_on` ;
- sources/preuves ;
- relations utiles (`depends_on`, `contradicts`, `supersedes`, `validated_by`, `tested_by`, `measured_by`, `player_impact`).

## Règle Core

Une recherche ne modifie jamais directement le Core. Elle produit d'abord une hypothèse ou une décision explicite. Une décision qui touche un invariant doit :

1. citer ses preuves ;
2. rechercher une contre-preuve ou une hypothèse concurrente ;
3. identifier les dépendances ;
4. définir le test ou la mesure de validation ;
5. prévoir la réversibilité ;
6. mettre à jour les contrats/tests automatisables concernés.

## Incidents

Tout incident significatif doit conserver : symptôme, portée, cause racine, correction, preuve de correction, prévention et connaissance affectée. Une correction sans cause racine connue reste `experimental` ou `revalidate`.

## Réévaluation

Une entrée doit passer à `revalidate` lorsque :

- une dépendance majeure change ;
- une version moteur/outillage rend la preuve ancienne fragile ;
- un playtest ou une mesure contredit l'hypothèse ;
- le Core qu'elle supporte change ;
- sa condition/date de revalidation est atteinte.

Une entrée remplacée devient `superseded` et pointe vers son successeur ; elle n'est pas supprimée si elle explique l'historique d'une décision.

## Definition of Done — changement significatif

Un changement n'est réellement terminé que si :

- le code/donnée/document canonique est à jour ;
- le test adapté est passé ;
- la preuve est conservée ou référencée ;
- la connaissance/ADR/incident concerné est mis à jour ;
- les dépendances impactées ont été vérifiées ;
- aucune contradiction connue n'est laissée silencieuse.

## Entretien

À chaque cycle de travail, préférer enrichir une entrée existante à créer un doublon. Les recherches génériques restent dans `docs/research/`; les décisions durables dans `docs/knowledge/decisions/`; les incidents dans `docs/knowledge/incidents/`. Le Guardian doit progressivement convertir les invariants objectivables en validations exécutables.
