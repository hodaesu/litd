extends Node3D
class_name OpeningCityProxyBuilder

var hero_group: Node3D
var approach_hero: Node3D
var _living_materials: Array[StandardMaterial3D] = []


func build() -> void:
    name = "OpeningCityMemoryProxy"
    _build_street()
    _build_rooftops()
    _build_tournament()
    _build_arts_house()
    _build_political_hall()
    _build_sea_fleet_and_gate()
    _build_four_heroes()


func begin_fall() -> void:
    for material: StandardMaterial3D in _living_materials:
        material.albedo_color = material.albedo_color.lerp(Color(0.30, 0.31, 0.33, 1.0), 0.72)
        material.roughness = 1.0


func hide_old_city() -> void:
    for child: Node in get_children():
        if child != hero_group:
            child.visible = false


func _build_street() -> void:
    var root := _section("LivingAlley", "population_and_children")
    var stone := _material("AlleyStone", Color(0.42, 0.35, 0.29))
    var cloth := _material("MarketCloth", Color(0.58, 0.22, 0.16))
    _box(root, Vector3(-30.0, -0.1, 18.0), Vector3(30.0, 0.2, 12.0), stone, "Street")
    for index in range(8):
        var side := -1.0 if index % 2 == 0 else 1.0
        _box(root, Vector3(-39.0 + float(index) * 4.2, 4.0, 18.0 + side * 7.0), Vector3(3.6, 8.0, 4.0), stone, "House_%02d" % index)
    for index in range(10):
        _person(root, Vector3(-37.0 + float(index) * 2.6, 0.0, 16.0 + float(index % 3) * 1.8), 1.0, cloth, "Citizen_%02d" % index)
    var child_material := _material("ChildrenCloth", Color(0.18, 0.42, 0.52))
    for index in range(4):
        var child := _person(root, Vector3(-25.5 + float(index) * 1.4, 0.0, 12.0 + float(index % 2) * 1.2), 0.62, child_material, "ChildPlaying_%02d" % index)
        child.set_meta("animation_intent", "run_chase_laugh")


func _build_rooftops() -> void:
    var root := _section("RooftopReveal", "connected_city")
    var tile := _material("RoofTile", Color(0.34, 0.12, 0.09))
    for index in range(9):
        _box(root, Vector3(-22.0 + float(index) * 5.0, 7.0 + float(index % 3), 3.0 - float(index) * 4.0), Vector3(5.0, 0.45, 5.0), tile, "Roof_%02d" % index)


func _build_tournament() -> void:
    var root := _section("MartialTournament", "war_replaced_by_rules")
    var arena := _material("ArenaSand", Color(0.48, 0.38, 0.24))
    var audience := _material("Audience", Color(0.36, 0.30, 0.42))
    var platform := _cylinder(root, Vector3(7.0, 0.25, -14.0), 9.0, 0.5, arena, "TournamentCircle")
    platform.set_meta("story_action", "codified_martial_tournament")
    _person(root, Vector3(5.5, 0.5, -14.0), 1.0, audience, "Fighter_A").set_meta("animation_intent", "martial_guard")
    _person(root, Vector3(8.5, 0.5, -14.0), 1.0, audience, "Fighter_B").set_meta("animation_intent", "martial_exchange")
    _person(root, Vector3(7.0, 0.5, -10.5), 1.0, arena, "Referee").set_meta("animation_intent", "judge_signal")
    for index in range(18):
        var angle := TAU * float(index) / 18.0
        _person(root, Vector3(7.0 + cos(angle) * 11.0, 0.0, -14.0 + sin(angle) * 11.0), 0.86, audience, "Spectator_%02d" % index)


func _build_arts_house() -> void:
    var root := _section("HouseOfArts", "arts_and_diegetic_music")
    var wood := _material("ArtsWood", Color(0.36, 0.24, 0.14))
    var art := _material("ArtColor", Color(0.58, 0.42, 0.18))
    _box(root, Vector3(27.0, -0.1, -29.0), Vector3(28.0, 0.2, 18.0), wood, "ArtsFloor")
    for position: Vector3 in [Vector3(14, 3, -20), Vector3(40, 3, -20), Vector3(14, 3, -38), Vector3(40, 3, -38)]:
        _box(root, position, Vector3(0.8, 6.0, 0.8), wood, "OpenColumn")
    for index in range(6):
        var worker := _person(root, Vector3(19.0 + float(index) * 3.0, 0.0, -25.0 - float(index % 2) * 3.0), 0.92, art, "Artist_%02d" % index)
        worker.set_meta("art_practice", ["painting", "sculpture", "dance", "ceramics", "calligraphy", "woodcraft"][index])
    for index in range(4):
        var musician := _person(root, Vector3(31.0 + float(index) * 2.0, 0.0, -34.0), 0.94, wood, "Musician_%02d" % index)
        musician.set_meta("animation_intent", "perform_opening_theme")
        musician.set_meta("audio_event", "diegetic_music")


func _build_political_hall() -> void:
    var root := _section("CivicAssembly", "politics_for_common_good")
    var civic := _material("CivicStone", Color(0.46, 0.39, 0.28))
    var debate := _material("DebateCloth", Color(0.23, 0.34, 0.48))
    _box(root, Vector3(46.0, -0.1, -53.0), Vector3(20.0, 0.2, 16.0), civic, "AssemblyFloor")
    for index in range(12):
        var angle := lerpf(-2.7, -0.45, float(index) / 11.0)
        var participant := _person(root, Vector3(46.0 + cos(angle) * 7.0, 0.0, -53.0 + sin(angle) * 7.0), 0.96, debate, "Debater_%02d" % index)
        participant.set_meta("animation_intent", "listen_argument_respond")
    _person(root, Vector3(46.0, 0.0, -49.0), 1.0, civic, "CurrentSpeaker").set_meta("animation_intent", "reasoned_public_argument")


func _build_sea_fleet_and_gate() -> void:
    var root := _section("SeaAndForeignFleet", "invasion_and_veil_gate")
    var sea := _material("Sea", Color(0.05, 0.18, 0.26))
    var foreign := _material("ForeignHull", Color(0.16, 0.11, 0.10))
    var veil := _material("VeilGate", Color(0.28, 0.10, 0.38))
    _box(root, Vector3(0.0, -1.2, -105.0), Vector3(140.0, 0.4, 80.0), sea, "Sea")
    for index in range(9):
        var ship := _box(root, Vector3(-34.0 + float(index) * 8.0, 0.0, -91.0 - float(index % 3) * 9.0), Vector3(5.0, 1.0, 11.0), foreign, "ForeignShip_%02d" % index)
        ship.set_meta("origin", "other_continents_alliance")
    var gate := _cylinder(root, Vector3(-15.0, 12.0, -119.0), 10.0, 1.0, veil, "VeilGate")
    gate.rotation_degrees.x = 90.0
    gate.set_meta("animation_intent", "open_and_release_shockwave")


func _build_four_heroes() -> void:
    hero_group = _section("FourHeroesApproach", "handoff_to_player_party")
    hero_group.top_level = true
    hero_group.global_position = Vector3(0.0, 0.0, 13.0)
    var colors: Array[Color] = [Color(0.20, 0.18, 0.16), Color(0.36, 0.24, 0.16), Color(0.58, 0.55, 0.43), Color(0.18, 0.23, 0.28)]
    for index in range(4):
        var hero_material := _material("Hero_%d" % index, colors[index])
        var hero := _person(hero_group, Vector3(-2.1 + float(index) * 1.4, 0.0, float(index % 2) * 0.8), 1.06, hero_material, "Hero_%d" % (index + 1))
        hero.set_meta("formation_slot", index)
        if index == 2:
            approach_hero = hero
            hero.set_meta("animation_intent", "approach_kneel_close_bird_eyes")


func _section(node_name: String, story_role: String) -> Node3D:
    var node := Node3D.new()
    node.name = node_name
    node.set_meta("story_role", story_role)
    add_child(node)
    return node


func _material(material_name: String, color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.resource_name = material_name
    material.albedo_color = color
    material.roughness = 0.82
    _living_materials.append(material)
    return material


func _box(parent: Node3D, position: Vector3, size: Vector3, material: Material, node_name: String) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = position
    instance.material_override = material
    parent.add_child(instance)
    return instance


func _cylinder(parent: Node3D, position: Vector3, radius: float, height: float, material: Material, node_name: String) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    instance.mesh = mesh
    instance.position = position
    instance.material_override = material
    parent.add_child(instance)
    return instance


func _person(parent: Node3D, position: Vector3, scale_value: float, material: Material, node_name: String) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.32 * scale_value
    mesh.height = 1.65 * scale_value
    instance.mesh = mesh
    instance.position = position + Vector3.UP * mesh.height * 0.5
    instance.material_override = material
    parent.add_child(instance)
    return instance
