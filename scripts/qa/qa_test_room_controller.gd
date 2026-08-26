extends Node3D
class_name QATestRoomController

const PARTY_SCENE := preload("res://scenes/world/terre_des_cendres/exploration_party_placeholder.tscn")
const NPC_SCRIPT := preload("res://scripts/qa/qa_test_dialogue_npc.gd")
const CHEST_SCRIPT := preload("res://scripts/qa/qa_test_loot_chest.gd")
const MAIN_SCENE := "res://scenes/Main.tscn"

var status_label: Label
var checklist_label: Label

func _ready() -> void:
    if not ExpeditionManager.expedition_active:
        ExpeditionManager.start_expedition()
    AshlandsRuntime.enter_zone("qa_validation_room")
    GameState.current_screen = "exploration"
    HUDDirector.set_screen_context("exploration")
    ContentScopeDirector.grant_capability("capture")
    _prepare_consumables()
    _build_room()
    _build_test_targets()
    _build_party()
    _build_panel()
    QATestRoomState.checklist_changed.connect(_on_checklist_changed)
    _on_checklist_changed(QATestRoomState.results)
    HUDDirector.notify_quest("Salle de validation", "Testez chaque station puis le combat.")

func _prepare_consumables() -> void:
    CombatLoadoutManager.add_to_inventory("field_dressing", 10)
    CombatLoadoutManager.add_to_inventory("fire_grenade", 10)
    if GameState.party.is_empty():
        return
    var hero: Dictionary = GameState.party[0]
    var hero_id := str(hero.get("id", ""))
    CombatLoadoutManager.equip(hero_id, "field_dressing", 5)
    CombatLoadoutManager.equip(hero_id, "fire_grenade", 5)
    QATestRoomState.mark("consumables",
        int(CombatLoadoutManager.equipped_stack(hero_id, CombatLoadoutManager.HEAL_SLOT).get("quantity", 0)) == 5
        and int(CombatLoadoutManager.equipped_stack(hero_id, CombatLoadoutManager.GRENADE_SLOT).get("quantity", 0)) == 5)

func _build_room() -> void:
    var geometry := Node3D.new()
    geometry.name = "ValidationRoomGeometry"
    add_child(geometry)
    _solid_box(geometry, "Floor", Vector3(0.0, -0.3, 0.0), Vector3(36.0, 0.6, 30.0), Color("#3a3740"))
    _solid_box(geometry, "NorthWall", Vector3(0.0, 2.0, -15.0), Vector3(36.0, 4.0, 0.8), Color("#211f29"))
    _solid_box(geometry, "SouthWall", Vector3(0.0, 2.0, 15.0), Vector3(36.0, 4.0, 0.8), Color("#211f29"))
    _solid_box(geometry, "WestWall", Vector3(-18.0, 2.0, 0.0), Vector3(0.8, 4.0, 30.0), Color("#211f29"))
    _solid_box(geometry, "EastWall", Vector3(18.0, 2.0, 0.0), Vector3(0.8, 4.0, 30.0), Color("#211f29"))
    _solid_box(geometry, "DialogueDais", Vector3(-9.0, 0.1, 2.0), Vector3(5.0, 0.2, 5.0), Color("#51606b"))
    _solid_box(geometry, "LootDais", Vector3(9.0, 0.1, 2.0), Vector3(5.0, 0.2, 5.0), Color("#705632"))
    _solid_box(geometry, "ArenaLine", Vector3(0.0, 0.03, -7.0), Vector3(32.0, 0.06, 0.35), Color("#8d3438"))

func _build_test_targets() -> void:
    var npc := NPC_SCRIPT.new() as Area3D
    npc.name = "IlyanDialogueTest"
    npc.position = Vector3(-9.0, 0.0, 2.0)
    _add_area_collision(npc, Vector3(1.2, 2.0, 1.2))
    _add_visual(npc, Vector3(0.0, 1.0, 0.0), Vector3(0.9, 2.0, 0.9), Color("#6d8fa3"))
    add_child(npc)

    var chest := CHEST_SCRIPT.new() as Area3D
    chest.name = "LootChestTest"
    chest.position = Vector3(9.0, 0.0, 2.0)
    _add_area_collision(chest, Vector3(1.8, 1.4, 1.4))
    _add_visual(chest, Vector3(0.0, 0.7, 0.0), Vector3(1.8, 1.4, 1.4), Color("#a17b3e"))
    add_child(chest)

    var encounter := EncounterTrigger.new()
    encounter.name = "CombatTestTrigger"
    encounter.position = Vector3(0.0, 0.0, -9.5)
    encounter.encounter_id = "qa_mixed_enemy_combat"
    encounter.encounter_type = "normal"
    encounter.one_shot = true
    encounter.alternate_route_available = true
    encounter.starts_on_contact = true
    encounter.use_combat_bridge = true
    encounter.set_meta("qa_purpose", ["combat", "skills", "items", "fear", "injuries", "capture", "inspection"])
    _add_area_collision(encounter, Vector3(14.0, 2.0, 3.0))
    add_child(encounter)

    var guidance_target := Marker3D.new()
    guidance_target.name = "AshGuidanceTarget"
    guidance_target.position = Vector3(0.0, 0.0, -12.5)
    guidance_target.add_to_group("qa_ash_target")
    add_child(guidance_target)

func _build_party() -> void:
    var party := PARTY_SCENE.instantiate()
    party.name = "QATestParty"
    party.position = Vector3(0.0, 0.1, 11.0)
    add_child(party)
    if party.has_signal("movement_state_changed"):
        party.movement_state_changed.connect(func(is_moving: bool, _is_running: bool):
            if is_moving:
                QATestRoomState.mark("movement"))

func _build_panel() -> void:
    var layer := CanvasLayer.new()
    layer.name = "QAValidationPanel"
    layer.layer = 90
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(930, 18)
    panel.size = Vector2(330, 684)
    layer.add_child(panel)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.02, 0.025, 0.035, 0.94)
    style.border_color = Color("#d5b26c")
    style.set_border_width_all(1)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    panel.add_theme_stylebox_override("panel", style)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 6)
    panel.add_child(column)
    column.add_child(_label("SALLE DE VALIDATION", 20, Color("#d5b26c")))
    column.add_child(_label("Environnement isolé — aucune progression de campagne.", 12, Color("#a49884")))
    status_label = _label("", 13, Color("#e5dccb"))
    column.add_child(status_label)
    checklist_label = _label("", 12, Color("#c9c0b1"))
    checklist_label.custom_minimum_size = Vector2(300, 210)
    column.add_child(checklist_label)
    column.add_child(_button("POSTURES PEUR / ESPOIR", _inject_psychology))
    column.add_child(_button("BLESSURE PERSISTANTE", _inject_injury))
    column.add_child(_button("DEMANDER LES CENDRES", _test_ash_guidance))
    column.add_child(_button("SAUVER SNAPSHOT QA", _save_qa_snapshot))
    column.add_child(_button("CHARGER SNAPSHOT QA", _load_qa_snapshot))
    column.add_child(_button("RÉINITIALISER LA SALLE", _reset_room))
    column.add_child(_button("RETOUR AU MENU", _return_to_title))

func _inject_psychology() -> void:
    if GameState.party.size() < 2:
        return
    var fearful: Dictionary = GameState.party[0]
    var hopeful: Dictionary = GameState.party[1]
    fearful["fear"] = 82
    fearful["hope"] = 5
    hopeful["fear"] = 0
    hopeful["hope"] = 82
    if GameState.party.size() >= 3:
        var afflicted: Dictionary = GameState.party[2]
        afflicted["madness"] = 72
    PsychologyRuntime.ensure_hero(fearful)
    PsychologyRuntime.ensure_hero(hopeful)
    QATestRoomState.mark("psychology")
    HUDDirector.request_party_status()
    GameState.state_changed.emit()
    _set_status("Postures contrastées appliquées aux héros.")

func _inject_injury() -> void:
    if GameState.party.is_empty():
        return
    var hero: Dictionary = GameState.party[0]
    var result := PersistentInjuryRuntime.apply_injury(hero, "arm_injury", "serious")
    QATestRoomState.mark("injury", not result.is_empty())
    HUDDirector.request_party_status()
    _set_status("Bras blessé sérieux appliqué ; le malus persistera jusqu'au soin.")

func _test_ash_guidance() -> void:
    var result := HUDDirector.request_world_guidance("qa_combat_gate", ["cendre"], {
        "source": "qa_validation_room",
        "target_position": [0.0, 0.0, -12.5],
        "path": [[0.0, 0.0, 11.0], [0.0, 0.0, 2.0], [0.0, 0.0, -6.0], [0.0, 0.0, -12.5]]
    })
    QATestRoomState.mark("ash_guidance", str(result.get("channel", "")) == "cendre" and not bool(result.get("hud_marker", true)))
    _set_status("Guidage demandé vers l'arène, sans marqueur HUD.")

func _save_qa_snapshot() -> void:
    var success := SaveManager.save_qa_snapshot()
    _set_status("Snapshot QA sauvegardé." if success else "Échec du snapshot QA.")

func _load_qa_snapshot() -> void:
    var success := SaveManager.load_qa_snapshot()
    QATestRoomState.mark("save_roundtrip", success)
    _set_status("Snapshot QA chargé." if success else "Aucun snapshot QA valide.")

func _reset_room() -> void:
    SaveManager.delete_qa_snapshot()
    GameState.reset_new_game()
    QATestRoomState.reset_session()
    get_tree().reload_current_scene()

func _return_to_title() -> void:
    SaveManager.delete_qa_snapshot()
    QATestRoomState.active = false
    GameState.current_screen = "title"
    get_tree().change_scene_to_file(MAIN_SCENE)

func _on_checklist_changed(results: Dictionary) -> void:
    if not is_instance_valid(checklist_label):
        return
    var labels := {
        "movement": "Déplacement",
        "dialogue": "Dialogue",
        "chest": "Ouverture du coffre",
        "loot": "Ajout du butin",
        "combat_started": "Entrée en combat",
        "combat_finished": "Retour après combat",
        "consumables": "Soins et grenades",
        "psychology": "Peur / Espoir / Folie",
        "injury": "Blessure persistante",
        "ash_guidance": "Guidage par les cendres",
        "save_roundtrip": "Sauvegarde / chargement"
    }
    var lines: Array[String] = []
    for check_id: String in QATestRoomState.CHECKS:
        lines.append("%s %s" % ["✓" if bool(results.get(check_id, false)) else "◇", str(labels.get(check_id, check_id))])
    checklist_label.text = "\n".join(lines)
    status_label.text = "%d/%d contrôles validés" % [QATestRoomState.completed_count(), QATestRoomState.CHECKS.size()]

func _set_status(text: String) -> void:
    GameState.add_log(text)
    HUDDirector.notify_quest("Validation", text)

func _solid_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = pos
    parent.add_child(body)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    mesh.material_override = material
    body.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)

func _add_area_collision(area: Area3D, size: Vector3) -> void:
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    collision.position.y = size.y * 0.5
    area.add_child(collision)

func _add_visual(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
    var mesh := MeshInstance3D.new()
    mesh.position = pos
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    mesh.material_override = material
    parent.add_child(mesh)

func _button(text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(300, 36)
    button.pressed.connect(callback)
    return button

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label
