extends Area3D
class_name AncientStoneMonolith

signal player_approached()
signal player_left()

@export var screen_active: bool = false
@onready var prompt_label: Label3D = $PromptLabel
@onready var magic_light: OmniLight3D = $MagicLight
@onready var runes_particles: CPUParticles3D = $RunesParticles
@onready var screen_quad: MeshInstance3D = $ScreenQuad
@onready var sub_viewport: SubViewport = $SubViewport
@onready var final_quiz_ui = $SubViewport/FinalQuizUI

var player_inside: bool = false
var snapped_to_ground: bool = false
var glow_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_label.visible = false
	
	# Apply SubViewport texture to the screen quad material dynamically
	call_deferred("_setup_screen_material")

func _setup_screen_material() -> void:
	if screen_quad and sub_viewport:
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = sub_viewport.get_texture()
		mat.emission_enabled = true
		mat.emission_texture = sub_viewport.get_texture()
		mat.emission = Color(0.2, 0.9, 1.0)
		mat.emission_energy_multiplier = 1.2
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		screen_quad.material_override = mat

func _physics_process(_delta: float) -> void:
	if not snapped_to_ground:
		_snap_to_terrain()

func _process(delta: float) -> void:
	glow_timer += delta
	# Pulsing rune glow
	if magic_light:
		var pulse = sin(glow_timer * 2.5) * 0.5 + 1.2
		magic_light.light_energy = pulse if screen_active else 0.4

func _snap_to_terrain() -> void:
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return
	var ray_origin = Vector3(global_position.x, 250.0, global_position.z)
	var ray_end = Vector3(global_position.x, -100.0, global_position.z)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	if result:
		global_position.y = result.position.y
		snapped_to_ground = true

func activate_magical_screen() -> void:
	screen_active = true
	if magic_light:
		magic_light.visible = true
	if runes_particles:
		runes_particles.emitting = true
	if final_quiz_ui and final_quiz_ui.has_method("show_invitation"):
		final_quiz_ui.show_invitation()
	
	# Update prompt
	if player_inside:
		prompt_label.text = "[E] Interact with Ancient Stone Screen"
		prompt_label.visible = true

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body is CharacterBody3D:
		player_inside = true
		emit_signal("player_approached")
		prompt_label.visible = true
		if not screen_active:
			prompt_label.text = "Ancient Stone of Evaluation (Locked until all 5 Units Complete)"
		else:
			prompt_label.text = "[E] Interact with Ancient Stone Screen"

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player" or body is CharacterBody3D:
		player_inside = false
		emit_signal("player_left")
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_inside and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			if screen_active:
				if final_quiz_ui:
					if not final_quiz_ui.is_quiz_open:
						final_quiz_ui._begin_quiz()
					prompt_label.text = "[1-4 / A-D] Select Answer | [Space] Next | [Esc] Close"
			elif final_quiz_ui:
				final_quiz_ui.show_invitation()
				prompt_label.text = "[Y / Enter] Start | [N] Later"

	# Forward keyboard input into the sub_viewport so controls inside work seamlessly without mouse
	if player_inside and sub_viewport:
		sub_viewport.push_input(event)
