extends Node3D
class_name TransformDemoObject

signal demo_completed(type: String)
signal player_interacted()

@onready var cube_pivot: Node3D = $CubePivot
@onready var cube_mesh: MeshInstance3D = $CubePivot/CubeMesh
@onready var axis_x: MeshInstance3D = $CubePivot/AxisX # Red
@onready var axis_y: MeshInstance3D = $CubePivot/AxisY # Green
@onready var axis_z: MeshInstance3D = $CubePivot/AxisZ # Blue
@onready var ghost_mesh: MeshInstance3D = $GhostMesh
@onready var prompt_label: Label3D = $PromptLabel
@onready var area_3d: Area3D = $Area3D

var is_animating: bool = false
var initial_cube_transform: Transform3D
var is_player_inside: bool = false
var current_demo_mode: String = "none" # "translation", "rotation", "scaling", "composite"
var active_tween: Tween

func _ready() -> void:
	if cube_pivot:
		initial_cube_transform = cube_pivot.transform
	if ghost_mesh:
		ghost_mesh.visible = false
	if area_3d:
		area_3d.body_entered.connect(_on_body_entered)
		area_3d.body_exited.connect(_on_body_exited)
	call_deferred("_snap_to_terrain")

func _snap_to_terrain() -> void:
	var space_state = get_world_3d().direct_space_state if get_world_3d() else null
	if not space_state:
		return
	var ray_origin = Vector3(global_position.x, 250.0, global_position.z)
	var ray_end = Vector3(global_position.x, -50.0, global_position.z)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	if area_3d:
		query.exclude = [area_3d.get_rid()]
	var result = space_state.intersect_ray(query)
	if result:
		global_position.y = result.position.y

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body is CharacterBody3D:
		is_player_inside = true
		_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player" or body is CharacterBody3D:
		is_player_inside = false
		if prompt_label:
			prompt_label.visible = false

func _update_prompt() -> void:
	if not prompt_label or not is_player_inside:
		return
	prompt_label.visible = true
	match current_demo_mode:
		"translation":
			prompt_label.text = "Press [E] to Run Translation: P' = P + T"
		"rotation":
			prompt_label.text = "Press [E] to Run Rotation: P' = R(θ) × P"
		"scaling":
			prompt_label.text = "Press [E] to Run Scaling: P' = S × P"
		"composite":
			prompt_label.text = "Press [E] to Run Composite: P' = T × R × S × P"
		_:
			prompt_label.text = "Transformation Demo Gizmo"

func set_demo_mode(mode: String) -> void:
	current_demo_mode = mode
	_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			run_current_demo()
			emit_signal("player_interacted")

func run_current_demo() -> void:
	match current_demo_mode:
		"translation":
			demonstrate_translation(Vector3(2.5, 1.2, 0.0))
		"rotation":
			demonstrate_rotation(Vector3.UP, deg_to_rad(90))
		"scaling":
			demonstrate_scaling(Vector3(1.8, 1.8, 1.8))
		"composite":
			demonstrate_composite(Vector3(2.0, 1.0, 0.0), Vector3.UP, deg_to_rad(90), Vector3(1.5, 1.5, 1.5))
		_:
			demonstrate_composite(Vector3(2.0, 1.0, 0.0), Vector3.UP, deg_to_rad(90), Vector3(1.5, 1.5, 1.5))

func demonstrate_translation(offset: Vector3) -> void:
	if is_animating: return
	is_animating = true
	_show_ghost(true)
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var target_pos = initial_cube_transform.origin + offset
	active_tween.tween_property(cube_pivot, "position", target_pos, 1.2)
	active_tween.tween_interval(1.0)
	active_tween.tween_property(cube_pivot, "position", initial_cube_transform.origin, 0.8)
	active_tween.tween_callback(func():
		_show_ghost(false)
		is_animating = false
		emit_signal("demo_completed", "translation")
	)

func demonstrate_rotation(axis: Vector3, angle_rad: float) -> void:
	if is_animating: return
	is_animating = true
	_show_ghost(true)
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var target_rot = cube_pivot.rotation + (axis.normalized() * angle_rad)
	active_tween.tween_property(cube_pivot, "rotation", target_rot, 1.4)
	active_tween.tween_interval(1.0)
	active_tween.tween_property(cube_pivot, "rotation", initial_cube_transform.basis.get_euler(), 0.8)
	active_tween.tween_callback(func():
		_show_ghost(false)
		is_animating = false
		emit_signal("demo_completed", "rotation")
	)

func demonstrate_scaling(scale_target: Vector3) -> void:
	if is_animating: return
	is_animating = true
	_show_ghost(true)
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	active_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(cube_pivot, "scale", scale_target, 1.0)
	active_tween.tween_interval(0.8)
	active_tween.tween_property(cube_pivot, "scale", Vector3(0.5, 0.5, 0.5), 0.8)
	active_tween.tween_interval(0.5)
	active_tween.tween_property(cube_pivot, "scale", initial_cube_transform.basis.get_scale(), 0.6)
	active_tween.tween_callback(func():
		_show_ghost(false)
		is_animating = false
		emit_signal("demo_completed", "scaling")
	)

func demonstrate_composite(t_offset: Vector3, r_axis: Vector3, r_angle: float, s_target: Vector3) -> void:
	if is_animating: return
	is_animating = true
	_show_ghost(true)
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# 1. Scale
	active_tween.tween_property(cube_pivot, "scale", s_target, 0.8)
	# 2. Rotate
	var target_rot = cube_pivot.rotation + (r_axis.normalized() * r_angle)
	active_tween.tween_property(cube_pivot, "rotation", target_rot, 0.8)
	# 3. Translate
	var target_pos = initial_cube_transform.origin + t_offset
	active_tween.tween_property(cube_pivot, "position", target_pos, 0.8)
	active_tween.tween_interval(1.2)
	# Reset
	active_tween.tween_property(cube_pivot, "transform", initial_cube_transform, 1.0)
	active_tween.tween_callback(func():
		_show_ghost(false)
		is_animating = false
		emit_signal("demo_completed", "composite")
	)

func _show_ghost(show: bool) -> void:
	if ghost_mesh:
		ghost_mesh.visible = show
		if show:
			ghost_mesh.transform = initial_cube_transform
