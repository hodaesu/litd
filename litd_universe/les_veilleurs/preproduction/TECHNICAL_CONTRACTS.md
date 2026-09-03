# LITD : Les Veilleurs — Contrats techniques V2

## Principe d'import

Ne jamais imposer au référentiel maître des champs qu'il ne possède pas. Séparer :

1. **SourceRecord** — reproduction fidèle des colonnes du classeur canonique.
2. **RuntimeDefinition** — structure Godot enrichie par normalisation, dérivation et données supplémentaires explicitement validées.

Une donnée runtime absente de la source doit être marquée `derived`, `defaulted` ou `author_required`; elle ne doit jamais être présentée comme une valeur récupérée.

## Couches

DEFINITIONS : données immuables de contenu.
RUNTIME STATE : état de campagne mutable.
SYSTEMS : logique pure et services.
PRESENTATION : UI, animation, FX, audio.
PERSISTENCE : sérialisation, migration, intégrité.

Aucun écran ne décide directement d'une règle de gameplay.

## IDs

IDs stables, ASCII et indépendants du texte affiché. Ne jamais sauvegarder un `display_name` comme clé métier.

Les IDs historiques des tables sources peuvent contenir accents/espaces. À l'import : conserver `source_id` tel quel et générer un `runtime_id` ASCII stable via une table de correspondance versionnée ; ne jamais régénérer ce mapping à chaque lancement.

## SourceAbilityRecord — colonnes canoniques Veilleurs

La feuille `Compétences_180` fournit exactement :

ID; Veilleur; Arbre; Niveau; Nom; Type; Fonction; Positions; Cible; Impacts; Zones privilégiées; Puissance qual.; Puissance 0-5; Précision qual.; Précision base %; Lésions possibles; Conséquences fonctionnelles; Démembrement; Interaction armure; Interaction environnement; Risque utilisateur; Tags; Cooldown; Charges; Conditions; Variante si blessé; Variante équipement; Note Godot.

Le premier importeur doit accepter ces colonnes sans exiger `PREP`, `REC`, coût d'endurance, coût matériel ou autres champs provenant d'anciens templates.

## RuntimeAbilityDefinition

Champs minimaux dérivables/normalisables :

runtime_id; source_id; owner_id; tree_id; unlock_level; slot_index; display_name; action_type; function_text; valid_positions; target_rule; impact_tags[]; preferred_zones[]; qualitative_power; source_power_0_5; qualitative_precision; source_precision_percent; lesion_rules; functional_consequences; dismemberment_rule; armor_interaction; environment_interaction; user_risk; tags[]; cooldown_rule; charges_rule; conditions; injured_variant; equipment_variant; godot_note; provenance.

Champs runtime supplémentaires possibles : required_body_functions[], forbidden_body_states[], sensory_emission, animation_intent, normalized_costs. Ils sont **enrichissements** et doivent avoir une provenance distincte.

Validation : exactement 15 compétences normales par arbre ; niveau/slot cohérents ; source_id unique ; runtime_id unique ; propriétaire/arbre résolus ; toute compétence physique conserve impacts, zones, lésions, armure et environnement de la source.

## SourceUltimateRecord

La feuille `Ultimes_12` fournit :

Veilleur; Arbre; Ultime; Mécanique; Charges; Limite combat; Condition; Puissance; Garde-fou; Beat 1; Beat 2; Beat 3; Beat 4; Beat 5; Beat 6; Beat 7; Beat 8.

Ne pas réduire ces 8 beats à cinq champs lors de l'import.

Baseline source : N16=1 / N32=2 / N48=3 ; une activation maximum du même ultime par rencontre ; pas d'invulnérabilité ni résurrection.

## RuntimeUltimateDefinition

runtime_id; owner_id; tree_id; display_name; mechanic; charge_progression; encounter_limit; conditions; qualitative_power; safeguard; beats[8]; body_requirements[]; normalized_systemic_effects; provenance.

Les règles corporelles supplémentaires viennent du moteur systémique, pas d'une réécriture du texte source.

## Anatomie

AnatomyDefinition : id, family, parts[], vital_functions[], locomotion_model, manipulation_model, sensory_organs[], special_structures[].

BodyPartDefinition : id, parent, functions[], tissue_tags[], vital_tags[], severable, armor_slots[], locomotion_weight, manipulation_weight.

BodyPartState : part_id, present, functionality, injuries[], protection_state, replacements[], adaptations[].

Familles minimales nécessaires au roster actuel : humanoïde, humanoïde altéré, quadrupède, quadrupède massif, construct/minéral, serpentin organique, amorphe organique, insectoïde végétal-organique, humanoïde cendreux, amorphe de version, construct humanoïde/de version. Les anatomies non verrouillées des boss restent `author_required`, jamais déduites arbitrairement.

## Impacts et lésions

Normalisation runtime initiale : BLUNT, CUTTING, PIERCING, TEARING, CRUSHING, THERMAL, CHEMICAL_BIOLOGICAL, PRESSURE_RESPIRATORY. Cette taxonomie sert au resolver mais ne doit pas écraser les chaînes source plus spécifiques.

Lésions runtime : CONTUSION, LACERATION, PUNCTURE, FRACTURE, DISLOCATION, MUSCLE_TENDON_RUPTURE, EXTERNAL_BLEEDING, INTERNAL_BLEEDING, BURN, CRUSH_INJURY, SEVERANCE, ORGAN_TRAUMA.

## Pipeline de résolution corporelle

ActionIntent -> TargetValidation -> Timeline/Preparation si applicable -> ContactResolution -> ArmorResolution -> TissueResolution -> LesionCreation -> FunctionalConsequences -> Bleeding/Pain/Respiration/Will -> DismembermentCheck -> Death/IncapacityCheck -> Recovery si applicable -> EventEmission -> Presentation.

Le démembrement exige anatomie sectionnable + impact compatible + état de zone + puissance + armure + autorisation de la compétence. Aucun proc de rareté ne crée un membre perdu.

## EquipmentDefinition

WeaponDefinition : id, grip_requirements[], body_function_requirements[], reach_profile, mass_class, attack_modes[], impact_types[], precision_profile, penetration_profile, durability_model, noise_profile, vibration_profile, environment_uses[], tags[].

ArmorDefinition : id, covered_zones[], material, rigidity, absorption_profile, deflection_profile, penetration_resistance, condition_model, mobility_cost, noise_profile, heat_or_breathing_effects, tags[].

## CharacterState

unique_id; definition_id; seed; level; xp; body_state; equipment_state; traits[]; current_conditions[]; relationship_refs[]; memory_refs[]; status; location_ref.

RecruitState courant : source_enemy_id; selected_tree_id; specialization_locked; refuge_assignment; rally_context; auxiliary_role; release_state. Ne pas imposer `orientation_id` du système legacy 25/75.

## RelationshipState

target_id; confidence; respect; fear; resentment; recent_trend; important_memory_refs[].

## MemoryEvent

id; type; participants[]; location_id; expedition_id; importance; emotional_tags[]; factual_tags[]; certainty; accuracy; created_at; last_recalled_at.

Mémoire bornée : fondatrice, significative, récente ; compression des répétitions autorisée sans perdre les événements structurants.

## SensoryEvent

id; source_id; position_or_zone; channel; intensity; tags[]; duration; environment_modifier; created_turn.

Canaux : VISUAL, NOISE, ODOR, VIBRATION, BIOLOGICAL ; cendre/particules via tags et médiums spécialisés.

SensoryMemory : source_hypothesis, estimated_location, certainty, interpretation, age, supporting_event_refs[].

## IA

Cycle : PERCEIVE -> UPDATE_BELIEFS -> ASSESS_SELF -> ASSESS_SITUATION -> SELECT_GOAL -> SELECT_ACTION -> EXECUTE -> LEARN_OR_REMEMBER.

Vigilance : UNAWARE, CURIOUS, SUSPICIOUS, SEARCHING, CONFIRMED, ENGAGED.

Volonté : COMPOSED, PRESSURED, SHAKEN, BREAKING, BROKEN.

Une IA n'utilise jamais une information qu'elle n'a ni perçue, ni reçue via un relais valide, ni mémorisée.

Les priorités IA spécifiques des actes II–V sont déjà dans le référentiel maître et doivent être importées avant génération de nouvelles heuristiques.

## Ralliement

RecruitmentDefinition : source_enemy_id, admissible, source_condition, auxiliary_role, body_state_requirements, knowledge_requirements, transport_requirements, provenance.

Capture et ralliement restent distincts ; blessures persistantes ; bosses non ralliables. Les conditions source sont prioritaires sur les anciennes règles 25/75.

## Cadavre

CorpseState : unique_id, original_character_id, source_enemy_id, location_ref, body_state_snapshot_ref, equipment_refs[], death_cause, decay_state, colonization_state, protection_state, memory_tags[].

Même identité de cadavre malgré déplacement/colonisation.

## ZoneScar

zone_id; scar_type; anchor_id; state; related_entities[]; created_expedition; persistence_rule.

## SaveGame

save_version; content_schema_version; canonical_pack_version; campaign; veilleur_states; recruit_registry; enemy_memory_registry; corpse_registry; refuge; knowledge; world_scars; narrative_flags; rng_state.

Autosave transactionnel A/B ; migration obligatoire des schémas.

## EventBus

CHARACTER_INJURED, BODY_PART_LOST, CHARACTER_DIED, CORPSE_CREATED, ENEMY_SURRENDERED, RECRUIT_JOINED, MEMORY_CREATED, RELATIONSHIP_CHANGED, KNOWLEDGE_DISCOVERED, REFUGE_EVENT_STARTED, ZONE_SCAR_CREATED, SENSORY_EVENT_EMITTED.

## RNG déterministe

Flux indépendants : WORLD, ENCOUNTER, INDIVIDUAL, LOOT, NARRATIVE. L'UI n'appelle jamais un RNG qui pourrait modifier une donnée persistante.

## Provenance obligatoire

Chaque définition importée doit pouvoir répondre à :

- de quel fichier/onglet vient-elle ?
- quel est son `source_id` ?
- quelle version du pack l'a produite ?
- quels champs ont été normalisés ?
- quels champs ont été enrichis après import ?

C'est le garde-fou principal contre une nouvelle divergence entre conversation, tableur et runtime Godot.
