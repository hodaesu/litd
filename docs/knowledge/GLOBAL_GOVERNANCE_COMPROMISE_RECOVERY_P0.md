# Procédure P0 — compromission totale de la gouvernance globale

Cette procédure s’applique si le Veilleur, le Guardian global, le ledger, un runner, une identité de workflow ou un secret de gouvernance est compromis ou raisonnablement suspecté.

## Principe

La gouvernance globale est une racine procédurale, jamais une autorité de reprise automatique. Une compromission globale ne doit pas pouvoir écrire dans un Core, réactiver un worker, restaurer un secret ou propager une décision entre projets.

## Séquence obligatoire

1. **Détecter et déclarer** un incident `CRITICAL`, horodaté, avec composants et projets potentiellement affectés.
2. **Geler** tous les Veilleurs, workers, cron, files de travaux et workflows disposant d’une capacité de mutation.
3. **Révoquer** tokens, clés OIDC, secrets, sessions, deploy keys et identités de service concernés. Ne jamais réutiliser un secret compromis.
4. **Préserver** les journaux en lecture seule. Ne jamais réécrire ni « nettoyer » le ledger suspect.
5. **Choisir une référence fiable** antérieure à l’incident : commit signé/audité, checkpoint de provenance et copie immuable du ledger.
6. **Reconstruire en environnement isolé**, avec de nouvelles identités et aucun accès en écriture aux Cores réels.
7. **Vérifier le ledger restauré** : chaîne complète, checkpoint, scan de replay, absence de rupture ou de substitution.
8. **Relancer les huit tests adversariaux** : source compromise, ledger altéré, replay, substitution de hash, SHA obsolète, changement de cible, mauvaise route et bypass.
9. **Faire statuer chaque Guardian local**. Chaque projet peut refuser la reprise globale. Un seul `ORANGE` ou `RED` bloque l’ensemble.
10. **Faire examiner les preuves par deux personnes distinctes** au minimum.
11. **Produire le reçu du recovery gate**. Le statut maximal est `READY_FOR_SEPARATE_HUMAN_RESUME_DECISION`.
12. **Décider la reprise séparément**, humainement, projet par projet, avec réactivation graduelle et surveillance renforcée.

## Interdictions permanentes

- aucune reprise automatique ;
- aucune restauration automatique des secrets ;
- aucune fusion ou écriture Core par le recovery gate ;
- aucune propagation trans-projets ;
- aucune suppression des preuves compromises ;
- aucune confiance accordée au seul fait que la CI est verte.

## Retour arrière

Si une vérification échoue après reprise, regeler immédiatement les composants réactivés, révoquer les nouvelles identités concernées, conserver les nouvelles preuves et revenir à la dernière référence fiable. Le rollback technique ne vaut jamais décision de reprise.

Le validateur exécutable est `tools/quality/global_governance_recovery_gate.py`.
