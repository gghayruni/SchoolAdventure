extends Node3D
## A tiny procedural neighborhood for a Windows prototype.
## All geometry, materials and props are generated at runtime.

const PlayerScript = preload("res://scripts/player.gd")
const MAP_HALF_SIZE = 116.0
const ROAD_LINES = [-60.0, 0.0, 60.0]
const LOT_LINES = [-90.0, -30.0, 30.0, 90.0]

var rng := RandomNumberGenerator.new()
var material_cache: Dictionary = {}
var building_palette := [
    Color("efd9bd"), Color("f3e7d8"), Color("c8dfdc"),
    Color("d3dced"), Color("e1d3ca"), Color("e9dcb6"),
    Color("dfdfeb"), Color("d8cbdc")
]

func _ready() -> void:
    rng.randomize()
    _add_environment()
    _create_ground()
    _create_streets()
    _create_city_blocks()
    _create_street_props()
    _create_player()
    _create_hud()

func _unhandled_key_input(event: InputEvent) -> void:
    # Godot passes all kinds of InputEvent here. Inspect keyboard-only
    # properties after narrowing to InputEventKey.
    if event is InputEventKey:
        if event.pressed and not event.echo and event.keycode == KEY_N:
            get_tree().reload_current_scene()

func _mat(color: Color) -> StandardMaterial3D:
    var key := color.to_html(true)
    if material_cache.has(key):
        return material_cache[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.92
    material_cache[key] = mat
    return mat

func _box(dimensions: Vector3, location: Vector3, color: Color, collision: bool = false, parent: Node3D = null) -> MeshInstance3D:
    var target: Node3D = self if parent == null else parent
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    node.mesh = mesh
    node.material_override = _mat(color)
    node.position = location
    target.add_child(node)
    if collision:
        var physics_body := StaticBody3D.new()
        physics_body.position = location
        target.add_child(physics_body)
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = dimensions
        col.shape = shape
        physics_body.add_child(col)
    return node

func _cylinder(radius: float, height: float, location: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
    var target: Node3D = self if parent == null else parent
    var node := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 9
    node.mesh = mesh
    node.material_override = _mat(color)
    node.position = location
    target.add_child(node)
    return node

func _sphere(radius: float, location: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
    var target: Node3D = self if parent == null else parent
    var node := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 12
    mesh.rings = 6
    node.mesh = mesh
    node.material_override = _mat(color)
    node.position = location
    target.add_child(node)
    return node

func _add_environment() -> void:
    var environment := Environment.new()
    var sky := Sky.new()
    var daytime := ProceduralSkyMaterial.new()
    daytime.sky_top_color = Color("71b7ed")
    daytime.sky_horizon_color = Color("d0e9fc")
    daytime.ground_bottom_color = Color("90a989")
    daytime.ground_horizon_color = Color("c3d3bd")
    sky.sky_material = daytime
    environment.background_mode = Environment.BG_SKY
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.65
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    var env_node := WorldEnvironment.new()
    env_node.environment = environment
    add_child(env_node)

    var sunlight := DirectionalLight3D.new()
    sunlight.rotation_degrees = Vector3(-53.0, -38.0, 0.0)
    sunlight.light_energy = 1.25
    sunlight.shadow_enabled = true
    add_child(sunlight)

func _create_ground() -> void:
    _box(Vector3(260.0, 0.5, 260.0), Vector3(0.0, -0.25, 0.0), Color("92be79"), true)
    for i in range(64):
        var x := rng.randf_range(-113.0, 113.0)
        var z := rng.randf_range(-113.0, 113.0)
        # Keep decorative grass out of the central carriageways.
        if _near_road(x, z, 12.0):
            continue
        _box(Vector3(rng.randf_range(2.0, 6.0), 0.02, rng.randf_range(2.0, 6.0)), Vector3(x, 0.015, z), Color("9dc582"))

func _near_road(x: float, z: float, distance: float) -> bool:
    for road in ROAD_LINES:
        if abs(x - road) < distance or abs(z - road) < distance:
            return true
    return false

func _create_streets() -> void:
    var asphalt := Color("566273")
    var curb := Color("d2cfcb")
    var sidewalk := Color("c9c6bc")
    var paint := Color("f6f3e5")
    for road in ROAD_LINES:
        # Two-way streets and separated sidewalks; 0 on Y is the ground level.
        _box(Vector3(12.0, 0.055, 238.0), Vector3(road, 0.025, 0.0), asphalt)
        _box(Vector3(238.0, 0.055, 12.0), Vector3(0.0, 0.027, road), asphalt)
        for direction in [-1.0, 1.0]:
            _box(Vector3(3.0, 0.13, 238.0), Vector3(road + direction * 7.65, 0.07, 0.0), sidewalk)
            _box(Vector3(238.0, 0.13, 3.0), Vector3(0.0, 0.071, road + direction * 7.65), sidewalk)
            _box(Vector3(0.18, 0.05, 238.0), Vector3(road + direction * 6.06, 0.08, 0.0), curb)
            _box(Vector3(238.0, 0.05, 0.18), Vector3(0.0, 0.08, road + direction * 6.06), curb)
        for i in range(-12, 13):
            # Center lane marking (leave gaps around intersections).
            var v := float(i) * 9.0
            if abs(v + 60.0) > 13.0 and abs(v) > 13.0 and abs(v - 60.0) > 13.0:
                _box(Vector3(0.14, 0.015, 4.0), Vector3(road, 0.07, v), paint)
                _box(Vector3(4.0, 0.015, 0.14), Vector3(v, 0.07, road), paint)

    for rx in ROAD_LINES:
        for rz in ROAD_LINES:
            _create_crosswalk(rx, rz)

func _create_crosswalk(rx: float, rz: float) -> void:
    var stripe := Color("f6f4e8")
    for i in range(7):
        var step := -4.5 + float(i) * 1.5
        # Two crossings before the intersection, with good pedestrian visibility.
        _box(Vector3(0.88, 0.016, 2.15), Vector3(rx + step, 0.083, rz + 13.5), stripe)
        _box(Vector3(2.15, 0.016, 0.88), Vector3(rx + 13.5, 0.083, rz + step), stripe)

func _create_city_blocks() -> void:
    var lot_index := 0
    for x in LOT_LINES:
        for z in LOT_LINES:
            lot_index += 1
            _create_lot(x, z, lot_index)

func _create_lot(cx: float, cz: float, index: int) -> void:
    # Each plot gets a court, one stylized building, and a few trees.
    _box(Vector3(41.0, 0.04, 41.0), Vector3(cx, 0.018, cz), Color("a8c98b"))
    _box(Vector3(29.0, 0.05, 29.0), Vector3(cx, 0.045, cz), Color("b3a99a"))
    var width := rng.randf_range(19.0, 26.0)
    var depth := rng.randf_range(18.0, 25.0)
    var floors := rng.randi_range(2, 6)
    var primary: Color = building_palette[rng.randi_range(0, building_palette.size() - 1)]
    var storefront := index == 11 or index == 12
    _create_building(Vector3(cx, 0.0, cz), width, depth, floors, primary, storefront)

    for corner in [Vector2(-17.0, -17.0), Vector2(17.0, -17.0), Vector2(-17.0, 17.0), Vector2(17.0, 17.0)]:
        if rng.randf() > 0.16:
            _create_tree(Vector3(cx + corner.x, 0.0, cz + corner.y), rng.randf_range(2.3, 3.7))

    # A grassy square where the player can walk between the paths.
    if index % 4 == 0:
        _create_bench(Vector3(cx + 15.4, 0.0, cz - 11.0), rng.randf_range(-1.0, 1.0))

func _create_building(center: Vector3, width: float, depth: float, floors: int, color: Color, storefront: bool) -> void:
    var height := float(floors) * 3.0
    var x := center.x
    var z := center.z
    var window_glass := Color("78a2bb") if rng.randf() > 0.5 else Color("a5cde0")
    var roof := color.darkened(0.23)

    _box(Vector3(width + 1.3, 0.4, depth + 1.3), Vector3(x, 0.2, z), Color("d4d2c9"))
    _box(Vector3(width, height, depth), Vector3(x, height * 0.5 + 0.4, z), color, true)
    _box(Vector3(width + 1.0, 0.52, depth + 1.0), Vector3(x, height + 0.7, z), roof)
    _box(Vector3(width + 0.9, 0.23, 0.16), Vector3(x, height + 0.4, z - depth * 0.5), Color("faf2e1"))

    # Windows on the four sides, distributed according to available wall width.
    var front_window_count: int = maxi(2, int(width / 4.0))
    var side_window_count: int = maxi(2, int(depth / 4.2))
    for floor_index in range(floors):
        var wy := 2.15 + float(floor_index) * 3.0
        for j in range(front_window_count):
            var local_x := -width * 0.5 + (float(j) + 0.5) * width / float(front_window_count)
            for side in [-1.0, 1.0]:
                _box(Vector3(1.25, 1.4, 0.08), Vector3(x + local_x, wy, z + side * (depth * 0.5 + 0.045)), window_glass)
                _box(Vector3(1.48, 0.12, 0.15), Vector3(x + local_x, wy - 0.77, z + side * (depth * 0.5 + 0.065)), Color("e9eced"))
        for j in range(side_window_count):
            var local_z := -depth * 0.5 + (float(j) + 0.5) * depth / float(side_window_count)
            for side in [-1.0, 1.0]:
                _box(Vector3(0.08, 1.38, 1.24), Vector3(x + side * (width * 0.5 + 0.044), wy, z + local_z), window_glass)

    # Store or apartment entrance on the street-facing facade.
    _box(Vector3(2.55, 2.7, 0.12), Vector3(x, 1.76, z - depth * 0.5 - 0.08), Color("4e6571"))
    _box(Vector3(3.3, 0.20, 1.5), Vector3(x, 3.17, z - depth * 0.5 - 0.55), Color("f9dd9c"))
    _box(Vector3(2.3, 0.12, 0.15), Vector3(x, 1.96, z - depth * 0.5 - 0.17), Color("c4e7ec"))

    if storefront:
        _box(Vector3(width * 0.75, 0.75, 0.22), Vector3(x, 3.65, z - depth * 0.5 - 0.17), Color("e5a35f"))
        _box(Vector3(4.0, 2.2, 0.12), Vector3(x + width * 0.24, 1.65, z - depth * 0.5 - 0.08), Color("74b9d1"))
        _box(Vector3(4.0, 2.2, 0.12), Vector3(x - width * 0.24, 1.65, z - depth * 0.5 - 0.08), Color("74b9d1"))
        var sign := Label3D.new()
        sign.text = "БУЛОЧНАЯ"
        sign.font_size = 56
        sign.pixel_size = 0.006
        sign.modulate = Color("3f261a")
        sign.position = Vector3(x, 3.7, z - depth * 0.5 - 0.32)
        sign.no_depth_test = false
        add_child(sign)

func _create_tree(location: Vector3, size: float) -> void:
    var trunk := Color("795c47")
    var leaf := Color("448d61") if rng.randf() > 0.5 else Color("5aa66d")
    _cylinder(0.23, size, location + Vector3(0, size * 0.5, 0), trunk)
    _sphere(size * 0.38, location + Vector3(0, size + 0.40, 0), leaf)
    _sphere(size * 0.27, location + Vector3(-0.56, size + 0.32, 0.25), leaf.lightened(0.10))
    _sphere(size * 0.26, location + Vector3(0.55, size + 0.2, -0.3), leaf.darkened(0.12))

func _create_bench(location: Vector3, rotation: float) -> void:
    var root := Node3D.new()
    root.position = location
    root.rotation.y = rotation
    add_child(root)
    _box(Vector3(2.0, 0.15, 0.6), Vector3(0, 0.74, 0), Color("ad7253"), false, root)
    _box(Vector3(2.0, 0.65, 0.14), Vector3(0, 1.12, 0.27), Color("ad7253"), false, root)
    for x in [-0.8, 0.8]:
        _box(Vector3(0.11, 0.70, 0.11), Vector3(x, 0.35, -0.10), Color("353c45"), false, root)

func _create_car(location: Vector3, direction: float, color: Color) -> void:
    var root := Node3D.new()
    root.position = location
    root.rotation.y = direction
    add_child(root)
    _box(Vector3(1.88, 0.64, 3.6), Vector3(0, 0.7, 0), color, false, root)
    _box(Vector3(1.57, 0.72, 1.95), Vector3(0, 1.25, 0.12), color.lightened(0.06), false, root)
    _box(Vector3(1.46, 0.39, 0.08), Vector3(0, 1.35, -0.89), Color("7bb3c4"), false, root)
    _box(Vector3(1.46, 0.39, 0.08), Vector3(0, 1.35, 1.12), Color("7bb3c4"), false, root)
    for side in [-1.0, 1.0]:
        for z in [-1.13, 1.14]:
            var wheel := _cylinder(0.36, 0.18, Vector3(side * 0.93, 0.36, z), Color("202631"), root)
            wheel.rotation.z = PI * 0.5
        _box(Vector3(0.20, 0.17, 0.34), Vector3(side * 0.73, 0.72, -1.76), Color("fff0bf"), false, root)
        _box(Vector3(0.20, 0.17, 0.34), Vector3(side * 0.73, 0.72, 1.76), Color("e44e57"), false, root)

func _create_streetlamp(location: Vector3) -> void:
    _cylinder(0.11, 5.5, location + Vector3(0, 2.75, 0), Color("526c79"))
    _box(Vector3(1.0, 0.14, 0.14), location + Vector3(0.48, 5.43, 0), Color("526c79"))
    _box(Vector3(0.63, 0.08, 0.45), location + Vector3(0.88, 5.28, 0), Color("fff0ba"))

func _create_bus_stop(location: Vector3) -> void:
    var root := Node3D.new()
    root.position = location
    add_child(root)
    _box(Vector3(5.0, 0.24, 2.0), Vector3(0, 2.85, 0), Color("31809d"), false, root)
    for x in [-2.2, 2.2]:
        for z in [-0.8, 0.8]:
            _box(Vector3(0.13, 2.8, 0.13), Vector3(x, 1.4, z), Color("496470"), false, root)
    _box(Vector3(4.5, 2.3, 0.10), Vector3(0, 1.4, 0.87), Color("a3d9dd"), false, root)
    _box(Vector3(3.3, 0.15, 0.6), Vector3(0, 0.73, 0), Color("a77b59"), false, root)
    _cylinder(0.10, 4.0, location + Vector3(4.3, 2.0, 0), Color("466679"))
    _box(Vector3(0.85, 0.85, 0.17), location + Vector3(4.3, 3.7, 0), Color("2d8bc2"))

func _create_street_props() -> void:
    var colors := [Color("dc7761"), Color("ecc76f"), Color("6fa6bc"), Color("a5b9c8"), Color("829e78")]
    for road in ROAD_LINES:
        for side in [-1.0, 1.0]:
            for z in [-96.0, -44.0, 25.0, 96.0]:
                var at := Vector3(road + side * 9.5, 0.0, z)
                # Lamps are on a sidewalk edge, outside the main car route.
                _create_streetlamp(at)

    for i in range(19):
        var road: float = ROAD_LINES[rng.randi_range(0, ROAD_LINES.size() - 1)]
        var longitudinal := rng.randf_range(-109.0, 109.0)
        var side := -1.0 if rng.randf() < 0.5 else 1.0
        var horizontal := rng.randf() < 0.5
        var car_position := Vector3(longitudinal, 0, road + side * 4.35) if horizontal else Vector3(road + side * 4.35, 0, longitudinal)
        var rotation := PI * 0.5 if horizontal else 0.0
        _create_car(car_position, rotation, colors[rng.randi_range(0, colors.size() - 1)])

    _create_bus_stop(Vector3(-45.0, 0, -8.0))
    _create_bench(Vector3(14.0, 0, -11.0), 0.0)
    _create_bench(Vector3(-14.0, 0, 11.0), PI)

func _create_player() -> void:
    var player := CharacterBody3D.new()
    player.name = "MainCharacter"
    player.set_script(PlayerScript)
    player.position = Vector3(9.4, 0.12, 9.4)
    add_child(player)

func _register_key(name: String, codes: Array[int]) -> void:
    if not InputMap.has_action(name):
        InputMap.add_action(name)
    for code in codes:
        var event := InputEventKey.new()
        event.physical_keycode = code
        InputMap.action_add_event(name, event)

func _create_hud() -> void:
    _register_key("move_forward", [KEY_W, KEY_UP])
    _register_key("move_back", [KEY_S, KEY_DOWN])
    _register_key("move_left", [KEY_A, KEY_LEFT])
    _register_key("move_right", [KEY_D, KEY_RIGHT])
    _register_key("jump", [KEY_SPACE])
    _register_key("run", [KEY_SHIFT])

    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(22, 20)
    panel.custom_minimum_size = Vector2(520, 92)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.035, 0.075, 0.125, 0.85)
    panel_style.corner_radius_top_left = 14
    panel_style.corner_radius_top_right = 14
    panel_style.corner_radius_bottom_left = 14
    panel_style.corner_radius_bottom_right = 14
    panel_style.border_width_left = 2
    panel_style.border_color = Color("58d4c4")
    panel.add_theme_stylebox_override("panel", panel_style)
    layer.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 3)
    panel.add_child(content)
    var title := Label.new()
    title.text = "  ДОРОГА В ШКОЛУ  /  ПРОТОТИП 0.1"
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color("7cf0d9"))
    content.add_child(title)
    var keys := Label.new()
    keys.text = "  WASD — идти     Shift — бег     Пробел — прыжок"
    keys.add_theme_font_size_override("font_size", 16)
    keys.add_theme_color_override("font_color", Color("eaf3f4"))
    content.add_child(keys)
    var tip := Label.new()
    tip.text = "  Мышь — камера     Esc — курсор     N — другой город"
    tip.add_theme_font_size_override("font_size", 14)
    tip.add_theme_color_override("font_color", Color("afc5d4"))
    content.add_child(tip)

    var bottom := Label.new()
    bottom.text = "Пробная версия: персонаж и город созданы программно. Дальше добавим реальные ориентиры и задания."
    bottom.position = Vector2(24, 676)
    bottom.add_theme_font_size_override("font_size", 13)
    bottom.add_theme_color_override("font_color", Color("173349"))
    layer.add_child(bottom)
