# Research Record — Méthode d’ingénierie LITD / PR #254

- ID: RR-0006
- Date: 2026-09-10
- Domaine: engineering / CI / quality
- Question: La méthode d’ingénierie de la PR #254 peut-elle être considérée comme référence active ?
- Niveau: R0
- Statut: revalidate
- Confiance: high

## Qui ? Quoi ? Où ? Pourquoi ? Comment ?

- Qui : équipe LITD.
- Quoi : méthode standard de développement, tests, CI et Definition of Done.
- Où : PR #254, `docs/engineering/working-method.md`.
- Pourquoi : conserver une doctrine technique cohérente sans confondre document proposé et référence fusionnée.
- Comment : contrôle de la PR et comparaison avec les pratiques déjà réellement intégrées au dépôt.

## Sources

- PR #254 : ouverte, non fusionnée, un fichier documentaire.
- `working-method.md` : cycle spec → invariants → petit changement → test proche → CI ciblée → intégration → E2E → merge si preuve et CI verte ; pyramide L0–L4 ; déterminisme ; architecture data-driven ; budgets de performance ; Definition of Done.
- Des éléments de cette doctrine sont déjà corroborés par des décisions fusionnées, notamment la CI par domaines et le Guardian progressif.

## Résultats concordants

Le contenu est cohérent avec l’architecture actuelle et formalise correctement plusieurs pratiques déjà adoptées.

## Contradictions / limites

La PR elle-même n’est pas fusionnée. Elle ne doit donc pas être citée comme unique autorité active, même si plusieurs sous-principes sont déjà établis ailleurs.

## Recherche opposée

Tentative de promotion : cohérence forte avec les pratiques actuelles. Contre-preuve : statut ouvert et absence d’intégration sur `main`.

## Ce qui est vérifié dans LITD

- CI par domaines déjà validée séparément ;
- Guardian progressif déjà intégré ;
- doctrine de petits changements, preuves et non-masquage cohérente avec les règles actuelles.

## Conditions de promotion

Promouvoir le document comme référence active après relecture contre l’état courant du dépôt, correction d’éventuels écarts, CI documentaire/Knowledge Guardian verte et fusion sur `main`.

## Relations Knowledge Graph

- source_for: engineering-working-method
- validated_by: future-pr254-merge
- influences: definition-of-done, ci-strategy, testing-pyramid
