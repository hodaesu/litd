# LITD : Les Veilleurs — Contrats techniques V1

## Couches

DEFINITIONS : données immuables de contenu.
RUNTIME STATE : état de campagne mutable.
SYSTEMS : logique pure et services.
PRESENTATION : UI, animation, FX, audio.
PERSISTENCE : sérialisation, migration, intégrité.

Aucun écran ne doit décider directement d'une règle de gameplay.

## IDs

Les IDs sont stables, ASCII et indépendants du texte affiché. Ne jamais sauvegarder un display_name comme clé métier.

Exemples : veilleur.v01, tree.v01.a, ability.v01.a.01, species.delie.rampant, orientation.delie.rampant.fouisseur.

## AbilityDefinition

Champs obligatoires :

id; owner_scope; tree_id; slot_index; display_name_key; description_key; action_type; targeting_mode; range_profile; required_body_functions[]; forbidden_body_states[]; impact_types[]; physical_power; precision; allowed_zones[]; preferred_zones[]; lesion_rules[]; functional_effects[]; dismemberment_eligibility; armor_interaction; environment_interaction; noise_profile; vibration_profile; biological_profile; user_risk; friendly_fire; prerequisites[]; synergy_tags[]; ai_tags[]; animation_intent; fx_tags[]; knowledge_reveal.

Validation : un arbre contient exactement 15 AbilityDefinition distinctes ; un UltimateDefinition séparé ; aucun ID dupliqué ; toutes les références résolues ; toute capacité offensive possède au moins un impact ou un effet systémique explicite ; toute capacité exigeant une partie du corps déclare ses fonctions requises.

## UltimateDefinition

id; tree_id; display_name_key; declaration_beat; commitment_beat; contact_or_phenomenon_beat; consequence_beat; aftermath_beat; body_requirements[]; target_rules; systemic_resolution; environment_hooks[]; failure_or_interruption_rules; animation_intent; audio_intent.

Un ultime ne contourne pas gratuitement géométrie, anatomie, armure ou environnement. Son nombre d'usages et son rythme exact restent PROTOTYPE.

## Anatomie

AnatomyDefinition : id, family, parts[], vital_functions[], locomotion_model, manipulation_model, sensory_organs[], special_structures[].

BodyPartDefinition : id, parent, functions[], tissue_tags[], vital_tags[], severable, armor_slots[], locomotion_weight, manipulation_weight.

BodyPartState : part_id, present, functionality, injuries[], protection_state, replacements[], adaptations[].

Familles minimales : humanoïde, quadrupède, arachnide, ailé, serpentin, massif, aberrant. Une espèce ne doit jamais être forcée dans un squelette humanoïde.

## Impacts et lésions

ImpactType V1 : BLUNT, CUTTING, PIERCING, TEARING, CRUSHING, THERMAL, CHEMICAL_BIOLOGICAL, PRESSURE_RESPIRATORY.

LesionType V1 : CONTUSION, LACERATION, PUNCTURE, FRACTURE, DISLOCATION, MUSCLE_TENDON_RUPTURE, EXTERNAL_BLEEDING, INTERNAL_BLEEDING, BURN, CRUSH_INJURY, SEVERANCE, ORGAN_TRAUMA.

Les lésions produisent d'abord des conséquences fonctionnelles. Les HP globaux peuvent exister comme abstraction de robustesse, mais ne doivent pas remplacer l'état du corps.

## Pipeline de résolution corporelle

ActionIntent -> TargetValidation -> ContactResolution -> ArmorResolution -> TissueResolution -> LesionCreation -> FunctionalConsequences -> Bleeding/Pain/Respiration/Will -> DismembermentCheck -> Death/IncapacityCheck -> EventEmission -> Presentation.

Le démembrement est autorisé uniquement si : anatomie severable + impact compatible + puissance/état de zone suffisant + armure ne bloque pas + règle de compétence autorise la conséquence. Aucun proc de rareté ne crée un membre perdu.

## EquipmentDefinition

WeaponDefinition : id, grip_requirements[], body_function_requirements[], reach_profile, mass_class, attack_modes[], impact_types[], precision_profile, penetration_profile, durability_model, noise_profile, vibration_profile, environment_uses[], tags[].

ArmorDefinition : id, covered_zones[], material, rigidity, absorption_profile, deflection_profile, penetration_resistance, condition_model, mobility_cost, noise_profile, heat_or_breathing_effects, tags[].

L'armure protège des zones concrètes et modifie aussi SPE, mobilité et respiration lorsque cohérent.

## CharacterState

unique_id; definition_id; seed; level; xp; body_state; equipment_state; traits[]; current_conditions[]; relationship_refs[]; memory_refs[]; status; location_ref.

RecruitState ajoute orientation_id, evolution_stage, refuge_assignment, rally_method, rally_context, release_state.

## RelationshipState

target_id; confidence; respect; fear; resentment; recent_trend; important_memory_refs[].

Le joueur voit des niveaux qualitatifs ; les valeurs internes exactes restent implémentation.

## MemoryEvent

id; type; participants[]; location_id; expedition_id; importance; emotional_tags[]; factual_tags[]; certainty; accuracy; created_at; last_recalled_at.

Importance : TRIVIAL, MINOR, SIGNIFICANT, MAJOR, FOUNDATIONAL.

Trois couches par individu : foundational, significant, recent. Compression permise pour les répétitions cohérentes.

## SensoryEvent

id; source_id; position_or_zone; channel; intensity; tags[]; duration; environment_modifier; created_turn.

Canaux : VISUAL, NOISE, ODOR, VIBRATION, BIOLOGICAL. Les perturbations particulaires utilisent tags/médium spécialisés.

SensoryMemory : source_hypothesis, estimated_location, certainty, interpretation, age, supporting_event_refs[].

## IA

Cycle : PERCEIVE -> UPDATE_BELIEFS -> ASSESS_SELF -> ASSESS_SITUATION -> SELECT_GOAL -> SELECT_ACTION -> EXECUTE -> LEARN_OR_REMEMBER.

Vigilance : UNAWARE, CURIOUS, SUSPICIOUS, SEARCHING, CONFIRMED, ENGAGED.

Volonté : COMPOSED, PRESSURED, SHAKEN, BREAKING, BROKEN.

Goals V1 : ATTACK, PROTECT, ESCAPE, INVESTIGATE, RALLY_ALLIES, HOLD_POSITION, SEEK_COVER, SURRENDER, RECOVER_BODY, BREAK_CONNECTION.

Une IA n'utilise jamais une information qu'elle n'a ni perçue, ni reçue d'un relais valide, ni mémorisée.

## Ralliement

RecruitmentDefinition : species_id, methods[], required_states[], forbidden_states[], knowledge_requirements[], anatomy_requirements[], special_conditions[], transport_requirements[], post_rally_requirements[].

Méthodes : SUBMISSION, SURRENDER, RESCUE, PACT, ACCLIMATION.

Ralliement et capture sont des états distincts. Les blessures persistent après ralliement.

## Cadavre

CorpseState : unique_id, original_character_id, species_id, location_ref, body_state_snapshot_ref, equipment_refs[], death_cause, decay_state, colonization_state, protection_state, memory_tags[].

Le cadavre reste le même objet narratif au travers des transformations de colonisation/déplacement.

## ZoneScar

zone_id; scar_type; anchor_id; state; related_entities[]; created_expedition; persistence_rule.

Types V1 : DOOR_DESTROYED, BODY_LEFT, BRIDGE_COLLAPSED, VEIN_GROWTH, ASH_SATURATION, OBJECT_REMOVED, MEMORIAL_EVENT.

## SaveGame

save_version; campaign; veilleur_states; recruit_registry; enemy_memory_registry; corpse_registry; refuge; knowledge; world_scars; narrative_flags; rng_state.

Autosave transactionnel A/B. Écrire -> valider intégrité -> basculer actif. Migration obligatoire entre versions de schéma.

## EventBus

Événements structurants : CHARACTER_INJURED, BODY_PART_LOST, CHARACTER_DIED, CORPSE_CREATED, ENEMY_SURRENDERED, RECRUIT_JOINED, MEMORY_CREATED, RELATIONSHIP_CHANGED, KNOWLEDGE_DISCOVERED, REFUGE_EVENT_STARTED, ZONE_SCAR_CREATED, SENSORY_EVENT_EMITTED.

Les systèmes réagissent aux événements plutôt que de se coupler directement.

## RNG déterministe

Flux indépendants : WORLD, ENCOUNTER, INDIVIDUAL, LOOT, NARRATIVE. Un appel RNG dans l'UI ou un système sans rapport ne doit jamais changer les traits persistants ou reroll un objet déjà créé.
