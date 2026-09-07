# LITD : Les Veilleurs — handoff Godot mémoire du Refuge v1

## Statut

Ce document décrit une **implémentation candidate post-playtest**. Les classes compilent et possèdent des smokes dédiés, mais elles ne doivent pas être enregistrées comme autoload ni référencées par les contrats actifs avant validation du playtest PC de la PR #173.

Référence actuelle : `post_playtest_detail_manifest_v1.json` **v8**.

Classes candidates :

- `VeilleursRefugeMemoryServiceCandidate`
- `VeilleursRefugeMemoryMigrationAuditCandidate`
- `VeilleursRefugeMemoryProjectionAdapterCandidate`
- `VeilleursAuxiliaryReactionResolverCandidate`
- `VeilleursPostPlaytestFeatureFlagsCandidate`
- `VeilleursMultiActArchiveVisualFixtureCandidate`

## 1. Responsabilités

### VeilleursRefugeMemoryServiceCandidate

Le service est propriétaire uniquement de la planification et de l'état de ses souvenirs : création, fenêtre temporelle en nombre d'expéditions, éligibilité, file, apparition, résolution, expiration, sérialisation et migration.

Il **n'est pas propriétaire** de la vérité des Archives, des rangs de connaissance, de la Rémanence, du recrutement, des blessures persistantes, des valeurs d'équilibrage ni des scènes du Refuge.

Il demande les écritures aux propriétaires existants via `archive_hook_requested` et `remanence_hook_requested`.

### VeilleursRefugeMemoryMigrationAuditCandidate

Cette couche audite le payload avant désérialisation puis préserve les normalisations importantes dans `migration_log`. Un état invalide ramené à `DORMANT` conserve explicitement `memory_id`, `old_state`, `new_state` et le code `invalid_state_reset_to_DORMANT`.

Le journal est idempotent : recharger un payload déjà normalisé ne duplique pas le même avertissement.

### VeilleursAuxiliaryReactionResolverCandidate

Le résolveur détermine quels auxiliaires individuels peuvent réagir à un événement, à partir de leur `entity_id`, de leur historique vécu et de leur implication précise. Il ne génère aucune réplique et ne déduit aucune personnalité de l'espèce.

### VeilleursMultiActArchiveVisualFixtureCandidate

Le présentateur charge les huit fixtures Archives multi-actes et peut produire une vue structurelle pour téléphone, tablette, PC ou manette. Il ne génère aucun texte canonique et ne change jamais l'état de connaissance fourni par les Archives.

## 2. Intégration prévue dans VeilleursContentRuntime

Après validation PC uniquement :

1. créer une instance du service mémoire lors de l'initialisation de `VeilleursContentRuntime` ;
2. connecter `archive_hook_requested` à un adaptateur qui appelle `record_archive_hook()` ;
3. connecter `remanence_hook_requested` au `VeilleursRuntimeCoordinator` / `VeilleursRemanencePolicy` ;
4. ne jamais écrire directement dans `archive_entries` ou les données Rémanence depuis le service ;
5. ajouter la racine `veilleurs_refuge_memory` au dictionnaire retourné par `VeilleursContentRuntime.serialize()` ;
6. transmettre cette racine à la couche migration/audit puis au service pendant `VeilleursContentRuntime.deserialize()` ;
7. appeler `service.reset()` depuis `VeilleursContentRuntime.reset()`.

Le runtime existant expose déjà `record_archive_hook()`, `serialize()`, `deserialize()`, `reset()` et `refuge_changed`, donc aucune seconde infrastructure globale n'est nécessaire.

## 3. Cycle d'un souvenir

Cycle candidat : `DORMANT → ELIGIBLE → QUEUED → SURFACED → RESOLVED → RETIRED`.

Branche d'expiration : `DORMANT/ELIGIBLE/QUEUED → EXPIRED → RETIRED`.

Un souvenir ne peut jamais apparaître directement depuis DORMANT. Une histoire source doit avoir été écrite et les conditions observables doivent être satisfaites.

## 4. Arbitrage

Ordre candidat : crise → corps/disponibilité → relation/départ → découverte/Archives → routine/travail.

À priorité identique : urgence → ancienneté → clé déterministe SHA-256.

La proposition actuelle autorise au maximum **2 souvenirs surfacés par retour**. Cette valeur n'est pas canonique et doit être mesurée en playtest.

Le même événement source possède un cooldown candidat de deux expéditions. La même famille possède un cooldown doux d'une expédition : elle est dépriorisée, jamais effacée.

Six profils candidats existent dans `refuge_memory_arbitration_variants_v1.json`, mais `active_profile` reste `none` avant playtest PC.

## 5. Sauvegarde, migration et audit

Racine candidate : `veilleurs_refuge_memory`.

Le payload contient uniquement seed, index d'expédition, index de retour, séquence, enregistrements mémoire, ordre de file, souvenir actuellement surfacé, cooldowns et journal de migration. Aucun NodePath, snapshot de scène ou horloge réelle.

Le corpus `refuge_memory_migration_corpus_v1.json` couvre 16 cas et un schéma futur inconnu est refusé.

Le smoke `veilleurs_refuge_memory_migration_audit_candidate_smoke.tscn` vérifie qu'un état invalide devient `DORMANT` **et** laisse une trace explicite dans `migration_log`, puis qu'un second chargement ne duplique pas cet avertissement.

## 6. Feature flags et rollback

Tous les flags post-playtest restent `false` avant validation PC.

`post_playtest_feature_flag_rollback_scenarios_v1.json` définit huit scénarios. Principe : **rollback d'exécution ≠ rollback de l'histoire**.

Désactiver un flag stoppe les nouvelles exécutions de la couche mais ne supprime aucun record mémoire, ne modifie ni `memory_id` ni `deterministic_tiebreak`, ne rétrograde pas la connaissance Archives, ne répare pas une blessure réelle, ne supprime pas une cicatrice du monde et ne rétrograde pas un rang de Rémanence déjà acquis.

Le smoke `veilleurs_post_playtest_feature_flag_rollback_candidate_smoke.tscn` crée réellement un historique, désactive les flags, vérifie une sérialisation mémoire identique, puis réactive le maître + mémoire et confirme les mêmes IDs et tiebreaks.

## 7. Archives et fixtures visuelles

Le service n'a jamais le droit d'augmenter seul `UNKNOWN/SUSPECTED/OBSERVED/CONFIRMED/UNDERSTOOD`. Seul le runtime Archives applique un changement de connaissance si de nouvelles preuves l'autorisent.

`multi_act_archive_visual_fixtures_v1.json` contient huit fixtures correspondant exactement aux huit chaînes de `multi_act_archive_projection_v1.json`.

Chaque fixture fixe sections visibles, ordre/type des cartes, badges de provenance/certitude, assertions visuelles et profil téléphone/tablette/PC/manette.

Contraintes : cibles tactiles ≥48 pt, aucun long press requis, aucun hover requis, aucune dépendance au pointeur pour la manette, versions contradictoires non fusionnées, cicatrice physique seulement si elle existe, même `entity_id` pour l'histoire Rémanente, état de connaissance courant préservé.

Le smoke `veilleurs_multi_act_archive_visual_fixture_candidate_smoke.tscn` parcourt 8 chaînes × 4 profils.

## 8. Rémanence

Une demande Rémanence n'est émise que si le souvenir possède un `remanence_link`, la résolution fournit `shared_lived_history=true` et un `entity_id` stable existe.

L'adaptateur ne transmet vers `note_enemy_memory_event()` qu'un événement canonique vécu, avec preuve non vide et `evidence_verified=true`. Il ne peut ni promouvoir automatiquement une entité ni créer une Némésis.

## 9. Auxiliaires individuels

Un auxiliaire peut réagir seulement s'il possède un `entity_id` stable, un `identity_seed` et une implication individuelle : participation, observation, histoire partagée ou conséquence matérielle.

Deux individus de la même espèce peuvent donc avoir des réactions différentes en fonction de leur histoire.

## 10. Chaînes multi-actes

`multi_act_consequence_chains_v1.json` définit 8 chaînes candidates. Une étape manquée ne bloque jamais la campagne. Aucune chaîne ne fournit de bonus caché et aucune Némésis n'est générée pour satisfaire une chaîne.

## 11. Tests déterministes

- Fixtures mémoire : 8 cas.
- Collisions : 8 cas.
- Corpus migrations : 16 cas.
- Rollbacks : 8 cas.
- Fixtures Archives : 8 chaînes × 4 profils.

Smokes Godot :

- `veilleurs_refuge_memory_service_candidate_smoke.tscn`
- `veilleurs_refuge_memory_migration_corpus_candidate_smoke.tscn`
- `veilleurs_refuge_memory_migration_audit_candidate_smoke.tscn`
- `veilleurs_post_playtest_feature_flag_rollback_candidate_smoke.tscn`
- `veilleurs_refuge_memory_projection_adapter_candidate_smoke.tscn`
- `veilleurs_auxiliary_reaction_resolver_candidate_smoke.tscn`
- `veilleurs_multi_act_archive_visual_fixture_candidate_smoke.tscn`

Ils sont lancés par `Remanence Smoke` sur la PR #180 mais ne sont utilisés par aucune scène de jeu.

## 12. Ordre d'activation après playtest

1. valider plafond/priorités/cooldowns ;
2. brancher le service derrière feature flag ;
3. valider save/load/migration + audit sur copies ;
4. valider rollback avec historique ;
5. brancher Archives et vérifier les fixtures ;
6. brancher Rémanence ;
7. brancher auxiliaires ;
8. activer une seule famille Refuge ;
9. playtest ;
10. seulement ensuite régional/multi-actes.

Aucune activation en masse avant validation de chaque étape.
