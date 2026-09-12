# Exercice mesuré de récupération de la gouvernance globale

Ce lot exécute un exercice isolé reproductible du protocole de récupération P0. Il génère une chaîne de ledger réelle dans l'espace temporaire du runner, provoque huit attaques distinctes, vérifie leur blocage, produit un reçu du recovery gate et conserve tous les artefacts avec leurs hashes.

## Classification obligatoire

Le résultat est toujours `TABLETOP_ONLY`. Il mesure le comportement du protocole et des détecteurs, mais ne prétend jamais prouver :

- la révocation de vrais secrets ou de vraies identités de service ;
- la restauration d'un ledger de production ;
- deux approbations humaines authentifiées ;
- une autorisation de reprise ;
- la fermeture de #315.

Le fichier `measurement.json` fixe ces cinq affirmations à `false` et liste les preuves externes encore requises.

## Exécution

```bash
python tools/quality/run_global_governance_recovery_drill.py \
  --source-sha <sha-exact-de-40-caracteres>
```

Les preuves sont écrites dans `reports/global-governance-recovery-drill/`. Le workflow dédié les conserve pendant 90 jours. Il possède uniquement `contents: read`, désactive la persistance des credentials Git et ne dispose d'aucun accès aux Cores, secrets ou infrastructures réelles.

## Condition de clôture P0

Un exercice vert constitue une mesure de tabletop, pas une certification de récupération de production. #315 reste ouvert jusqu'à la rotation réelle et isolée des identités, la restauration vérifiée du ledger réel, deux revues humaines authentifiées et des décisions de reprise séparées pour chaque projet.
