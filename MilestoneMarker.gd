extends Area3D
class_name MilestoneMarker

@export var milestone_id: String = "m1_trees"
@export var title: String = "Milestone 1: Procedural Cuboid Tree"
@export var syllabus_unit: String = "Unit I & Unit V: Primitives, Polygons & Geometric Modelling"
@export_multiline var question: String = "In Chunk.gd, a tree trunk and its foliage are modeled as 3D box shapes using SurfaceTool. How are quad faces converted and rendered in the graphics pipeline?"
@export var options: Array[String] = [
	"A) Each quad face is decomposed into 2 triangles using indexed vertices with associated normal and UV attributes.",
	"B) Each quad is submitted as an arbitrary n-gon without index buffers.",
	"C) Cubes are always rendered as voxel point clouds without polygonal surfaces.",
	"D) The graphics hardware draws each face as an independent Bézier patch."
]
@export var correct_option_index: int = 0
@export_multiline var explanation: String = "Polygonal 3D shapes are triangulated (2 triangles per quad face) with per-vertex indices, normals, and UVs for GPU rendering."

@onready var beacon_mesh: MeshInstance3D = $Beacon
@onready var prompt_label: Label3D = $PromptLabel
var player_inside: bool = false
var snapped_to_ground: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_label.visible = false

func _physics_process(_delta: float) -> void:
	if not snapped_to_ground:
		_snap_to_terrain()

func _process(delta: float) -> void:
	# Subtle floating rotation for beacon
	if beacon_mesh:
		beacon_mesh.rotate_y(1.2 * delta)

func _snap_to_terrain() -> void:
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return

	# Cast a ray downwards through the terrain collision mesh
	var ray_origin = Vector3(global_position.x, 250.0, global_position.z)
	var ray_end = Vector3(global_position.x, -100.0, global_position.z)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	# Exclude self so the ray does not hit the marker's own Area3D
	query.exclude = [get_rid()]

	var result = space_state.intersect_ray(query)
	if result:
		global_position.y = result.position.y
		snapped_to_ground = true

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body is CharacterBody3D:
		player_inside = true
		prompt_label.visible = true
		# Inform QuizUI about this milestone
		var quiz_ui = get_tree().root.find_child("QuizUI", true, false)
		if quiz_ui and quiz_ui.has_method("notify_marker_entered"):
			quiz_ui.notify_marker_entered(self)

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player" or body is CharacterBody3D:
		player_inside = false
		prompt_label.visible = false
		var quiz_ui = get_tree().root.find_child("QuizUI", true, false)
		if quiz_ui and quiz_ui.has_method("notify_marker_exited"):
			quiz_ui.notify_marker_exited(self)
