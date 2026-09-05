extends RefCounted

const PROFILE_PATH := "res://data/veilleurs/enemy_production_profiles_24.json"

var payload: Dictionary = {}
var profiles_by_species: Dictionary = {}
var species_by_family: Dictionary = {}

func _init() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
    if not (parsed is Dictionary):
        return
    payload = parsed
    for value: Variant in payload.get("species", []):
        if not (value is Dictionary):
            continue
        var profile: Dictionary = (value as Dictionary).duplicate(true)
        var species := str(profile.get("species", ""))
        var family := str(profile.get("family", ""))
        if species == "" or family == "":
            continue
        profiles_by_species[species] = profile
        var members: Array = species_by_family.get(family, [])
        members.append(species)
        species_by_family[family] = members

func species_count() -> int:
    return profiles_by_species.size()

func family_count() -> int:
    return species_by_family.size()

func has_species(species: String) -> bool:
    return profiles_by_species.has(species)

func species_profile(species: String) -> Dictionary:
    return (profiles_by_species.get(species, {}) as Dictionary).duplicate(true)

func family_species(family: String) -> Array:
    return (species_by_family.get(family, []) as Array).duplicate()

func known_families() -> Array[String]:
    var result: Array[String] = []
    for key: Variant in species_by_family.keys():
        result.append(str(key))
    result.sort()
    return result

func variant_form(species: String, tier: String) -> Dictionary:
    var profile := species_profile(species)
    if profile.is_empty():
        return {"known": false, "species": species, "tier": tier, "form": "", "named_form_locked": false}
    var forms: Dictionary = profile.get("forms", {})
    var requested := tier if forms.has(tier) else "N1"
    var raw_form: Variant = forms.get(requested, null)
    var locked := bool(profile.get("named_forms_locked", false))
    var form_name := str(raw_form) if raw_form != null else ""
    if requested == "N1" and form_name == "":
        form_name = species
    return {
        "known": true,
        "species": species,
        "tier": requested,
        "form": form_name,
        "named_form_locked": locked,
        "uses_base_species_name": form_name == species,
        "unnamed_canonical_variant": requested != "N1" and form_name == ""
    }

func enrich_actor(actor: Dictionary, species: String, tier: String) -> Dictionary:
    var output := actor.duplicate(true)
    var profile := species_profile(species)
    if profile.is_empty():
        output["production_profile_missing"] = true
        return output
    var form := variant_form(species, tier)
    output["production_profile_missing"] = false
    output["production_profile_id"] = species
    output["species"] = species
    output["act_id"] = str(profile.get("act", ""))
    output["family"] = str(profile.get("family", ""))
    output["role"] = str(profile.get("role", ""))
    output["anatomy"] = str(profile.get("anatomy", ""))
    output["positions_contract"] = str(profile.get("positions", ""))
    output["skill_trees"] = (profile.get("trees", []) as Array).duplicate()
    output["behavior_tags"] = (profile.get("tags", []) as Array).duplicate()
    output["recruitable"] = true
    output["recruitment_condition"] = profile.get("recruitment_condition", null)
    output["auxiliary_role"] = profile.get("auxiliary_role", null)
    output["main_party_replacement_forbidden"] = true
    output["variant_form"] = str(form.get("form", ""))
    output["variant_form_locked"] = bool(form.get("named_form_locked", false))
    output["unnamed_canonical_variant"] = bool(form.get("unnamed_canonical_variant", false))
    return output

func validate_contract() -> Dictionary:
    var errors: Array[String] = []
    if species_count() != int(payload.get("ordinary_species_count", 24)):
        errors.append("species_count")
    if family_count() != int(payload.get("combat_family_count", 8)):
        errors.append("family_count")
    for species: Variant in profiles_by_species.keys():
        var profile: Dictionary = profiles_by_species[species]
        if (profile.get("trees", []) as Array).size() != 3:
            errors.append("trees:%s" % str(species))
        if str(profile.get("family", "")) == "":
            errors.append("family:%s" % str(species))
        if str(profile.get("role", "")) == "":
            errors.append("role:%s" % str(species))
        if str(profile.get("anatomy", "")) == "":
            errors.append("anatomy:%s" % str(species))
        var forms: Dictionary = profile.get("forms", {})
        for tier in ["N1", "N20", "N40"]:
            if not forms.has(tier):
                errors.append("variant:%s:%s" % [str(species), tier])
    return {"valid": errors.is_empty(), "errors": errors, "species_count": species_count(), "family_count": family_count()}
