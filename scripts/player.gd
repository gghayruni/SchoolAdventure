extends CharacterBody3D
## Controllable third-person cartoon character. No external model required.

const WALK_SPEED = 5.0
const RUN_SPEED = 9.5
const JUMP_SPEED = 7.0
const GRAVITY = 18.0
const MOUSE_SENSITIVITY = 0.0035

var model: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var camera: Camera3D
var camera_yaw := 0.0
var camera_pitch := 0.12
var animation_time := 0.0
var camera_initialized := false

func _ready() -> void:
    name = "Наш герой"
    _build_body()
    _build_character()
    camera = Camera3D.new()
    camera.name = "ThirdPersonCamera"
    camera.current = true
    camera.fov = 73.0
    camera.near = 0.15
    get_parent().call_deferred("add_child", camera)
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_LEFT:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    elif event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        camera_yaw -= event.relative.x * MOUSE_SENSITIVITY
        camera_pitch = clamp(camera_pitch + event.relative.y * MOUSE_SENSITIVITY, -0.48, 0.65)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = JUMP_SPEED

    var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var input_direction := Vector3(move_input.x, 0.0, move_input.y)
    var direction := (Basis(Vector3.UP, camera_yaw) * input_direction).normalized()
    var running := Input.is_action_pressed("run")
    var speed := RUN_SPEED if running else WALK_SPEED
    var acceleration := 12.0 if is_on_floor() else 3.0
    velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
    velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
    move_and_slide()

    if direction.length_squared() > 0.01:
        var desired_yaw := atan2(-direction.x, -direction.z)
        model.rotation.y = lerp_angle(model.rotation.y, desired_yaw, min(1.0, delta * 12.0))
        animation_time += delta * (13.0 if running else 9.0)
        left_leg.rotation.x = sin(animation_time) * (0.60 if running else 0.43)
        right_leg.rotation.x = -left_leg.rotation.x
        left_arm.rotation.x = -left_leg.rotation.x * 0.75
        right_arm.rotation.x = left_leg.rotation.x * 0.75
    else:
        left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.0, min(1.0, 8.0 * delta))
        right_leg.rotation.x = lerpf(right_leg.rotation.x, 0.0, min(1.0, 8.0 * delta))
        left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.0, min(1.0, 8.0 * delta))
        right_arm.rotation.x = lerpf(right_arm.rotation.x, 0.0, min(1.0, 8.0 * delta))

    if is_instance_valid(camera) and camera.is_inside_tree():
        var target := global_position + Vector3(0.0, 1.45, 0.0)
        var radius := 6.5 * cos(camera_pitch)
        var offset := Vector3(sin(camera_yaw) * radius, 2.7 + sin(camera_pitch) * 5.0, cos(camera_yaw) * radius)
        var wanted := global_position + offset
        if not camera_initialized:
            camera.global_position = wanted
            camera_initialized = true
        else:
            camera.global_position = camera.global_position.lerp(wanted, min(1.0, delta * 7.0))
        camera.look_at(target, Vector3.UP)

func _build_body() -> void:
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.34
    capsule.height = 1.7
    var collider := CollisionShape3D.new()
    collider.name = "PlayerCollider"
    collider.shape = capsule
    collider.position.y = 0.88
    add_child(collider)

func _material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.92
    return material

func _box(parent: Node3D, scale: Vector3, location: Vector3, color: Color) -> void:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = scale
    mesh.mesh = box
    mesh.material_override = _material(color)
    mesh.position = location
    parent.add_child(mesh)

func _ball(parent: Node3D, scale: Vector3, location: Vector3, color: Color) -> void:
    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.5
    sphere.height = 1.0
    sphere.radial_segments = 12
    sphere.rings = 6
    mesh.mesh = sphere
    mesh.material_override = _material(color)
    mesh.scale = scale
    mesh.position = location
    parent.add_child(mesh)

func _limb(parent: Node3D, height: float, width: float, color: Color) -> void:
    var mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = width
    cylinder.bottom_radius = width
    cylinder.height = height
    cylinder.radial_segments = 8
    mesh.mesh = cylinder
    mesh.material_override = _material(color)
    mesh.position.y = -height * 0.5
    parent.add_child(mesh)

func _build_character() -> void:
    model = Node3D.new()
    model.name = "CartoonBoy"
    add_child(model)
    var skin := Color("ffcd9d")
    var jacket := Color("23aec3")
    var jeans := Color("344a88")
    var hair := Color("32251f")

    _box(model, Vector3(0.72, 0.85, 0.40), Vector3(0, 1.17, 0), jacket)
    _box(model, Vector3(0.64, 0.22, 0.42), Vector3(0, 0.78, 0), Color("154e85"))
    _ball(model, Vector3(0.67, 0.72, 0.67), Vector3(0, 1.98, -0.02), skin)
    _ball(model, Vector3(0.70, 0.27, 0.66), Vector3(0, 2.22, -0.02), hair)
    # Face looks toward local -Z.
    _ball(model, Vector3(0.075, 0.088, 0.07), Vector3(-0.15, 2.02, -0.32), Color("17212e"))
    _ball(model, Vector3(0.075, 0.088, 0.07), Vector3(0.15, 2.02, -0.32), Color("17212e"))
    _box(model, Vector3(0.13, 0.035, 0.025), Vector3(0, 1.84, -0.35), Color("aa5960"))

    # Backpack (back is local +Z).
    _box(model, Vector3(0.55, 0.68, 0.34), Vector3(0, 1.18, 0.37), Color("ea7650"))
    _box(model, Vector3(0.37, 0.22, 0.36), Vector3(0, 0.98, 0.56), Color("e14d52"))
    _box(model, Vector3(0.10, 0.84, 0.12), Vector3(-0.30, 1.29, 0.24), Color("f0bf66"))
    _box(model, Vector3(0.10, 0.84, 0.12), Vector3(0.30, 1.29, 0.24), Color("f0bf66"))

    left_arm = Node3D.new()
    left_arm.position = Vector3(-0.47, 1.53, 0)
    model.add_child(left_arm)
    _limb(left_arm, 0.59, 0.13, jacket)
    _ball(left_arm, Vector3(0.19, 0.19, 0.19), Vector3(0, -0.62, 0), skin)
    right_arm = Node3D.new()
    right_arm.position = Vector3(0.47, 1.53, 0)
    model.add_child(right_arm)
    _limb(right_arm, 0.59, 0.13, jacket)
    _ball(right_arm, Vector3(0.19, 0.19, 0.19), Vector3(0, -0.62, 0), skin)

    left_leg = Node3D.new()
    left_leg.position = Vector3(-0.21, 0.74, 0)
    model.add_child(left_leg)
    _limb(left_leg, 0.62, 0.155, jeans)
    _box(left_leg, Vector3(0.34, 0.18, 0.46), Vector3(0, -0.64, -0.07), Color("ffffff"))
    right_leg = Node3D.new()
    right_leg.position = Vector3(0.21, 0.74, 0)
    model.add_child(right_leg)
    _limb(right_leg, 0.62, 0.155, jeans)
    _box(right_leg, Vector3(0.34, 0.18, 0.46), Vector3(0, -0.64, -0.07), Color("ffffff"))
