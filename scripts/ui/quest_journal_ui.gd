extends CanvasLayer

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const DARK := Color(0.015, 0.017, 0.023, 0.98)
const PANEL := Color(0.035, 0.038, 0.050, 0.98)

var launcher: Button
var overlay: Control
var body: Control

func _ready() -> void:
    layer = 28
    _build_launcher(); _build_overlay()
    GameState.screen_requested.connect(_on_screen_requested)
    PoliticalState.politics_changed.connect(_on_state_changed)
    CampaignState.campaign_changed.connect(_on_state_changed)
    BountyContractDirector.bounty_board_changed.connect(_on_state_changed)
    Chapter01Runtime.chapter_one_changed.connect(_on_state_changed); Chapter01Runtime.boss_choice_required.connect(_open_journal)
    Chapter02Runtime.chapter_two_changed.connect(_on_state_changed); Chapter02Runtime.final_choice_required.connect(_open_journal)
    Chapter03Runtime.chapter_three_changed.connect(_on_state_changed); Chapter03Runtime.echo_choice_required.connect(_open_journal)
    Chapter04Runtime.chapter_four_changed.connect(_on_state_changed); Chapter04Runtime.final_choice_required.connect(_open_journal)
    Chapter05Runtime.chapter_five_changed.connect(_on_state_changed); Chapter05Runtime.final_choice_required.connect(_open_journal)
    Chapter06Runtime.chapter_six_changed.connect(_on_state_changed); Chapter06Runtime.final_choice_required.connect(_open_journal)
    Chapter07Runtime.chapter_seven_changed.connect(_on_state_changed); Chapter07Runtime.provisional_choice_required.connect(func(_actor): _open_journal()); Chapter07Runtime.final_choice_required.connect(_open_journal)
    SanctuaryState.sanctuary_state_changed.connect(_on_sanctuary_changed)
    _on_screen_requested(GameState.current_screen)

func _style(color := PANEL) -> StyleBoxFlat:
    var style := StyleBoxFlat.new(); style.bg_color = color; style.border_color = Color(0.45,0.34,0.20,0.82); style.set_border_width_all(1); style.set_corner_radius_all(5); style.content_margin_left = 12; style.content_margin_right = 12; style.content_margin_top = 9; style.content_margin_bottom = 9; return style
func _label(text: String, size := 15, color := TEXT) -> Label:
    var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size",size); label.add_theme_color_override("font_color",color); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; return label
func _button(text: String, callback: Callable, size := Vector2(180,44)) -> Button:
    var button := Button.new(); button.text = text; button.custom_minimum_size = size; button.add_theme_font_size_override("font_size",15); button.add_theme_color_override("font_color",TEXT); button.add_theme_stylebox_override("normal",_style()); button.add_theme_stylebox_override("hover",_style(Color(0.11,0.085,0.06,0.99))); button.pressed.connect(callback); return button

func _build_launcher() -> void:
    launcher = _button("JOURNAL",func(): GameState.request_screen("quest_journal"),Vector2(150,44)); launcher.position = Vector2(1080,80); launcher.visible = false; add_child(launcher)
func _build_overlay() -> void:
    overlay = Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.visible = false; add_child(overlay)
    var bg := ColorRect.new(); bg.color = DARK; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(bg)
    var header := HBoxContainer.new(); header.position = Vector2(24,18); header.size = Vector2(1232,52); overlay.add_child(header)
    var title := _label("JOURNAL",26,GOLD); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title); header.add_child(_button("RETOUR",func(): GameState.request_screen("sanctuary"),Vector2(130,42)))
    body = Control.new(); body.position = Vector2(24,82); body.size = Vector2(1232,610); overlay.add_child(body)

func _on_screen_requested(screen_name: String) -> void:
    overlay.visible = screen_name == "quest_journal"; launcher.visible = false
    if overlay.visible:
        SanctuaryState.refresh(); PoliticalState.refresh_unlocks(); Chapter01Runtime.refresh_progress(); Chapter02Runtime.refresh_progress(); Chapter03Runtime.refresh_progress(); Chapter04Runtime.refresh_progress(); Chapter05Runtime.refresh_progress(); Chapter06Runtime.refresh_progress(); Chapter07Runtime.refresh_progress(); _render()
func _open_journal() -> void: GameState.request_screen("quest_journal")
func _on_state_changed() -> void:
    if overlay.visible: call_deferred("_render")
func _on_sanctuary_changed(_layers: Array) -> void:
    if overlay.visible: call_deferred("_render")
func _clear() -> void:
    for child in body.get_children(): child.queue_free()

func _render() -> void:
    if not overlay.visible: return
    _clear(); var columns := HBoxContainer.new(); columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); columns.add_theme_constant_override("separation",16); body.add_child(columns)
    var qp := PanelContainer.new(); qp.custom_minimum_size = Vector2(590,590); qp.add_theme_stylebox_override("panel",_style()); columns.add_child(qp)
    var qs := ScrollContainer.new(); qp.add_child(qs); var q := VBoxContainer.new(); q.custom_minimum_size = Vector2(550,0); q.add_theme_constant_override("separation",9); qs.add_child(q)
    var chapter := CampaignState.current_chapter(); q.add_child(_label("QUÊTE PRINCIPALE",19,GOLD)); q.add_child(_label("CHAPITRE %d — %s" % [CampaignState.current_chapter_number(),String(chapter.get("title",""))],18,TEXT)); q.add_child(_label(String(chapter.get("premise","")),13,MUTED))
    match CampaignState.current_chapter_id:
        "chapter_01_ashlands": _render_chapter_one(q)
        "chapter_02_before_fall": _render_chapter_two(q)
        "chapter_03_threshold": _render_chapter_three(q)
        "chapter_04_first_rupture": _render_chapter_four(q)
        "chapter_05_great_closure": _render_chapter_five(q)
        "chapter_06_absent": _render_chapter_six(q)
        "chapter_07_living_responsible": _render_chapter_seven(q)
    for quest_value in CampaignState.active_main_quests():
        var quest: Dictionary = quest_value; q.add_child(_label("◆ %s" % String(quest.get("name","Quête principale")),16,TEXT)); q.add_child(_label(String(quest.get("goal","")),13,MUTED))
    if not CampaignState.discovered_revelations.is_empty():
        q.add_child(_label("RÉVÉLATIONS CONFIRMÉES",16,GOLD)); for revelation in CampaignState.discovered_revelations.values(): q.add_child(_label("• %s" % String(revelation),13,MUTED))
    _render_side_quests(q)
    _render_bounties(q)
    q.add_child(_label("DÉCISIONS LOCALES",18,GOLD))
    for quest_value in PoliticalState.available_quests():
        var quest: Dictionary = quest_value; q.add_child(_label("• %s" % String(quest.get("name","Quête")),17,TEXT)); q.add_child(_label(String(quest.get("theme","")),13,MUTED))
    var sp := PanelContainer.new(); sp.custom_minimum_size = Vector2(590,590); sp.add_theme_stylebox_override("panel",_style()); columns.add_child(sp)
    var ss := ScrollContainer.new(); sp.add_child(ss); var s := VBoxContainer.new(); s.custom_minimum_size = Vector2(550,0); s.add_theme_constant_override("separation",9); ss.add_child(s)
    s.add_child(_label("SANCTUAIRE DU PREMIER VOILE",19,GOLD)); s.add_child(_label("État actuel : %s" % SanctuaryState.summary(),16,TEXT)); s.add_child(_label("Confiance %d · Tension %d · Réputation %+d" % [PoliticalState.trust,PoliticalState.tension,PoliticalState.reputation],14,MUTED))
    var a: Dictionary = PoliticalState.three_awakenings; s.add_child(_label("Corps %d · Esprit %d · Cité %d" % [int(a.get("body",50)),int(a.get("spirit",50)),int(a.get("city",50))],14,MUTED)); _add_section(s,"CHANGEMENTS VISIBLES",SanctuaryState.current_visual_cues()); _add_section(s,"POPULATION ET PRÉSENCES",SanctuaryState.current_population_cues()); _add_section(s,"AMBIANCE",SanctuaryState.current_audio_cues())

func _stage_header(parent: VBoxContainer, title: String, runtime: Node) -> void:
    parent.add_child(_label("PROGRESSION DU %s — %s" % [title,runtime.progress_text()],15,GOLD)); var st: Dictionary = runtime.active_stage(); if not st.is_empty(): parent.add_child(_label("Objectif actuel : %s" % String(st.get("name","")),16,TEXT)); parent.add_child(_label(String(st.get("objective","")),13,MUTED))
func _render_chapter_one(parent: VBoxContainer) -> void: _stage_header(parent,"CHAPITRE I",Chapter01Runtime); _add_c01_choice(parent)
func _render_chapter_two(parent: VBoxContainer) -> void:
    _stage_header(parent,"CHAPITRE II",Chapter02Runtime); if not AshlandsRuntime.is_zone_discovered("c02_old_road"): parent.add_child(_button("PARTIR SUR LA ROUTE DES BORNES",func(): AshlandsSceneRouter.start_chapter_02(),Vector2(520,48))); parent.add_child(_label("ENQUÊTE — %d indices · %d sources indépendantes" % [Chapter02Runtime.clue_count(),Chapter02Runtime.independent_source_count()],15,GOLD)); _add_c02_choice(parent)
func _render_chapter_three(parent: VBoxContainer) -> void:
    _stage_header(parent,"CHAPITRE III",Chapter03Runtime); if not AshlandsRuntime.is_zone_discovered("c03_abandoned_relay"): parent.add_child(_button("ENTRER DANS LE RÉSEAU DU SEUIL",func(): AshlandsSceneRouter.start_chapter_03(),Vector2(520,48))); parent.add_child(_label("DOSSIER DU PROJET SEUIL — %d preuves · %d acteurs reliés · %d sources" % [Chapter03Runtime.evidence_count(),Chapter03Runtime.actor_count_with_evidence(),Chapter03Runtime.independent_source_count()],15,GOLD)); _add_c03_choice(parent)
func _render_chapter_four(parent: VBoxContainer) -> void:
    _stage_header(parent,"CHAPITRE IV",Chapter04Runtime); if not AshlandsRuntime.is_zone_discovered("c04_buried_city"): parent.add_child(_button("DESCENDRE VERS LA CITÉ DE NHAL",func(): AshlandsSceneRouter.start_chapter_04(),Vector2(520,48))); parent.add_child(_label("ARCHÉOLOGIE ASHAÏ — %d fragments · %d familles de sources · %d contradictions" % [Chapter04Runtime.fragment_count(),Chapter04Runtime.independent_source_family_count(),Chapter04Runtime.contradiction_count()],15,GOLD)); _add_c04_choice(parent)
func _render_chapter_five(parent: VBoxContainer) -> void:
    _stage_header(parent,"CHAPITRE V",Chapter05Runtime); if not AshlandsRuntime.is_zone_discovered("c05_black_glass_crypts"): parent.add_child(_button("ENTRER DANS LES CRYPTES DE VERRE NOIR",func(): AshlandsSceneRouter.start_chapter_05(),Vector2(520,48))); parent.add_child(_label("DOSSIER OR-SILEX / SAAN — %d fragments · %d familles de sources" % [Chapter05Runtime.fragment_count(),Chapter05Runtime.independent_source_family_count()],15,GOLD)); _add_c05_choice(parent)
func _render_chapter_six(parent: VBoxContainer) -> void:
    _stage_header(parent,"CHAPITRE VI",Chapter06Runtime); if not AshlandsRuntime.is_zone_discovered("c06_timeless_garden"): parent.add_child(_button("ENTRER DANS LE JARDIN SANS SAISON",func(): AshlandsSceneRouter.start_chapter_06(),Vector2(520,48))); parent.add_child(_label("DOSSIER DES ABSENTS — %d signaux · %d familles de sources" % [Chapter06Runtime.signal_count(),Chapter06Runtime.independent_source_family_count()],15,GOLD)); parent.add_child(_label("Réactions directes : %d · mesures de Meira : %d · ancrages %d/3" % [Chapter06Runtime.direct_reaction_count(),Chapter06Runtime.proxy_reaction_count(),Chapter06Runtime.anchor_count()],13,MUTED)); _add_c06_choice(parent)
func _render_chapter_seven(parent: VBoxContainer) -> void:
    _stage_header(parent,"CHAPITRE VII",Chapter07Runtime)
    if not AshlandsRuntime.is_zone_discovered("c07_engineer_refuge"): parent.add_child(_button("RETROUVER LES RESPONSABLES VIVANTS",func(): AshlandsSceneRouter.start_chapter_07(),Vector2(520,48)))
    parent.add_child(_label("DOSSIER DE RESPONSABILITÉ — %d témoignages · chaîne étrangère %d" % [Chapter07Runtime.testimony_count(),Chapter07Runtime.foreign_chain_count()],15,GOLD))
    parent.add_child(_label("Bram : %s · Veyra : %s · contre-rituels : %d/3" % [String(Chapter07Runtime.provisional_choices.get("bram","non tranché")),String(Chapter07Runtime.provisional_choices.get("veyra","non tranché")),Chapter07Runtime.counter_ritual_count()],13,MUTED))
    _add_c07_provisional_choice(parent,"bram"); _add_c07_provisional_choice(parent,"veyra"); _add_c07_choice(parent)

func _add_c01_choice(parent: VBoxContainer) -> void:
    if Chapter01Runtime.boss_choice != "" or not AshlandsRuntime.is_encounter_cleared("c01_boss_ash_witness"): return
    for value in Chapter01Runtime.stage("c01_stage_07_witness").get("boss_choices",[]): var c: Dictionary = value; var id := String(c.get("id","")); parent.add_child(_button(String(c.get("label",id)),func(v=id): Chapter01Runtime.choose_boss_outcome(String(v)); SaveManager.save_game(); _render(),Vector2(520,48)))
func _add_c02_choice(parent: VBoxContainer) -> void:
    if Chapter02Runtime.final_choice != "" or not AshlandsRuntime.is_encounter_cleared("c02_marker_warden"): return
    for value in Chapter02Runtime.slice.get("final_choice",[]): var c: Dictionary = value; var id := String(c.get("id","")); parent.add_child(_button(String(c.get("label",id)),func(v=id): Chapter02Runtime.choose_final_outcome(String(v)); SaveManager.save_game(); _render(),Vector2(520,48)))
func _add_c03_choice(parent: VBoxContainer) -> void:
    if Chapter03Runtime.echo_choice != "" or not AshlandsRuntime.is_encounter_cleared("c03_boss_threshold_echo"): return
    parent.add_child(_label("DÉCISION — L'ÉCHO DU SEUIL",16,GOLD)); for value in Chapter03Runtime.data.get("boss_choices",[]): var c: Dictionary = value; var id := String(c.get("id","")); parent.add_child(_button(String(c.get("label",id)),func(v=id): Chapter03Runtime.choose_echo_outcome(String(v)); SaveManager.save_game(); _render(),Vector2(520,48)))
func _add_c04_choice(parent: VBoxContainer) -> void:
    if Chapter04Runtime.final_choice != "" or not AshlandsRuntime.is_encounter_cleared("c04_boss_unfinished_chorus"): return
    parent.add_child(_label("DÉCISION — LE CHŒUR INACHEVÉ",16,GOLD)); for value in Chapter04Runtime.chapter.get("boss_choices",[]): var c: Dictionary = value; var id := String(c.get("id","")); parent.add_child(_button(String(c.get("label",id)),func(v=id): Chapter04Runtime.choose_final_outcome(String(v)); SaveManager.save_game(); _render(),Vector2(520,48)))
func _add_c05_choice(parent: VBoxContainer) -> void:
    if Chapter05Runtime.final_choice != "" or not AshlandsRuntime.is_encounter_cleared("c05_boss_silex_general"): return
    parent.add_child(_label("DÉCISION — L'ARSENAL DU GÉNÉRAL DE SILEX",16,GOLD)); for value in Chapter05Runtime.chapter.get("boss_choices",[]): var c: Dictionary = value; var id := String(c.get("id","")); parent.add_child(_button(String(c.get("label",id)),func(v=id): Chapter05Runtime.choose_final_outcome(String(v)); SaveManager.save_game(); _render(),Vector2(520,48)))
func _add_c06_choice(parent: VBoxContainer) -> void:
    if Chapter06Runtime.final_choice != "" or not AshlandsRuntime.is_encounter_cleared("c06_boss_boundary") or Chapter06Runtime.anchor_count() < 3: return
    parent.add_child(_label("DÉCISION — LA FRONTIÈRE QUI MARCHE",16,GOLD)); for value in Chapter06Runtime.chapter.get("boss_choices",[]): var c: Dictionary = value; var id := String(c.get("id","")); parent.add_child(_button(String(c.get("label",id)),func(v=id): Chapter06Runtime.choose_final_outcome(String(v)); SaveManager.save_game(); _render(),Vector2(520,48)))
func _add_c07_provisional_choice(parent: VBoxContainer, actor_id: String) -> void:
    if Chapter07Runtime.provisional_choices.has(actor_id) or not Chapter07Runtime.can_resolve_actor(actor_id): return
    parent.add_child(_label("STATUT PROVISOIRE — %s" % ("BRAM TORGUN" if actor_id == "bram" else "VEYRA OSS"),16,GOLD))
    for value in Chapter07Runtime.chapter.get("provisional_outcomes",{}).get(actor_id,[]): var c: Dictionary = value; var id := String(c.get("id","")); parent.add_child(_button(String(c.get("label",id)),func(v=id,a=actor_id): Chapter07Runtime.choose_provisional_outcome(String(a),String(v)); SaveManager.save_game(); _render(),Vector2(520,48)))
func _add_c07_choice(parent: VBoxContainer) -> void:
    if Chapter07Runtime.final_choice != "" or not AshlandsRuntime.is_encounter_cleared("c07_boss_edras") or Chapter07Runtime.counter_ritual_count() < 3: return
    parent.add_child(_label("DÉCISION — EDRAS NHAL",16,GOLD)); parent.add_child(_label("Le vaincre ne décide pas encore ce que la Concorde a le droit de lui faire.",13,MUTED))
    for value in Chapter07Runtime.available_boss_choices(): var c: Dictionary = value; var id := String(c.get("id","")); parent.add_child(_button(String(c.get("label",id)),func(v=id): Chapter07Runtime.choose_final_outcome(String(v)); SaveManager.save_game(); _render(),Vector2(520,48)))

func _add_section(parent: VBoxContainer, title: String, entries: Array) -> void:
    if entries.is_empty(): return
    parent.add_child(_label(title,15,GOLD)); for entry in entries: parent.add_child(_label("• %s" % String(entry),13,MUTED))

func _render_side_quests(parent: VBoxContainer) -> void:
    var file := FileAccess.open("res://data/quests.json", FileAccess.READ)
    if file == null:
        return
    var quest_data = JSON.parse_string(file.get_as_text())
    if typeof(quest_data) != TYPE_ARRAY:
        return
    parent.add_child(_label("QUÊTES SECONDAIRES — PREMIÈRE CARTE",18,GOLD))
    for value in quest_data:
        var quest: Dictionary = value
        if String(quest.get("narrative_role", "")) != "side":
            continue
        var giver := NarrativeLibrary.quest_giver_for(quest)
        var quest_id := String(quest.get("id", ""))
        var quest_status := SideQuestRuntime.status(quest_id)
        var state_data := SideQuestRuntime.state(quest_id)
        var progress: Dictionary = state_data.get("progress", {})
        parent.add_child(_label("%s %s — %s" % ["◆" if quest_status == "active" else ("✓" if quest_status == "completed" else "◇"), String(quest.get("name", "Quête")), quest_status.capitalize()],15,TEXT))
        var giver_button := _button("RENCONTRER %s — %s" % [String(giver.get("name", "Inconnu")).to_upper(), String(giver.get("role", ""))], func(g = giver, q = quest, s = quest_status): QuestGiverPresentation.open_dialogue(g, q, s), Vector2(520, 42))
        QuestGiverPresentation.bind_card(giver_button, giver, quest_status)
        parent.add_child(giver_button)
        parent.add_child(_label(String(giver.get("location", "")),12,GOLD))
        parent.add_child(_label(NarrativeLibrary.quest_state_text(quest, quest_status),12,MUTED))
        for objective_value: Variant in quest.get("objectives", []):
            var objective: Dictionary = objective_value
            var objective_id := String(objective.get("id", ""))
            var current := int(progress.get(objective_id, 0))
            var required := int(objective.get("count", 1))
            parent.add_child(_label("  %s %s — %d/%d" % ["✓" if current >= required else "□", NarrativeLibrary.quest_objective_text(objective), current, required],11,MUTED))

func _render_bounties(parent: VBoxContainer) -> void:
    if BountyContractDirector.offered_contracts.is_empty() and BountyContractDirector.active_contracts.is_empty():
        var context := {
            "dungeon_id": "first_veil_crypts",
            "enemy_families": ["arachnid", "undead", "ash_mutant"],
            "elites": ["ash_guardian"],
            "capturable_families": ["arachnid", "ash_mutant"],
            "body_parts": ["arm", "leg", "head"]
        }
        BountyContractDirector.generate_dungeon_board("first_veil_crypts", 1, context, 101 + BountyContractDirector.completed_dungeon_runs)
    parent.add_child(_label("CONTRATS DE CHASSE",18,GOLD))
    var bounty_giver := NarrativeLibrary.quest_giver("vara_kesh")
    var bounty_dialogue := {"name":"Contrats de chasse","narrative":{"offer_lines":["Vara maintient une main sur le registre et fait glisser les contrats disponibles.","« Une prime n’est pas une invitation au massacre. C’est une dette précise envers ceux qui ne peuvent plus emprunter la route. »"],"player_accept":"Montre-nous les contrats dont la route a besoin.","player_decline":"Nous ne prendrons aucun engagement aujourd’hui."}}
    var bounty_button := _button("RENCONTRER %s — %s" % [String(bounty_giver.get("name", "Vara Kesh")).to_upper(), String(bounty_giver.get("role", "Maîtresse des primes"))], func(): QuestGiverPresentation.open_dialogue(bounty_giver, bounty_dialogue, "offered"), Vector2(520,42))
    QuestGiverPresentation.bind_card(bounty_button, bounty_giver, "offered")
    parent.add_child(bounty_button)
    parent.add_child(_label(String(bounty_giver.get("location", "Table des chasseurs")),12,GOLD))
    parent.add_child(_label("Maximum 2 actifs · renouvelés après les expéditions",12,MUTED))
    for value in BountyContractDirector.active_contracts:
        var contract: Dictionary = value
        parent.add_child(_label("◆ %s — %d/%d" % [String(contract.get("name", "Contrat")), int(contract.get("progress", 0)), int(contract.get("required", 1))],14,TEXT))
        if String(contract.get("status", "")) == "completed":
            parent.add_child(_button("RÉCLAMER LA PRIME", func(id = String(contract.get("id", ""))): BountyContractDirector.claim_contract(id); SaveManager.save_game(); _render(), Vector2(300,42)))
    for value in BountyContractDirector.offered_contracts:
        var contract: Dictionary = value
        parent.add_child(_label("○ %s · cible : %s · quantité : %d" % [String(contract.get("name", "Contrat")), String(contract.get("target", "")), int(contract.get("required", 1))],14,TEXT))
        parent.add_child(_button("ACCEPTER", func(id = String(contract.get("id", ""))): BountyContractDirector.accept_contract(id); SaveManager.save_game(); _render(), Vector2(220,40)))
