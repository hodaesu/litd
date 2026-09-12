# Guardian Change Gate

Le Guardian Change Gate reçoit uniquement un reçu `LITD_CHANGE_CANDIDATE_APPROVED_PENDING_GUARDIAN` issu de la résolution gouvernée du Veilleur.

## But

Transformer une proposition LITD en décision bornée et traçable :

- `REJECT_CHANGE` → arrêt ;
- `REQUEST_MORE_EVIDENCE` → retour au cycle de preuve ;
- `ACCEPT_FOR_IMPLEMENTATION` → création d'un plan `READY_FOR_BOUNDED_IMPLEMENTATION_PR`.

L'acceptation n'applique jamais le changement. Elle autorise uniquement la préparation d'une PR d'implémentation séparée.

## Contenu obligatoire du plan accepté

- résumé du changement ;
- valeur joueur ;
- valeur technique ;
- risque ;
- réversibilité ;
- chemins autorisés ;
- tests obligatoires ;
- plan de rollback ;
- références de preuves.

## Frontières d'autorité

Le gate impose :

- `core_write_allowed=false` ;
- `automatic_code_write_allowed=false` ;
- `automatic_merge_allowed=false` ;
- `automatic_target_change_allowed=false` ;
- tests verts avant toute application ;
- preuve de rollback ;
- changement d'implémentation dans une PR séparée.

Les cibles canoniques, règles Guardian et baseline de dérive ne peuvent pas être modifiées via ce chemin. Elles restent sous leurs gouvernances dédiées.

## Chaîne complète

Veilleur → revue → résolution gouvernée → Guardian Change Gate → PR d'implémentation bornée → tests → mesures → décision d'application → provenance → signature/checkpoint.
