# LITD : Les Veilleurs — activation post-playtest v1

## Statut

Cette couche est **préparée mais inactive**. Elle appartient à la PR #180 en brouillon et ne doit pas modifier la version de playtest de la PR #173.

Aucun fichier de cette couche n'est autoloadé. Aucun contrat actif du playtest ne doit les référencer avant validation PC.

## 1. Feature flags

Source : `data/veilleurs/parallel_content/post_playtest_feature_flags_v1.json`.

Résolveur candidat : `VeilleursPostPlaytestFeatureFlagsCandidate`.

Le flag maître est `veilleurs.post_playtest.enabled`. Il est `false` par défaut, comme tous ses enfants. Une sauvegarde, une migration ou une donnée de contenu ne peut pas l'activer. Un override n'est accepté que par un appel explicitement autorisé développeur.

Ordre candidat : maître → mémoire du Refuge → projection Archives → projection Rémanence → réactions auxiliaires → échos régionaux → chaînes multi-actes. Les altérations d'expédition possèdent un flag séparé.

## 2. Rollback

Source : `post_playtest_feature_flag_rollback_scenarios_v1.json`.

Huit scénarios de rollback sont préparés. Désactiver un feature flag ne supprime jamais l'histoire déjà écrite. Le service cesse de produire de nouveaux rappels/projections, mais les Archives, blessures, traces et historiques déjà validés restent dans leurs systèmes propriétaires.

Rollback interdit : effacer une connaissance, réparer une blessure, supprimer une histoire de Rémanence, supprimer une cicatrice du monde, rétrograder un rang de Rémanence ou reroll une file de souvenirs simplement parce qu'un flag change.

Le smoke `veilleurs_post_playtest_feature_flag_rollback_candidate_smoke.tscn` vérifie le cas concret : historique créé → flags désactivés → sérialisation mémoire strictement identique → réactivation → mêmes `memory_id`, mêmes `deterministic_tiebreak`, aucune duplication.

## 3. Corpus de migrations

`refuge_memory_migration_corpus_v1.json` contient 16 cas : sauvegarde sans racine mémoire, payload v0/non versionné, v1 vide, file valide, références orphelines, entrée non QUEUED, souvenir SURFACED valide/invalide, état mémoire invalide, enregistrement malformé, RESOLVED/EXPIRED, schéma futur, limite de surface, cooldowns et idempotence.

Le smoke `veilleurs_refuge_memory_migration_corpus_candidate_smoke.tscn` exécute ce corpus dans Godot sans brancher le service au jeu.

### Audit explicite des normalisations

`VeilleursRefugeMemoryMigrationAuditCandidate` scanne le payload avant désérialisation et conserve dans `migration_log` les normalisations importantes.

Un état inconnu ramené à `DORMANT` produit explicitement `memory_id`, `warning = invalid_state_reset_to_DORMANT`, `old_state` et `new_state = DORMANT`.

Le smoke `veilleurs_refuge_memory_migration_audit_candidate_smoke.tscn` vérifie aussi l'idempotence : le même avertissement ne doit pas être dupliqué au rechargement suivant.

## 4. Variantes priorité / cooldown

`refuge_memory_arbitration_variants_v1.json` contient six profils candidats : conservateur, candidat actuel, relations prioritaires, Archives prioritaires, faible cooldown et conséquences fortes seulement.

**Aucun profil n'est actif.** Une comparaison doit conserver la même seed, le même build et le même snapshot de sauvegarde. Une seule famille de paramètres doit être modifiée à la fois autant que possible.

## 5. Projection Archives des huit chaînes multi-actes

Source : `multi_act_archive_projection_v1.json`.

Les huit chaînes sont couvertes exactement. Chaque étape exige que son `write` source existe déjà. Une projection peut ajouter de l'histoire sans augmenter la connaissance. Tout passage vers CONFIRMED ou UNDERSTOOD exige de nouvelles preuves compatibles avec les règles Archives existantes.

### Fixtures visuelles

`multi_act_archive_visual_fixtures_v1.json` contient huit fixtures, une par chaîne, avec quatre profils : téléphone, tablette, PC et manette.

`VeilleursMultiActArchiveVisualFixtureCandidate` transforme ces fixtures en vues structurelles QA sans inventer de texte canonique. Il conserve l'état de connaissance courant, expose les sections/cartes attendues et applique les contraintes : cible tactile ≥48 pt, pas de long press requis, pas de hover requis, pas de dépendance au pointeur pour la manette.

Le smoke `veilleurs_multi_act_archive_visual_fixture_candidate_smoke.tscn` parcourt les 8 chaînes × 4 profils et vérifie qu'aucune vue ne modifie l'état de connaissance ni ne génère de texte canonique.

## 6. Archives / Rémanence

L'adaptateur candidat reste borné : Archives via `VeilleursContentRuntime.record_archive_hook()` ; Rémanence en référence historique par défaut ; transmission à `VeilleursRuntimeCoordinator.note_enemy_memory_event()` seulement pour un événement canonique vécu, avec preuve non vide et `evidence_verified=true`.

Les rangs Mémoriel/Vétéran/Élite/Némésis restent la propriété de `VeilleursRemanencePolicy`.

## 7. Ordre d'activation après playtest PC

1. obtenir les résultats de la PR #173 ;
2. décider si le système mémoire mérite activation ;
3. activer uniquement le flag maître + mémoire du Refuge sur une branche de test ;
4. exécuter les 16 migrations sur copies de sauvegardes ;
5. vérifier le journal d'audit de migration ;
6. tester un rollback avec historique réel ;
7. tester un seul profil d'arbitrage ;
8. activer projection Archives ;
9. vérifier connaissance/incertitude et fixtures visuelles ;
10. activer projection Rémanence ;
11. vérifier qu'aucune promotion artificielle n'est possible ;
12. activer réactions auxiliaires ;
13. activer une seule famille Refuge ;
14. playtest ;
15. seulement ensuite régional puis multi-actes.

## 8. Gate

Avant toute activation dans une branche jouable : CI vert, Remanence Smoke vert, Tactical vert, Balance Telemetry vert, tous les flags `false` sur la branche de base, corpus migration vert, audit migration vert, rollback avec historique vert, fixtures Archives cohérentes, aucun autoload candidat, aucune référence depuis les contrats actifs, feedback PC documenté et rollback défini.

La PR #180 reste en brouillon tant que ces conditions d'activation n'ont pas été décidées après le playtest.
