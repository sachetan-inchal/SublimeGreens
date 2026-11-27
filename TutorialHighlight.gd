extends Node3D
class_name TutorialHighlight

signal player_entered(highlight: TutorialHighlight)
signal player_exited(highlight: TutorialHighlight)
signal player_interacted(highlight: TutorialHighlight)

@export var highlight_color: Color = Color(0.0, 0.9, 1.0, 1.0) # Cyan default
@export var label_text: String = "Tutorial Target"
@export var trigger_radius: float = 3.5
@export var snap_to_ground_on_ready: bool = true
@export var show_beam: bool = true

@onready var area: Area3D = $Area3D
@onready var collision_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var ground_ring: MeshInstance3D = $GroundRing
@onready var beacon_beam: MeshInstance3D = $BeaconBeam
@onready var floating_gem: MeshInstance3D = $FloatingGem
@onready var label_3d: Label3D = $Label3D
@onready var omni_light: OmniLight3D = $OmniLight3D

var is_player_inside: bool = false
var player_ref: Node3D = null
var pulse_time: float = 0.0
var ring_material: StandardMaterial3D
var beam_material: StandardMaterial3D
var gem_material: StandardMaterial3D

func _ready() -> void:
	# Duplicate materials to allow unique per-instance color customization without affecting others
	_setup_materials()
	set_highlight_color(highlight_color)
	set_label(label_text)
	
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
		
	if snap_to_ground_on_ready:
		call_deferred("snap_to_terrain")

func _setup_materials() -> void:
	ring_material = StandardMaterial3D.new()
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ground_ring:
		ground_ring.material_override = ring_material
		
	beam_material = StandardMaterial3D.new()
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if beacon_beam:
		beacon_beam.material_override = beam_material
		beacon_beam.visible = show_beam
		
	gem_material = StandardMaterial3D.new()
	gem_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gem_material.emission_enabled = true
	if floating_gem:
		floating_gem.material_override = gem_material

func set_highlight_color(c: Color) -> void:
	highlight_color = c
	if ring_material:
		ring_material.albedo_color = Color(c.r, c.g, c.b, 0.75)
	if beam_material:
		beam_material.albedo_color = Color(c.r, c.g, c.b, 0.35)
	if gem_material:
		gem_material.albedo_color = Color(c.r, c.g, c.b, 0.85)
		gem_material.emission = c
		gem_material.emission_energy_multiplier = 2.5
	if omni_light:
		omni_light.light_color = c
	if label_3d:
		label_3d.modulate = Color(c.r * 1.2, c.g * 1.2, c.b * 1.2, 1.0)

func set_label(txt: String) -> void:
	label_text = txt
	if label_3d:
		label_3d.text = txt

func _process(delta: float) -> void:
	pulse_time += delta
	
	# Animate floating gem rotation and bobbing
	if floating_gem:
		floating_gem.rotate_y(1.5 * delta)
		floating_gem.position.y = 1.6 + sin(pulse_time * 2.5) * 0.15
		
	# Animate ground ring pulsing scale
	if ground_ring:
		var ring_scale = 1.0 + sin(pulse_time * 3.0) * 0.08
		ground_ring.scale = Vector3(ring_scale, 1.0, ring_scale)
		
	# Update distance in 3D label if player is active
	if is_instance_valid(player_ref) and label_3d and label_3d.visible:
		var dist = global_position.distance_to(player_ref.global_position)
		if is_player_inside:
			label_3d.text = "%s\n[ Press E to Interact ]" % label_text
		else:
			label_3d.text = "%s\n(%.1fm)" % [label_text, dist]

func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			emit_signal("player_interacted", self)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body is CharacterBody3D:
		is_player_inside = true
		player_ref = body
		emit_signal("player_entered", self)

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player" or body is CharacterBody3D:
		is_player_inside = false
		emit_signal("player_exited", self)

func snap_to_terrain() -> void:
	var space_state = get_world_3d().direct_space_state if get_world_3d() else null
	if not space_state:
		return
	var ray_origin = Vector3(global_position.x, 250.0, global_position.z)
	var ray_end = Vector3(global_position.x, -50.0, global_position.z)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	if area:
		query.exclude = [area.get_rid()]
	var result = space_state.intersect_ray(query)
	if result:
		global_position.y = result.position.y
