# LITD : Les Veilleurs — handoff Godot mémoire du Refuge v1

## Statut

Ce document décrit une **implémentation candidate post-playtest**. Les classes compilent et possèdent des smokes dédiés, mais elles ne doivent pas être enregistrées comme autoload ni référencées par les contrats actifs avant validation du playtest PC de la PR #173.

Classes candidates :

- `VeilleursRefugeMemoryServiceCandidate`
- `VeilleursAuxiliaryReactionResolverCandidate`

## 1. Responsabilités

### VeilleursRefugeMemoryServiceCandidate

Le service est propriétaire uniquement de la planification et de l'état de ses souvenirs : création, fenêtre temporelle en nombre d'expéditions, éligibilité, file, apparition, résolution, expiration, sérialisation et migration.

Il **n'est pas propriétaire** :

- de la vérité des Archives ;
- des rangs de connaissance ;
- de la Rémanence ;
- du recrutement ;
- des blessures persistantes ;
- des valeurs d'équilibrage ;
- des scènes du Refuge.

Il demande les écritures aux propriétaires existants via `archive_hook_requested` et `remanence_hook_requested`.

### VeilleursAuxiliaryReactionResolverCandidate

Le résolveur détermine quels auxiliaires individuels peuvent réagir à un événement, à partir de leur `entity_id`, de leur historique vécu et de leur implication précise. Il ne génère aucune réplique et ne déduit aucune personnalité de l'espèce.

## 2. Intégration prévue dans VeilleursContentRuntime

Après validation PC uniquement :

1. créer une instance du service mémoire lors de l'initialisation de `VeilleursContentRuntime` ;
2. connecter `archive_hook_requested` à un adaptateur qui appelle `record_archive_hook()` ;
3. connecter `remanence_hook_requested` au `VeilleursRuntimeCoordinator` / `VeilleursRemanencePolicy` ;
4. ne jamais écrire directement dans `archive_entries` ou les données Rémanence depuis le service ;
5. ajouter la racine `veilleurs_refuge_memory` au dictionnaire retourné par `VeilleursContentRuntime.serialize()` ;
6. transmettre cette racine à `service.deserialize()` pendant `VeilleursContentRuntime.deserialize()` ;
7. appeler `service.reset()` depuis `VeilleursContentRuntime.reset()`.

Le runtime existant expose déjà `record_archive_hook()`, `serialize()`, `deserialize()`, `reset()` et `refuge_changed`, donc aucune seconde infrastructure globale n'est nécessaire.

## 3. Cycle d'un souvenir

Cycle candidat :

`DORMANT → ELIGIBLE → QUEUED → SURFACED → RESOLVED → RETIRED`

Branche d'expiration :

`DORMANT/ELIGIBLE/QUEUED → EXPIRED → RETIRED`

Un souvenir ne peut jamais apparaître directement depuis DORMANT. Une histoire source doit avoir été écrite et les conditions observables doivent être satisfaites.

`confirm_projection_committed(memory_id)` fait passer RESOLVED ou EXPIRED vers RETIRED uniquement après confirmation que les propriétaires Archives/Rémanence ont traité les demandes d'écriture.

## 4. Arbitrage

Ordre candidat :

1. crise ;
2. corps/disponibilité ;
3. relation/départ ;
4. découverte/Archives ;
5. routine/travail.

À priorité identique : urgence → ancienneté → clé déterministe SHA-256.

La proposition actuelle autorise au maximum **2 souvenirs surfacés par retour**. Cette valeur n'est pas canonique et doit être mesurée en playtest.

Le même événement source possède un cooldown candidat de deux expéditions. La même famille possède un cooldown doux d'une expédition : elle est dépriorisée, jamais effacée.

La file sélectionnée et les clés de départage sont sauvegardées. Recharger ne reroll donc pas le Refuge.

## 5. Sauvegarde

Racine candidate :

`veilleurs_refuge_memory`

Schéma : `refuge_memory_save_schema_v1.json`, version 1.

Le payload contient uniquement : seed, index d'expédition, index de retour, séquence, enregistrements mémoire, ordre de file, souvenir actuellement surfacé, cooldowns et journal de migration.

Interdits : NodePath, snapshot de scène, horloge réelle comme source temporelle, connaissance cachée, vérité de phase boss.

### Migration

- sauvegarde sans racine mémoire : initialise un état v1 vide ;
- payload v0/non versionné : normalise les champs manquants sans réouvrir RESOLVED/EXPIRED ;
- schema futur > 1 : refuse la mutation avec rapport `future_schema_unsupported`.

La migration doit rester idempotente.

## 6. Signaux Godot

Le service émet :

- `memory_recorded`
- `memory_became_eligible`
- `memory_queued`
- `memory_surfaced`
- `memory_resolved`
- `memory_expired`
- `scheduler_changed`
- `archive_hook_requested`
- `remanence_hook_requested`

Le résolveur auxiliaire n'a besoin d'aucun signal global : il reçoit un snapshot d'auxiliaire et un contexte d'événement puis renvoie une décision pure.

## 7. Archives

Une résolution peut demander un hook `refuge_memory_resolved` avec :

- `memory_id` ;
- événement source ;
- choix ;
- lien d'Archive ;
- canaux d'écriture ;
- résolution ;
- preuves vécues.

Le service n'a jamais le droit d'augmenter seul `UNKNOWN/SUSPECTED/OBSERVED/CONFIRMED/UNDERSTOOD`. Seul le runtime Archives applique un changement de connaissance si de nouvelles preuves l'autorisent.

## 8. Rémanence

Une demande Rémanence n'est émise que si :

- le souvenir possède un `remanence_link` ;
- la résolution fournit `shared_lived_history=true` ;
- un `entity_id` stable existe.

Cette demande ne peut ni promouvoir automatiquement une entité ni créer une Némésis. Le `VeilleursRemanencePolicy` reste propriétaire de ces décisions.

## 9. Auxiliaires individuels

Un auxiliaire peut réagir seulement s'il possède :

- un `entity_id` stable ;
- un `identity_seed` ;
- une implication individuelle : participation, observation, histoire partagée ou conséquence matérielle.

Le contexte utilise des listes d'IDs (`direct_participants`, `direct_observers`, `materially_affected_entities`, `shared_history_entities`) afin qu'un booléen collectif ne rende pas automatiquement tous les auxiliaires admissibles.

Deux Déliés Affamés différents peuvent donc avoir des réactions totalement différentes en fonction de leur histoire.

## 10. Chaînes multi-actes

`multi_act_consequence_chains_v1.json` définit 8 chaînes candidates. Elles peuvent préserver :

- versions concurrentes ;
- référentiels de route ;
- méthodes de coordination ;
- preuves corporelles ;
- apprentissages de terrain ;
- usage de la lumière comme référentiel local ;
- importance du contexte face aux copies ;
- histoire partagée avec une entité de Rémanence.

Une étape manquée ne bloque jamais la campagne. Aucune chaîne ne fournit de bonus caché et aucune Némésis n'est générée pour satisfaire une chaîne.

## 11. Tests déterministes

Fixtures : `refuge_memory_fixtures_v1.json` — 8 cas.

Collisions : `refuge_memory_collision_scenarios_v1.json` — 8 cas.

Smokes Godot :

- `veilleurs_refuge_memory_service_candidate_smoke.tscn`
- `veilleurs_auxiliary_reaction_resolver_candidate_smoke.tscn`

Ils sont lancés par `Remanence Smoke` sur la PR #180 mais ne sont utilisés par aucune scène de jeu.

## 12. Ordre d'activation après playtest

1. valider le plafond de rappels par retour ;
2. valider les priorités/cooldowns ;
3. brancher le service à `VeilleursContentRuntime` derrière un feature flag ;
4. valider save/load/migration sur copies de sauvegardes ;
5. brancher les requêtes Archives ;
6. brancher les requêtes Rémanence ;
7. brancher le résolveur d'auxiliaires ;
8. activer une seule famille d'événements Refuge ;
9. playtest ;
10. seulement ensuite étendre aux événements régionaux et chaînes multi-actes.

Aucune activation en masse avant validation de chaque étape.
