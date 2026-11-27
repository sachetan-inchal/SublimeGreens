extends CanvasLayer
class_name NarrativeTutorial

signal milestone_changed(milestone_idx: int)
signal tutorial_completed()

# --- Node Exports / References ---
@export var player: CharacterBody3D
@export var sun_light: DirectionalLight3D

# --- UI References ---
@onready var left_panel: PanelContainer = find_child("LeftPanelContainer", true, false)
@onready var unit_badge: Label = find_child("UnitBadge", true, false)
@onready var milestone_label: Label = find_child("MilestoneLabel", true, false)
@onready var concept_title: Label = find_child("ConceptTitle", true, false)
@onready var explanation_label: Label = find_child("ExplanationLabel", true, false)
@onready var action_box_label: Label = find_child("ActionLabel", true, false)
@onready var code_tag_label: Label = find_child("CodeTag", true, false)
@onready var prev_button: Button = find_child("PrevButton", true, false)
@onready var next_button: Button = find_child("NextButton", true, false)
@onready var unit_selector: OptionButton = find_child("UnitSelector", true, false)

# Objective HUD (Top Center)
@onready var objective_hud: PanelContainer = find_child("ObjectiveHUD", true, false)
@onready var hud_unit_label: Label = find_child("UnitLabel", true, false)
@onready var hud_objective_label: Label = find_child("ObjectiveLabel", true, false)
@onready var hud_distance_label: Label = find_child("DistanceLabel", true, false)
@onready var mouse_mode_btn: Button = find_child("MouseModeBtn", true, false)

# Right-side formula panel
@onready var formula_panel: TutorialFormulaPanel = find_child("TutorialFormulaPanel", true, false)

# Floating Highlight & Demo references (dynamically spawned or assigned)
var active_highlight: TutorialHighlight
var transform_gizmo: TransformDemoObject

# Dedicated individual targets
var glowing_grass: MeshInstance3D
var glowing_grass_light: OmniLight3D
var glowing_grass_base_scale: Vector3 = Vector3.ONE

var glowing_tree: MeshInstance3D
var glowing_tree_light: OmniLight3D
var glowing_tree_base_scale: Vector3 = Vector3.ONE

# Font size scaling state (Ctrl +/-)
var _base_font_sizes: Dictionary = {}
var _font_size_offset: int = 0
var font_hint_timer: float = 0.0

# --- State ---
var current_milestone_idx: int = 1
var is_active: bool = true
var camera: Camera3D
var initial_player_spawn: Vector3 = Vector3(0, 44.5, 0)
var milestones: Array[Dictionary] = []

# Milestones tracking state
var milestone_timer: float = 0.0
var walk_time_tracker: float = 0.0
var sprint_time_tracker: float = 0.0
var jump_performed: bool = false
var camera_pitch_max: float = 0.0
var camera_pitch_min: float = 0.0
var initial_camera_yaw: float = 0.0
var yaw_accumulated: float = 0.0
var last_cam_forward: Vector3 = Vector3.ZERO
var lod_moved_away: bool = false

# Tweens
var dialogue_tween: Tween
var typewriter_tween: Tween

const SAVE_PATH: String = "user://tutorial_cgvr_progress.cfg"

func _ready() -> void:
	_resolve_ui_nodes()
	_init_font_scaling()
	_init_milestones_data()
	_resolve_nodes()
	_setup_ui_events()
	_setup_world_objects()
	
	# Load or start milestone 1
	var saved_idx = _load_progress()
	set_milestone(saved_idx)

func _init_font_scaling() -> void:
	_base_font_sizes.clear()
	_collect_font_nodes(self)

func _collect_font_nodes(root: Node) -> void:
	for child in root.get_children():
		if child is RichTextLabel:
			var sz = child.get_theme_font_size("normal_font_size")
			if sz <= 0: sz = 9
			_base_font_sizes[child] = sz
		elif child is Label:
			var sz = child.get_theme_font_size("font_size")
			if sz <= 0: sz = 10
			_base_font_sizes[child] = sz
		elif child is Button:
			var sz = child.get_theme_font_size("font_size")
			if sz <= 0: sz = 9
			_base_font_sizes[child] = sz
		_collect_font_nodes(child)

func _adjust_font_size(delta: int, reset: bool = false) -> void:
	if reset:
		_font_size_offset = 0
	else:
		_font_size_offset = clamp(_font_size_offset + delta, -2, 8)
		
	for node in _base_font_sizes.keys():
		if not is_instance_valid(node): continue
		var base_sz = _base_font_sizes[node]
		var new_sz = max(7, base_sz + _font_size_offset)
		if node is RichTextLabel:
			node.add_theme_font_size_override("normal_font_size", new_sz)
			node.add_theme_font_size_override("bold_font_size", new_sz)
		else:
			node.add_theme_font_size_override("font_size", new_sz)
			
	if hud_distance_label:
		var sign_str = "+" if _font_size_offset > 0 else ""
		hud_distance_label.text = "[ Font: %s%d ]" % [sign_str, _font_size_offset]
		font_hint_timer = 1.8

func _resolve_ui_nodes() -> void:
	if not left_panel: left_panel = find_child("LeftPanelContainer", true, false)
	if not unit_badge: unit_badge = find_child("UnitBadge", true, false)
	if not milestone_label: milestone_label = find_child("MilestoneLabel", true, false)
	if not concept_title: concept_title = find_child("ConceptTitle", true, false)
	if not explanation_label: explanation_label = find_child("ExplanationLabel", true, false)
	if not action_box_label: action_box_label = find_child("ActionLabel", true, false)
	if not code_tag_label: code_tag_label = find_child("CodeTag", true, false)
	if not prev_button: prev_button = find_child("PrevButton", true, false)
	if not next_button: next_button = find_child("NextButton", true, false)
	if not unit_selector: unit_selector = find_child("UnitSelector", true, false)
	if not objective_hud: objective_hud = find_child("ObjectiveHUD", true, false)
	if not hud_unit_label: hud_unit_label = find_child("UnitLabel", true, false)
	if not hud_objective_label: hud_objective_label = find_child("ObjectiveLabel", true, false)
	if not hud_distance_label: hud_distance_label = find_child("DistanceLabel", true, false)
	if not mouse_mode_btn: mouse_mode_btn = find_child("MouseModeBtn", true, false)
	if not formula_panel: formula_panel = find_child("TutorialFormulaPanel", true, false)

func _resolve_nodes() -> void:
	if not player:
		player = get_node_or_null("../Player")
		if not player:
			player = get_tree().root.find_child("Player", true, false)
			
	if not sun_light:
		sun_light = get_node_or_null("../DirectionalLight3D")
		if not sun_light:
			sun_light = get_tree().root.find_child("DirectionalLight3D", true, false)
			
	if player:
		camera = player.get_node_or_null("Node3D/SpringArm3D/Camera3D")
		if not camera:
			camera = player.find_child("Camera3D", true, false)
			
	if not camera:
		camera = get_viewport().get_camera_3d()

func _setup_ui_events() -> void:
	if prev_button:
		prev_button.pressed.connect(func(): set_milestone(current_milestone_idx - 1))
	if next_button:
		next_button.pressed.connect(_on_next_button_pressed)
	if mouse_mode_btn:
		mouse_mode_btn.pressed.connect(_on_mouse_mode_btn_pressed)
		_update_mouse_mode_ui()
		
	if unit_selector:
		unit_selector.clear()
		unit_selector.add_item("Jump to Unit I (Primitives & Shaders)", 1)
		unit_selector.add_item("Jump to Unit II (Input, Audio & UI)", 5)
		unit_selector.add_item("Jump to Unit III (3D Transformations)", 9)
		unit_selector.add_item("Jump to Unit IV (Viewing, Culling & LOD)", 13)
		unit_selector.add_item("Jump to Unit V (Modelling & Kinematics)", 17)
		unit_selector.item_selected.connect(func(idx):
			var target_m = unit_selector.get_item_id(idx)
			set_milestone(target_m)
		)

func _on_mouse_mode_btn_pressed() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_mouse_mode_ui()

func _update_mouse_mode_ui() -> void:
	if not mouse_mode_btn:
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_mode_btn.text = "[ 🔒 LOOK | Tab: Cursor ]"
		mouse_mode_btn.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	else:
		mouse_mode_btn.text = "[ 🖱️ CURSOR | Tab: Look ]"
		mouse_mode_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))

func _setup_world_objects() -> void:
	# Create the dynamic TutorialHighlight instance if not existing
	var hl_scene = load("res://TutorialHighlight.tscn")
	if hl_scene:
		active_highlight = hl_scene.instantiate()
		get_parent().call_deferred("add_child", active_highlight)
		active_highlight.player_entered.connect(_on_highlight_entered)
		active_highlight.player_interacted.connect(_on_highlight_interacted)
		
	# Create the TransformDemoObject for Unit III if not existing
	var demo_scene = load("res://TransformDemoObject.tscn")
	if demo_scene:
		transform_gizmo = demo_scene.instantiate()
		transform_gizmo.position = Vector3(8.0, 44.5, -2.0) # Near spawn
		get_parent().call_deferred("add_child", transform_gizmo)
		transform_gizmo.demo_completed.connect(_on_transform_demo_completed)
		transform_gizmo.player_interacted.connect(_on_transform_demo_interacted)

	_setup_glowing_grass()
	_setup_glowing_tree()

func _setup_glowing_grass() -> void:
	glowing_grass = MeshInstance3D.new()
	glowing_grass.name = "GlowingGrassBlade"
	glowing_grass.visible = false
	
	var grass_mat = StandardMaterial3D.new()
	grass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grass_mat.albedo_color = Color(0.2, 1.0, 0.85)
	grass_mat.emission_enabled = true
	grass_mat.emission = Color(0.1, 1.0, 0.8)
	grass_mat.emission_energy_multiplier = 5.0
	grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glowing_grass.material_override = grass_mat
	
	glowing_grass_light = OmniLight3D.new()
	glowing_grass_light.light_color = Color(0.1, 1.0, 0.85)
	glowing_grass_light.light_energy = 3.0
	glowing_grass_light.omni_range = 2.5
	glowing_grass_light.position = Vector3(0, 0.15, 0)
	glowing_grass.add_child(glowing_grass_light)
	
	var lbl = Label3D.new()
	lbl.text = "✦ TARGET GRASS BLADE"
	lbl.font_size = 18
	lbl.outline_size = 4
	lbl.modulate = Color(0.2, 1.0, 0.85)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 0.45, 0)
	glowing_grass.add_child(lbl)
	
	get_parent().call_deferred("add_child", glowing_grass)

func _setup_glowing_tree() -> void:
	glowing_tree = MeshInstance3D.new()
	glowing_tree.name = "GlowingIndividualTree"
	glowing_tree.visible = false
	
	glowing_tree_light = OmniLight3D.new()
	glowing_tree_light.light_color = Color(0.3, 1.0, 0.5)
	glowing_tree_light.light_energy = 4.0
	glowing_tree_light.omni_range = 14.0
	glowing_tree_light.position = Vector3(0, 2.2, 0)
	glowing_tree.add_child(glowing_tree_light)
	
	var lbl = Label3D.new()
	lbl.text = "✦ TARGET PROCEDURAL TREE"
	lbl.font_size = 20
	lbl.outline_size = 5
	lbl.modulate = Color(0.3, 1.0, 0.6)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 3.8, 0)
	glowing_tree.add_child(lbl)
	
	get_parent().call_deferred("add_child", glowing_tree)

func _ensure_grass_mesh() -> void:
	if not glowing_grass: return
	if glowing_grass.mesh: return
	
	var chunk_mgr = get_tree().root.find_child("ChunkManager", true, false)
	if chunk_mgr and "active_chunks" in chunk_mgr:
		for chunk in chunk_mgr.active_chunks.values():
			if is_instance_valid(chunk) and chunk.has_method("get_grass_mesh"):
				var m = chunk.get_grass_mesh()
				if m:
					glowing_grass.mesh = m
					return
					
	# Fallback single blade procedural mesh
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height = 0.2; var base_width = 0.02; var tip_width = 0.002
	var v0 = Vector3(-base_width, 0, 0); var v1 = Vector3(base_width, 0, 0)
	var v2 = Vector3(tip_width, 0, height); var v3 = Vector3(-tip_width, 0, height)
	st.set_uv(Vector2(0, 1)); st.add_vertex(v0); st.set_uv(Vector2(1, 1)); st.add_vertex(v1)
	st.set_uv(Vector2(1, 0)); st.add_vertex(v2); st.set_uv(Vector2(0, 0)); st.add_vertex(v3)
	st.add_index(0); st.add_index(1); st.add_index(3); st.add_index(1); st.add_index(2); st.add_index(3)
	st.generate_normals()
	glowing_grass.mesh = st.commit()

func _ensure_tree_mesh() -> void:
	if not glowing_tree: return
	if glowing_tree.mesh: return
	
	var chunk_mgr = get_tree().root.find_child("ChunkManager", true, false)
	if chunk_mgr and "active_chunks" in chunk_mgr:
		for chunk in chunk_mgr.active_chunks.values():
			if is_instance_valid(chunk) and chunk.has_method("get_tree_mesh"):
				var m = chunk.get_tree_mesh()
				if m:
					glowing_tree.mesh = m
					break
					
	if not glowing_tree.mesh:
		var c = load("res://Chunk.tscn").instantiate()
		glowing_tree.mesh = c._create_tree_mesh()
		c.queue_free()
		
	# Surface 0 = Trunk (Golden/Amber glow)
	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(1.0, 0.7, 0.2)
	trunk_mat.emission_enabled = true
	trunk_mat.emission = Color(1.0, 0.7, 0.2)
	trunk_mat.emission_energy_multiplier = 5.0
	glowing_tree.set_surface_override_material(0, trunk_mat)
	
	# Surface 1 = Foliage (Vibrant Emerald glow)
	var foliage_mat = StandardMaterial3D.new()
	foliage_mat.albedo_color = Color(0.2, 1.0, 0.45)
	foliage_mat.emission_enabled = true
	foliage_mat.emission = Color(0.2, 1.0, 0.45)
	foliage_mat.emission_energy_multiplier = 6.0
	glowing_tree.set_surface_override_material(1, foliage_mat)

func _activate_glowing_grass() -> void:
	_ensure_grass_mesh()
	if not glowing_grass: return
	
	var player_pos = player.global_position if player else initial_player_spawn
	var chosen_xform = Transform3D()
	var found = false
	
	var chunk_mgr = get_tree().root.find_child("ChunkManager", true, false)
	if chunk_mgr and "active_chunks" in chunk_mgr:
		for chunk in chunk_mgr.active_chunks.values():
			if not is_instance_valid(chunk): continue
			var grass_list = chunk.get_grass_transforms() if chunk.has_method("get_grass_transforms") else []
			for t in grass_list:
				var world_t = chunk.global_transform * t
				var dist = player_pos.distance_to(world_t.origin)
				if dist >= 3.0 and dist <= 6.5:
					chosen_xform = world_t
					found = true
					break
			if found: break
			
	if not found:
		var forward = -player.global_transform.basis.z.normalized() if player else Vector3.FORWARD
		var target_pt = player_pos + forward * 3.8
		chosen_xform = Transform3D(Basis.IDENTITY, target_pt)
		
	glowing_grass.global_transform = chosen_xform
	var base_sc = chosen_xform.basis.get_scale()
	if base_sc.length_squared() < 0.2:
		base_sc = Vector3.ONE * 2.0
	glowing_grass_base_scale = base_sc * 1.5
	glowing_grass.scale = glowing_grass_base_scale
	glowing_grass.visible = true
	milestones[1]["pos"] = glowing_grass.global_position
	milestones[2]["pos"] = glowing_grass.global_position

func _activate_glowing_tree() -> void:
	_ensure_tree_mesh()
	if not glowing_tree: return
	
	var player_pos = player.global_position if player else initial_player_spawn
	var chosen_xform = Transform3D()
	var found = false
	var best_dist = 9999.0
	
	var chunk_mgr = get_tree().root.find_child("ChunkManager", true, false)
	if chunk_mgr and "active_chunks" in chunk_mgr:
		for chunk in chunk_mgr.active_chunks.values():
			if not is_instance_valid(chunk): continue
			var tree_list = chunk.get_tree_transforms() if chunk.has_method("get_tree_transforms") else []
			for t in tree_list:
				var world_t = chunk.global_transform * t
				var dist = player_pos.distance_to(world_t.origin)
				if dist >= 7.0 and dist <= 38.0 and dist < best_dist:
					best_dist = dist
					chosen_xform = world_t
					found = true
					
	if not found:
		var forward = -player.global_transform.basis.z.normalized() if player else Vector3.FORWARD
		var target_pt = player_pos + forward * 14.0
		chosen_xform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 2.0), target_pt)
		
	glowing_tree.global_transform = chosen_xform
	glowing_tree_base_scale = chosen_xform.basis.get_scale()
	if glowing_tree_base_scale.length_squared() < 0.2:
		glowing_tree_base_scale = Vector3.ONE * 2.0
	glowing_tree.scale = glowing_tree_base_scale
	glowing_tree.visible = true
	milestones[3]["pos"] = glowing_tree.global_position

# =============================================================================
# --- MILESTONES DATA DEFINITIONS (UNITS I TO V) ---
# =============================================================================
func _init_milestones_data() -> void:
	milestones.clear()
	milestones.resize(20) # 1-based indexing for 19 milestones
	
	# -------------------------------------------------------------------------
	# UNIT I: INTRODUCTION TO COMPUTER GRAPHICS
	# -------------------------------------------------------------------------
	milestones[1] = {
		"unit": "UNIT I: INTRODUCTION TO COMPUTER GRAPHICS",
		"unit_tag": "UNIT I: PRIMITIVES",
		"concept_title": "TRIANGULAR MESH GENERATION",
		"title": "Milestone 1: Discover the Grass Blade",
		"pos": Vector3(3.5, 44.5, 3.5),
		"color": Color(0.0, 0.9, 1.0), # Cyan
		"target_name": "Individual Glowing Grass Blade",
		"dialogue": "Look closely at the field! Those thousands of grass blades are not imported models. Each individual blade is synthesized from vertices and triangles using SurfaceTool.",
		"action": "Walk towards the glowing cyan individual grass blade.",
		"code_file": "Chunk.gd",
		"code_func": "_create_grass_blade_mesh()",
		"impl_type": "Implemented Directly (SurfaceTool Mesh.PRIMITIVE_TRIANGLES)",
		"math_text": "[b]Grass Geometry Parameters:[/b]\nBase Width = 0.04m, Tip Width = 0.004m, Height = 0.2m\n\n[b]Indexed Triangles:[/b]\nT₁ = (V₀, V₁, V₃)\nT₂ = (V₁, V₂, V₃)",
		"diagram_text": "[code]     V3 (-0.002, 0.2) --- V2 (0.002, 0.2)\n     |   \\              / |\n     |     \\    T2    /   |\n     |  T1   \\      /     |\n     V0 (-0.02, 0) ------ V1 (0.02, 0)[/code]",
		"vars_text": "• [b]V₀, V₁[/b]: Base vertices (UV.y = 1.0, planted on ground)\n• [b]V₂, V₃[/b]: Tip vertices (UV.y = 0.0, sway endpoint)\n• [b]T₁, T₂[/b]: 2 counter-clockwise triangles forming 1 blade",
		"completion_type": "grass_blade",
		"status": "Approach the glowing grass blade"
	}
	
	milestones[2] = {
		"unit": "UNIT I: INTRODUCTION TO COMPUTER GRAPHICS",
		"unit_tag": "UNIT I: SHADERS",
		"concept_title": "VERTEX SHADER WIND DEFORMATION",
		"title": "Milestone 2: Experience Grass Animation",
		"pos": Vector3(3.5, 44.5, 3.5),
		"color": Color(0.1, 1.0, 0.6), # Mint green
		"target_name": "Animated Grass Blade",
		"dialogue": "Notice how the grass blades sway realistically in the wind! This movement is computed entirely on the GPU via a vertex shader deformer, leaving the CPU completely free.",
		"action": "Stand near the glowing grass blade and observe the GPU wind displacement for a few seconds.",
		"code_file": "grass.gdshader",
		"code_func": "void vertex()",
		"impl_type": "Implemented Directly (GLSL Spatial Vertex Shader)",
		"math_text": "[b]Wind Sway Equation:[/b]\nSwayMask = 1.0 - UV.y\nAt Root (UV.y = 1): SwayMask = 0  (Zero displacement)\nAt Tip  (UV.y = 0): SwayMask = 1  (Max displacement)\n\n[b]Vertex Offset:[/b]\nΔP = normalize(wind_dir) × noise_val × wind_strength × SwayMask",
		"diagram_text": "[code]   Tip  (UV.y=0, Mask=1) ------> [Max Displacement ΔP]\n        \\      ) sway arc\n         \\    )\n          \\  )\n   Root (UV.y=1, Mask=0) -----> [Firmly Fixed Base][/code]",
		"vars_text": "• [b]UV.y[/b]: Normalized vertical texture coordinate\n• [b]wind_dir[/b]: World direction vector (1.0, 0.7)\n• [b]noise_val[/b]: Seamless simplex noise sampled in world XZ",
		"completion_type": "observe_near",
		"status": "Observe wind sway animation"
	}
	
	milestones[3] = {
		"unit": "UNIT I: INTRODUCTION TO COMPUTER GRAPHICS",
		"unit_tag": "UNIT I: MODELLING",
		"concept_title": "PROCEDURAL CUBOID TREE MODELLING",
		"title": "Milestone 3: Discover the Tree",
		"pos": Vector3(5.0, 44.5, -6.0),
		"color": Color(0.2, 0.8, 1.0), # Cyan-blue
		"target_name": "Glowing Procedural Tree",
		"dialogue": "Look at the procedural trees dotting the landscape. Each tree is formed by combining distinct 3D cuboid primitives for trunk and foliage, submitted as separate sub-mesh surfaces.",
		"action": "Walk towards the fully glowing procedural tree.",
		"code_file": "Chunk.gd",
		"code_func": "_create_tree_mesh()",
		"impl_type": "Implemented Directly (st_trunk + st_leaves SurfaceTools)",
		"math_text": "[b]Polygonal Box Assembly:[/b]\nV = {v₁, v₂, ..., v₈} per cuboid component\n6 Quad Faces × 2 Triangles = 12 Triangles per Box\n\n[b]Dimensions:[/b]\nTrunk: 0.3m × 1.5m × 0.3m  (Surface 0 - Wood Material)\nFoliage: 1.4m × 1.2m × 1.4m (Surface 1 - Leaves Material)",
		"diagram_text": "[code]     +-------------+   <- Foliage Box (Green)\n    /             /|      SurfaceTool st_leaves\n   +-------------+ |      12 Triangles\n   |             | +\n   +-------------+\n        |   |          <- Trunk Box (Brown)\n        |   |             SurfaceTool st_trunk\n        +---+             12 Triangles[/code]",
		"vars_text": "• [b]SurfaceTool[/b]: Generates indexed vertex arrays & normals\n• [b]commit()[/b]: Appends multiple surfaces to a single ArrayMesh",
		"completion_type": "tree_approach",
		"status": "Approach the glowing tree"
	}
	
	milestones[4] = {
		"unit": "UNIT I: INTRODUCTION TO COMPUTER GRAPHICS",
		"unit_tag": "UNIT I: GPU BATCHING",
		"concept_title": "GPU HARDWARE INSTANCING (MULTIMESH)",
		"title": "Milestone 4: GPU Instancing",
		"pos": Vector3(45.0, 68.0, -42.0),
		"color": Color(1.0, 0.85, 0.2), # Gold
		"target_name": "Distant Terrain Overlook Ridge",
		"dialogue": "Rendering thousands of individual tree and grass nodes would choke the CPU with draw calls. Instead, SublimeGreens uses GPU Hardware Instancing via MultiMeshInstance3D.",
		"action": "Hike up to the distant terrain overlook ridge (approx. 65m away) to observe GPU instancing across the vast terrain.",
		"code_file": "Chunk.gd",
		"code_func": "generate_grass(), generate_trees()",
		"impl_type": "Engine GPU Hardware Batching configured via GDScript",
		"math_text": "[b]Affine Transform Matrix per Instance:[/b]\nP' = Transform3D × P\n\n[b]Buffer Layout (12 floats / instance):[/b]\nBuffer = [ Xx, Xy, Xz, Tx,  Yx, Yy, Yz, Ty,  Zx, Zy, Zz, Tz ]\n\n[b]Draw Calls:[/b] 1 single draw call draws 10,000+ blades!",
		"diagram_text": "[code]   [Base Mesh Data] ---+---> [GPU Instance Buffer: T0] -> Instance 0\n   (4 Verts, 2 Tris)   +---> [GPU Instance Buffer: T1] -> Instance 1\n                       +---> [GPU Instance Buffer: T2] -> Instance 2\n                       +---> [GPU Instance Buffer: Tn] -> Instance n[/code]",
		"vars_text": "• [b]MultiMesh[/b]: Modern engine replacement for display lists\n• [b]PackedFloat32Array[/b]: Direct contiguous memory buffer to VRAM",
		"completion_type": "proximity",
		"status": "Hike to the distant overlook"
	}
	
	# -------------------------------------------------------------------------
	# UNIT II: INPUT AND OUTPUT DEVICES
	# -------------------------------------------------------------------------
	milestones[5] = {
		"unit": "UNIT II: INPUT AND OUTPUT DEVICES",
		"unit_tag": "UNIT II: KEYBOARD",
		"concept_title": "DISCRETE SCANCODE INPUT & INTEGRATION",
		"title": "Milestone 5: Keyboard Navigation Challenge",
		"pos": Vector3(-7.0, 44.5, 2.0),
		"color": Color(0.3, 0.9, 1.0),
		"target_name": "Keyboard Navigation Waypoint",
		"dialogue": "Physical keyboard input devices generate discrete scancode events. The game engine samples input states each physics frame to calculate numerical velocity and displacement.",
		"action": "Use the [W, A, S, D] keys to navigate to the marked waypoint.",
		"code_file": "Player.gd",
		"code_func": "_physics_process(delta)",
		"impl_type": "Implemented Directly (Input.is_key_pressed)",
		"math_text": "[b]Numerical Position Integration:[/b]\nP(t + Δt) = P(t) + v(t) × Δt\n\n[b]Input Vector Composition:[/b]\ndir = (-basis.z × W) + (basis.z × S) + (-basis.x × A) + (basis.x × D)\nv.xz = normalize(dir).xz × SPEED",
		"diagram_text": "[code]          [W] (-basis.z)\n     [A]        [D]  ==> Normalized Vector -> Velocity -> move_and_slide()\n          [S] (+basis.z)[/code]",
		"vars_text": "• [b]W, A, S, D[/b]: Scancode state booleans (True/False)\n• [b]delta (Δt)[/b]: Fixed physics timestep (~0.0166s at 60Hz)\n• [b]SPEED[/b]: Scalar movement constant (10.0 m/s)",
		"completion_type": "proximity",
		"status": "Navigate using WASD"
	}
	
	milestones[6] = {
		"unit": "UNIT II: INPUT AND OUTPUT DEVICES",
		"unit_tag": "UNIT II: MOUSE & CAMERA",
		"concept_title": "RELATIVE POINTING DEVICES & ROTATION",
		"title": "Milestone 6: Mouse and Camera Interaction",
		"pos": Vector3(0, 44.5, 0),
		"color": Color(1.0, 0.7, 0.2),
		"target_name": "Camera Orientation",
		"dialogue": "The mouse operates as a relative 2D pointing device. When captured, continuous displacement deltas (relative.x, relative.y) are mapped to 3D spherical viewing angles.",
		"action": "Move your mouse horizontally and vertically to rotate the camera around your surroundings.",
		"code_file": "Player.gd",
		"code_func": "_input(event: InputEventMouseMotion)",
		"impl_type": "Implemented Directly (InputEventMouseMotion)",
		"math_text": "[b]Angular Displacement Formula:[/b]\nΔYaw   = -event.relative.x × sensitivity  (Player rotate_y)\nΔPitch = -event.relative.y × sensitivity  (Pivot rotate_x)\n\n[b]Pitch Clamping:[/b]\nPitch = clamp(Pitch, deg_to_rad(-90°), deg_to_rad(45°))",
		"diagram_text": "[code]   Mouse ΔX ----> rotate_y(ΔYaw)   ----> Player Body Yaw (360°)\n   Mouse ΔY ----> rotate_x(ΔPitch) ----> Camera Pivot Pitch (-90°..+45°)[/code]",
		"vars_text": "• [b]event.relative[/b]: Relative pixel motion since last frame\n• [b]sensitivity[/b]: Scaling coefficient (0.25 deg/pixel)",
		"completion_type": "mouse_look",
		"status": "Look around with mouse"
	}
	
	milestones[7] = {
		"unit": "UNIT II: INPUT AND OUTPUT DEVICES",
		"unit_tag": "UNIT II: EVENT UI",
		"concept_title": "LOGICAL INPUT, MODAL UI & TRIGGER BEACONS",
		"title": "Milestone 7: Interactive Quiz and Menu",
		"pos": Vector3(5.0, 44.5, -6.0),
		"color": Color(0.2, 0.9, 1.0),
		"target_name": "Milestone Quiz Beacon",
		"dialogue": "Virtual reality interfaces bridge user intent to visual scene state through collision triggers and modal CanvasLayer menus with focus management.",
		"action": "Approach the glowing milestone beacon and press [E] to open the CGVR Quiz UI.",
		"code_file": "QuizUI.gd, MilestoneMarker.gd",
		"code_func": "open_quiz(marker), notify_marker_entered()",
		"impl_type": "Implemented Directly (Area3D body_entered + CanvasLayer)",
		"math_text": "[b]Event-Driven Trigger Architecture:[/b]\nPlayer Enters Area3D -> notify_marker_entered()\nKeyPress(E) -> open_quiz() -> Mouse Mode = VISIBLE\nOption Pressed -> evaluate_answer() -> Provide Immediate Feedback",
		"diagram_text": "[code]   [3D Area3D Sensor] === body_entered ===> [MilestoneMarker]\n                                                    |\n   [User KeyPress: E] === InputEvent =====> [QuizUI CanvasLayer Modal][/code]",
		"vars_text": "• [b]Area3D[/b]: Spatial trigger volume querying physics space\n• [b]MOUSE_MODE_VISIBLE[/b]: Unlocks cursor for 2D UI interaction",
		"completion_type": "quiz_open",
		"status": "Press [E] at the Beacon"
	}
	
	milestones[8] = {
		"unit": "UNIT II: INPUT AND OUTPUT DEVICES",
		"unit_tag": "UNIT II: 3D AUDIO",
		"concept_title": "SPATIAL AUDIO ATTENUATION & MODULATION",
		"title": "Milestone 8: Spatial Audio",
		"pos": Vector3(0, 44.5, 0),
		"color": Color(0.6, 0.4, 1.0),
		"target_name": "Footstep Audio System",
		"dialogue": "Audio in VR uses 3D spatial attenuation and kinematics-based pitch modulation. Sprinting increases footstep playback speed and pitch!",
		"action": "Walk and hold [Shift] to sprint, observing the 3D footstep pitch increase from 1.0x to 1.35x.",
		"code_file": "Player.gd",
		"code_func": "_handle_movement_audio()",
		"impl_type": "Implemented Directly (AudioStreamPlayer3D)",
		"math_text": "[b]Kinematic Audio Modulation:[/b]\nNormal Walk:  pitch_scale = 1.00  (Standard tempo)\nShift Sprint: pitch_scale = 1.35  (35% faster tempo & higher pitch)\n\n[b]Distance Attenuation:[/b]\nAmplitude(d) = BaseVolume / (1.0 + attenuation_coeff × d²)",
		"diagram_text": "[code]   Movement State ===> is_sprinting? ---> YES: pitch = 1.35x\n                                     ---> NO:  pitch = 1.00x\n   AudioStreamPlayer3D positioned at Player origin in 3D world[/code]",
		"vars_text": "• [b]AudioStreamPlayer3D[/b]: Positionally spatialized audio emitter\n• [b]pitch_scale[/b]: Frequency multiplier for footstep speed",
		"completion_type": "sprint_listen",
		"status": "Walk & hold Shift to Sprint"
	}
	
	# -------------------------------------------------------------------------
	# UNIT III: GEOMETRIC TRANSFORMATIONS
	# -------------------------------------------------------------------------
	milestones[9] = {
		"unit": "UNIT III: GEOMETRIC TRANSFORMATIONS",
		"unit_tag": "UNIT III: TRANSLATION",
		"concept_title": "3D TRANSLATION TRANSFORMATION",
		"title": "Milestone 9: Translation",
		"pos": Vector3(8.0, 44.5, -2.0),
		"color": Color(0.85, 0.25, 1.0), # Purple
		"target_name": "Transformation Demo Gizmo",
		"dialogue": "Translation adds a displacement vector T to every vertex position, moving the geometry in 3D Euclidean space without altering its orientation or shape.",
		"action": "Approach the Transformation Gizmo and press [E] to activate 3D Translation.",
		"code_file": "TransformDemoObject.gd, Player.gd",
		"code_func": "demonstrate_translation(offset)",
		"impl_type": "Implemented Directly (Tween / Vector addition)",
		"math_text": "[b]Affine Translation Matrix:[/b]\n[ x' ]   [ 1  0  0  tx ]   [ x ]     [ x + tx ]\n[ y' ] = [ 0  1  0  ty ] × [ y ]  =  [ y + ty ]\n[ z' ]   [ 0  0  1  tz ]   [ z ]     [ z + tz ]\n[ 1  ]   [ 0  0  0  1  ]   [ 1 ]     [   1    ]\n\nVector Form: P' = P + T, where T = (2.5, 1.2, 0.0)",
		"diagram_text": "[code]   Initial Pos P (0, 1.8, 0) --- Vector T=(2.5, 1.2, 0) ---> Target Pos P'\n          [Cube P]                                              [Cube P'][/code]",
		"vars_text": "• [b]P[/b]: Initial vertex vector [x, y, z, 1]ᵀ in homogeneous coordinates\n• [b]T[/b]: Translation offset vector [tx, ty, tz]ᵀ\n• [b]P'[/b]: Transformed destination vertex coordinates",
		"completion_type": "gizmo_interact",
		"gizmo_mode": "translation",
		"status": "Press [E] to Run Translation"
	}
	
	milestones[10] = {
		"unit": "UNIT III: GEOMETRIC TRANSFORMATIONS",
		"unit_tag": "UNIT III: ROTATION",
		"concept_title": "3D ROTATION TRANSFORMATION ABOUT AXIS",
		"title": "Milestone 10: Rotation",
		"pos": Vector3(8.0, 44.5, -2.0),
		"color": Color(0.85, 0.25, 1.0),
		"target_name": "Transformation Demo Gizmo",
		"dialogue": "3D Rotation alters an object's angular orientation around a chosen axis. Rotating by angle θ around the Y-axis uses trigonometric orthonormal basis vectors.",
		"action": "Press [E] at the Gizmo to trigger a 90° Rotation demonstration around the Y-axis.",
		"code_file": "TransformDemoObject.gd, Player.gd",
		"code_func": "demonstrate_rotation(axis, angle), rotate_y()",
		"impl_type": "Implemented Directly (Basis orthonormal rotation)",
		"math_text": "[b]Rotation Matrix About Y-Axis (Ry(θ)):[/b]\n[ x' ]   [  cosθ  0  sinθ  0 ]   [ x ]\n[ y' ] = [   0    1   0    0 ] × [ y ]\n[ z' ]   [ -sinθ  0  cosθ  0 ]   [ z ]\n[ 1  ]   [   0    0   0    1 ]   [ 1 ]\n\nFor θ = 90°: cos(90°) = 0, sin(90°) = 1",
		"diagram_text": "[code]            +Y (Green Axis of Rotation)\n             |\n             |  θ = +90°\n   +X (Red) -+------> +Z (Blue)\n            [Cube rotates around central Y axis][/code]",
		"vars_text": "• [b]θ (theta)[/b]: Angular rotation in radians (90° = π/2 ≈ 1.5708 rad)\n• [b]Orthonormality[/b]: Length of basis vectors and 90° angles preserved",
		"completion_type": "gizmo_interact",
		"gizmo_mode": "rotation",
		"status": "Press [E] to Run Rotation"
	}
	
	milestones[11] = {
		"unit": "UNIT III: GEOMETRIC TRANSFORMATIONS",
		"unit_tag": "UNIT III: SCALING",
		"concept_title": "3D SCALING TRANSFORMATION",
		"title": "Milestone 11: Scaling",
		"pos": Vector3(8.0, 44.5, -2.0),
		"color": Color(0.85, 0.25, 1.0),
		"target_name": "Transformation Demo Gizmo",
		"dialogue": "Scaling multiplies an object's dimensions along coordinate axes. Uniform scaling preserves aspect ratio; non-uniform scaling stretches geometry along chosen dimensions.",
		"action": "Press [E] at the Gizmo to trigger the 3D Scaling demonstration.",
		"code_file": "TransformDemoObject.gd, Chunk.gd",
		"code_func": "demonstrate_scaling(), basis.scaled()",
		"impl_type": "Implemented Directly (Basis diagonal scaling)",
		"math_text": "[b]Scaling Matrix (S):[/b]\n[ x' ]   [ Sx  0   0   0 ]   [ x ]     [ Sx × x ]\n[ y' ] = [ 0   Sy  0   0 ] × [ y ]  =  [ Sy × y ]\n[ z' ]   [ 0   0   Sz  0 ]   [ z ]     [ Sz × z ]\n[ 1  ]   [ 0   0   0   1 ]   [ 1 ]     [   1    ]\n\nUniform: Sx = Sy = Sz = 1.8  (Expands 180% then contracts)",
		"diagram_text": "[code]    +-------+        +-------------+\n   /       /|       /             /|   <- Scaled up by Sx, Sy, Sz\n  +-------+ |  ==> +-------------+ |\n  |  1.0  | +      |     1.8     | +\n  +-------+        +-------------+[/code]",
		"vars_text": "• [b]Sx, Sy, Sz[/b]: Independent scale factors along X, Y, and Z axes\n• [b]Chunk.gd[/b]: Uses randf_range(0.8, 1.4) for procedural tree diversity",
		"completion_type": "gizmo_interact",
		"gizmo_mode": "scaling",
		"status": "Press [E] to Run Scaling"
	}
	
	milestones[12] = {
		"unit": "UNIT III: GEOMETRIC TRANSFORMATIONS",
		"unit_tag": "UNIT III: COMPOSITE",
		"concept_title": "COMPOSITE AFFINE TRANSFORMATIONS (TRS)",
		"title": "Milestone 12: Composite Transformations",
		"pos": Vector3(8.0, 44.5, -2.0),
		"color": Color(0.85, 0.25, 1.0),
		"target_name": "Transformation Demo Gizmo",
		"dialogue": "In 3D graphics, transformations are sequenced through matrix concatenation. Matrix multiplication is non-commutative: the canonical graphics order is TRS (Scale first, then Rotate, then Translate).",
		"action": "Press [E] at the Gizmo to observe the sequential composite pipeline.",
		"code_file": "TransformDemoObject.gd, Chunk.gd",
		"code_func": "demonstrate_composite(), Transform3D(basis, origin)",
		"impl_type": "Implemented Directly (Transform3D Basis & Origin composition)",
		"math_text": "[b]Composite Transformation Equation:[/b]\nP' = ( T × R × S ) × P\n\n[b]Godot Transform3D Architecture:[/b]\nTransform3D = Basis(R × S) + Origin(T)\nMatrix order is strictly non-commutative: T × R ≠ R × T!",
		"diagram_text": "[code]   P (Model Space)\n         │\n         ▼  1. Scale Matrix (S)\n       P_scaled\n         │\n         ▼  2. Rotation Matrix (R)\n       P_rotated\n         │\n         ▼  3. Translation Matrix (T)\n       P' (World Space Position)[/code]",
		"vars_text": "• [b]Non-commutative[/b]: Order of operations fundamentally changes outcome\n• [b]Transform3D[/b]: 3x4 affine matrix representation standard in Godot",
		"completion_type": "gizmo_interact",
		"gizmo_mode": "composite",
		"status": "Press [E] to Run Composite Demo"
	}
	
	# -------------------------------------------------------------------------
	# UNIT IV: 3D VIEWING AND VISIBLE SURFACE DETECTION
	# -------------------------------------------------------------------------
	milestones[13] = {
		"unit": "UNIT IV: 3D VIEWING AND VISIBLE SURFACE DETECTION",
		"unit_tag": "UNIT IV: VIEW PIPELINE",
		"concept_title": "CAMERA VIEWING PIPELINE & SCENE HIERARCHY",
		"title": "Milestone 13: Camera Viewing Pipeline",
		"pos": Vector3(0, 44.5, 0),
		"color": Color(0.2, 0.8, 1.0),
		"target_name": "Player & Camera Rig",
		"dialogue": "The 3D viewing pipeline maps world-space objects into camera viewing coordinates. SublimeGreens implements a third-person spring-arm hierarchy that decouples yaw, pitch, and zoom.",
		"action": "Orbit your camera around the player by moving the mouse horizontally.",
		"code_file": "Player.tscn",
		"code_func": "Scene Tree Hierarchy",
		"impl_type": "Engine Component Hierarchy Configured in Player.tscn",
		"math_text": "[b]View Matrix Transformation:[/b]\nP_view = M_view × P_world, where M_view = (M_camera)⁻¹\n\n[b]Scene Graph Transform Inheritance:[/b]\nM_cam_world = M_player × M_pivot × M_springarm × M_cam_local",
		"diagram_text": "[code]   Player (CharacterBody3D) [Yaw Axis - rotate_y]\n     └── Node3D (Pivot) [Pitch Axis - rotate_x]\n           └── SpringArm3D (Length = 5.0m, collision raycast)\n                 └── Camera3D (Perspective Projection FOV=75°)[/code]",
		"vars_text": "• [b]SpringArm3D[/b]: Performs raycasts to prevent camera passing through terrain\n• [b]M_view[/b]: Inverts camera transform to bring world into eye space",
		"completion_type": "orbit_camera",
		"status": "Orbit camera around player"
	}
	
	milestones[14] = {
		"unit": "UNIT IV: 3D VIEWING AND VISIBLE SURFACE DETECTION",
		"unit_tag": "UNIT IV: CLAMPING",
		"concept_title": "VIEWING ANGLE & GIMBAL-LOCK CLAMPING",
		"title": "Milestone 14: Viewing Angle and Clamping",
		"pos": Vector3(0, 44.5, 0),
		"color": Color(1.0, 0.75, 0.2),
		"target_name": "Camera Pitch Limiter",
		"dialogue": "To prevent gimbal lock and awkward view inversion, vertical camera rotation is strictly clamped between -90° (looking straight down) and +45° (looking up into the sky).",
		"action": "Move your mouse vertically to hit the camera's upper (+45°) and lower (-90°) limits.",
		"code_file": "Player.gd",
		"code_func": "pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-90), deg_to_rad(45))",
		"impl_type": "Implemented Directly (Math clamp function)",
		"math_text": "[b]Angular Clamp Equation:[/b]\nθ_clamped = clamp( θ_raw, θ_min, θ_max )\nθ_min = deg_to_rad(-90°) ≈ -1.5708 rad  (Top-down view)\nθ_max = deg_to_rad(+45°) ≈ +0.7854 rad  (Skyward view)",
		"diagram_text": "[code]             ▲ +45° Max Sky Limit (θ_max = 0.785 rad)\n             │   / (Sun visible in upper FOV)\n    Horizon ─┼──O─── (θ = 0°)\n             │   \\\n             ▼ -90° Min Ground Limit (θ_min = -1.571 rad, looking down)[/code]",
		"vars_text": "• [b]Gimbal Lock[/b]: Occurs when Euler pitch reaches ±90°, losing 1 DOF\n• [b]clamp()[/b]: Bound function returning min if val < min, max if val > max",
		"completion_type": "clamp_pitch",
		"status": "Tilt mouse to upper/lower limits"
	}
	
	milestones[15] = {
		"unit": "UNIT IV: 3D VIEWING AND VISIBLE SURFACE DETECTION",
		"unit_tag": "UNIT IV: CULLING",
		"concept_title": "BACK-FACE CULLING & TWO-SIDED SURFACES",
		"title": "Milestone 15: Back-Face Culling",
		"pos": Vector3(3.0, 44.5, 3.0),
		"color": Color(0.2, 0.9, 0.6),
		"target_name": "Grass & Terrain Culling",
		"dialogue": "Back-face culling discards polygons whose normals point away from the camera. Terrain enables `cull_back` to save 50% rasterization, while grass disables culling (`cull_disabled`) so both sides stay visible!",
		"action": "Walk to the grass patch and orbit your camera to observe two-sided grass rendering.",
		"code_file": "Chunk.gdshader, grass.gdshader",
		"code_func": "render_mode cull_back vs cull_disabled",
		"impl_type": "Shader Configuration",
		"math_text": "[b]Back-Face Culling Test:[/b]\nDot Product = N_face · V_cam\nIf Dot Product < 0: Face points away -> DISCARD in GPU rasterizer\nIf Dot Product ≥ 0: Face points to camera -> RENDER\n\n[b]SublimeGreens Configuration:[/b]\nChunk Terrain:  cull_back     (Solid ground, interior hidden)\nGrass Blade:    cull_disabled (Thin geometry, visible from all angles)",
		"diagram_text": "[code]          Camera View Vector V_cam\n                   │\n     Front Face:   ▼    Back Face:\n     Normal N ↑         Normal N ↓\n     N · V > 0 -> RENDER   N · V < 0 -> CULL (DISCARD)[/code]",
		"vars_text": "• [b]N_face[/b]: Surface normal unit vector perpendicular to triangle plane\n• [b]V_cam[/b]: Viewing ray vector from camera towards the polygon",
		"completion_type": "proximity",
		"status": "Inspect two-sided grass blades"
	}
	
	milestones[16] = {
		"unit": "UNIT IV: 3D VIEWING AND VISIBLE SURFACE DETECTION",
		"unit_tag": "UNIT IV: LEVEL OF DETAIL",
		"concept_title": "DISTANCE-BASED AABB LEVEL OF DETAIL (LOD)",
		"title": "Milestone 16: Distance-Based LOD",
		"pos": Vector3(0.0, 44.5, 0.0),
		"color": Color(0.4, 0.85, 1.0),
		"target_name": "LOD Distance Boundary",
		"dialogue": "To sustain high frame rates across large procedural worlds, SublimeGreens updates vegetation density dynamically based on player distance to each chunk's Axis-Aligned Bounding Box (AABB).",
		"action": "Move away from the center (>18m) and return to observe the grass density scaling.",
		"code_file": "Chunk.gd",
		"code_func": "update_grass_lod(player_pos)",
		"impl_type": "Implemented Directly (AABB distance clamp & MultiMesh count)",
		"math_text": "[b]AABB Surface Distance Calculation:[/b]\nClosestPoint = clamp( player_pos, AABB_min, AABB_max )\nDistance = distance( player_pos, ClosestPoint )\n\n[b]LOD Thresholds:[/b]\nd < 25m: 100% density (All grass blades rendered)\nd < 50m: 60% density\nd ≥ 50m: 20% density (Outer blades culled first)",
		"diagram_text": "[code]   Player ─── Distance d ───> [Chunk AABB Boundary]\n   If Inside AABB: Distance = 0m (Max 100% LOD)\n   MultiMesh.visible_instance_count = TotalInstances × DensityMultiplier[/code]",
		"vars_text": "• [b]AABB[/b]: Axis-Aligned Bounding Box (position, size)\n• [b]visible_instance_count[/b]: Instant zero-allocation GPU instance culling",
		"completion_type": "lod_walk",
		"status": "Walk away (>18m) and return"
	}
	
	# -------------------------------------------------------------------------
	# UNIT V: MODELLING IN VIRTUAL REALITY
	# -------------------------------------------------------------------------
	milestones[17] = {
		"unit": "UNIT V: MODELLING IN VIRTUAL REALITY",
		"unit_tag": "UNIT V: PROCEDURAL VR",
		"concept_title": "PROCEDURAL TERRAIN & WATER MODELLING",
		"title": "Milestone 17: Procedural Environment Modelling",
		"pos": Vector3(-8.0, 44.5, -4.0),
		"color": Color(0.2, 0.9, 0.8),
		"target_name": "Terrain Milestone Beacon",
		"dialogue": "Virtual reality environments rely on procedural geometric modelling. SublimeGreens synthesizes endless mountains, valleys, and rivers by layering coherent simplex noise octaves.",
		"action": "Visit the Terrain milestone beacon to inspect procedural mesh elevation.",
		"code_file": "Chunk.gd",
		"code_func": "generate_terrain(), setup_water_plane()",
		"impl_type": "Implemented Directly (FastNoiseLite + SurfaceTool elevation)",
		"math_text": "[b]Composite Height Function:[/b]\nHeight(x, z) = ContinentSlope(x,z) + Mountain(x,z)·Mask + Valley(x,z) + Erosion(x,z)\n\n[b]Vertex Mesh Generation:[/b]\nVertex = Vector3( x × step_x, Height(x,z), z × step_z )\nWater Plane = PlaneMesh at visual_water_level",
		"diagram_text": "[code]   Base Continent Noise ──┐\n   Mountain Noise       ──┼──> Sum Height(x,z) ──> SurfaceTool Vertex\n   Valley & Erosion     ──┘\n   Water Plane intersects at Y = visual_water_level[/code]",
		"vars_text": "• [b]FastNoiseLite[/b]: Procedural coherent 2D gradient noise\n• [b]Normal Generation[/b]: st.generate_normals() computes surface normals",
		"completion_type": "proximity",
		"status": "Visit the Terrain Beacon"
	}
	
	milestones[18] = {
		"unit": "UNIT V: MODELLING IN VIRTUAL REALITY",
		"unit_tag": "UNIT V: COLLISION",
		"concept_title": "COLLISION DETECTION & SURFACE RESOLUTION",
		"title": "Milestone 18: Collision Detection",
		"pos": Vector3(0, 44.5, 0),
		"color": Color(1.0, 0.3, 0.3), # Red
		"target_name": "Terrain Collision Mesh",
		"dialogue": "Physical presence in VR demands accurate collision detection. The procedural terrain automatically constructs a ConcavePolygonShape3D from its mesh faces to stop the player from falling through the world.",
		"action": "Press [Space] to jump into the air and land on the collision-enabled terrain surface.",
		"code_file": "Chunk.gd, Player.tscn",
		"code_func": "coll_shape.set_faces(mesh.get_faces()), move_and_slide()",
		"impl_type": "Engine Collision Pipeline configured via GDScript",
		"math_text": "[b]Collision Pair:[/b]\nPlayer:  CapsuleShape3D (radius = 0.5m, height = 2.0m)\nTerrain: ConcavePolygonShape3D (Triangular polygon boundary)\n\n[b]Penetration Resolution:[/b]\nUpon Contact: Normal Velocity vn = 0, is_on_floor() = true",
		"diagram_text": "[code]          [Player CapsuleShape3D]\n                    │ (falling with gravity)\n                    ▼\n   ═════════════════════════════════  <- ConcavePolygonShape3D Surface\n          Contact Normal N (Floor)[/code]",
		"vars_text": "• [b]ConcavePolygonShape3D[/b]: Static triangle-accurate terrain collision\n• [b]is_on_floor()[/b]: Physics query returning true when floor normal detected",
		"completion_type": "jump_land",
		"status": "Press Space to Jump & Land"
	}
	
	milestones[19] = {
		"unit": "UNIT V: MODELLING IN VIRTUAL REALITY",
		"unit_tag": "UNIT V: KINEMATICS",
		"concept_title": "PHYSICS KINEMATICS & BEHAVIOUR MODELLING",
		"title": "Milestone 19: Kinematics and Behaviour Modelling",
		"pos": Vector3(0, 44.5, 0),
		"color": Color(0.3, 1.0, 0.4), # Green
		"target_name": "Kinematics Verification",
		"dialogue": "Virtual reality behaviour modelling integrates Newton's kinematic laws with player steering. Gravity continuously accelerates the player downward until ground contact halts velocity.",
		"action": "Complete the final kinematics sequence: Walk 2 seconds, Sprint 2 seconds, and Jump!",
		"code_file": "Player.gd",
		"code_func": "_physics_process(), velocity.y -= 9.8 * delta * 2",
		"impl_type": "Implemented Directly (Kinematic equations + move_and_slide())",
		"math_text": "[b]Kinematic Motion Equations:[/b]\nv(t + Δt) = v(t) + a × Δt\ns(t + Δt) = s(t) + v(t)Δt + ½ a (Δt)²\n\n[b]Implementation Forces:[/b]\nGravity: a_y = -9.8 × 2 = -19.6 m/s²\nJump Impulse: v_y = +5.0 m/s\nSprint Multiplier: v_xz × 2.0",
		"diagram_text": "[code]   Horizontal Velocity: v_xz = InputDir × Speed (× 2 if Sprint)\n   Vertical Velocity:   v_y(t+Δt) = v_y(t) - 19.6 × Δt\n   Solver:              move_and_slide() integrates displacement[/code]",
		"vars_text": "• [b]v[/b]: Velocity vector in m/s (x, y, z)\n• [b]a[/b]: Acceleration vector (gravity downwards)\n• [b]move_and_slide()[/b]: Built-in physics solver handling collisions & sliding",
		"completion_type": "full_kinematics",
		"status": "Walk, Sprint, and Jump!"
	}

# =============================================================================
# --- PROGRESSION AND STATE MANAGEMENT ---
# =============================================================================
func set_milestone(idx: int) -> void:
	if idx < 1: idx = 1
	if idx > 19:
		_finish_all_milestones()
		return
		
	current_milestone_idx = idx
	_save_progress(idx)
	emit_signal("milestone_changed", idx)
	
	# Reset milestone tracking variables
	milestone_timer = 0.0
	walk_time_tracker = 0.0
	sprint_time_tracker = 0.0
	jump_performed = false
	lod_moved_away = false
	
	if camera:
		initial_camera_yaw = camera.global_rotation.y
		last_cam_forward = -camera.global_transform.basis.z.normalized()
		camera_pitch_max = camera.global_rotation.x
		camera_pitch_min = camera.global_rotation.x
	yaw_accumulated = 0.0
	
	_resolve_ui_nodes()
	var data = milestones[idx]
	
	# 1. Update Left Dialogue Panel
	if unit_badge: unit_badge.text = data["unit_tag"]
	if milestone_label: milestone_label.text = "Step %d of 19" % idx
	if concept_title: concept_title.text = data["concept_title"]
	if action_box_label: action_box_label.text = "ACTION REQUIRED:\n" + data["action"]
	if code_tag_label: code_tag_label.text = "📁 " + data["code_file"] + " → " + data["code_func"]
	_display_dialogue(data["dialogue"])
	
	# Update unit selector dropdown without triggering event loop
	if unit_selector:
		var unit_map = {1: 0, 5: 1, 9: 2, 13: 3, 17: 4}
		for key in unit_map.keys():
			if idx >= key:
				unit_selector.selected = unit_map[key]
				
	# 2. Update Right Formula Panel
	if formula_panel:
		formula_panel.display_formula(data)
		formula_panel.set_status(data["status"], data["color"])
		
	# 3. Update Objective HUD
	if hud_unit_label:
		hud_unit_label.text = "<%s>" % data["unit_tag"]
	if hud_objective_label:
		hud_objective_label.text = data["title"]
		
	# 4. Target Configuration: Glowing Individual Targets vs Generic Waypoint Marker
	if idx in [1, 2]:
		_activate_glowing_grass()
		if glowing_tree: glowing_tree.visible = false
		if active_highlight: active_highlight.visible = false
	elif idx == 3:
		_activate_glowing_tree()
		if glowing_grass: glowing_grass.visible = false
		if active_highlight: active_highlight.visible = false
	else:
		if glowing_grass: glowing_grass.visible = false
		if glowing_tree: glowing_tree.visible = false
		if active_highlight:
			var target_pos = data["pos"]
			active_highlight.global_position = target_pos
			active_highlight.set_highlight_color(data["color"])
			active_highlight.set_label(data["target_name"])
			active_highlight.visible = data["completion_type"] in ["proximity", "observe_near", "gizmo_interact"]
			active_highlight.snap_to_terrain()
		
	# 5. Configure Transformation Demo Gizmo if in Unit III
	if transform_gizmo:
		if "gizmo_mode" in data:
			transform_gizmo.visible = true
			transform_gizmo.set_demo_mode(data["gizmo_mode"])
		else:
			transform_gizmo.visible = (idx >= 9 and idx <= 12)

func _process(delta: float) -> void:
	_update_mouse_mode_ui()
	if not is_active or current_milestone_idx < 1 or current_milestone_idx > 19:
		return
		
	var data = milestones[current_milestone_idx]
	milestone_timer += delta
	
	# Animate individual glowing targets
	if glowing_grass and glowing_grass.visible:
		var grass_pulse = 1.0 + sin(milestone_timer * 5.0) * 0.12
		glowing_grass.scale = glowing_grass_base_scale * grass_pulse
		if glowing_grass_light:
			glowing_grass_light.light_energy = 2.5 + sin(milestone_timer * 5.0) * 1.5

	if glowing_tree and glowing_tree.visible:
		var tree_pulse = 1.0 + sin(milestone_timer * 3.5) * 0.05
		glowing_tree.scale = glowing_tree_base_scale * tree_pulse
		if glowing_tree_light:
			glowing_tree_light.light_energy = 3.5 + sin(milestone_timer * 3.5) * 1.5

	# Update distance in Objective HUD
	if hud_distance_label:
		if font_hint_timer > 0.0:
			font_hint_timer -= delta
			var sign_str = "+" if _font_size_offset > 0 else ""
			hud_distance_label.text = "[ Font: %s%d ]" % [sign_str, _font_size_offset]
		elif player:
			var target_pt: Vector3 = Vector3.ZERO
			var has_target: bool = false
			if current_milestone_idx in [1, 2] and glowing_grass and glowing_grass.visible:
				target_pt = glowing_grass.global_position
				has_target = true
			elif current_milestone_idx == 3 and glowing_tree and glowing_tree.visible:
				target_pt = glowing_tree.global_position
				has_target = true
			elif active_highlight and active_highlight.visible:
				target_pt = data["pos"]
				has_target = true
				
			if has_target:
				var dist = player.global_position.distance_to(target_pt)
				hud_distance_label.text = "[ %.1fm ]" % dist
			else:
				hud_distance_label.text = ""
			
	# Process Milestone Specific Completion Conditions
	match data["completion_type"]:
		"grass_blade":
			if player and glowing_grass and glowing_grass.visible:
				var dist = player.global_position.distance_to(glowing_grass.global_position)
				if dist < 2.5:
					_complete_current_milestone()

		"observe_near":
			var g_pos = glowing_grass.global_position if (glowing_grass and glowing_grass.visible) else data["pos"]
			if player and player.global_position.distance_to(g_pos) < 5.0:
				walk_time_tracker += delta
				if formula_panel:
					formula_panel.set_progress(walk_time_tracker / 3.5)
					formula_panel.set_status("Observing Shader Deformation... (%d%%)" % int((walk_time_tracker / 3.5) * 100), Color(0.2, 1.0, 0.5))
				if walk_time_tracker >= 3.5:
					_complete_current_milestone()

		"tree_approach":
			if player and glowing_tree and glowing_tree.visible:
				var dist = player.global_position.distance_to(glowing_tree.global_position)
				if dist < 5.0:
					_complete_current_milestone()
					
		"mouse_look":
			# Milestone 6: Look around with mouse
			if camera:
				var current_forward = -camera.global_transform.basis.z.normalized()
				var angle = current_forward.angle_to(last_cam_forward)
				yaw_accumulated += angle
				last_cam_forward = current_forward
				if formula_panel:
					formula_panel.set_progress(clamp(yaw_accumulated / 3.14, 0.0, 1.0))
				if yaw_accumulated >= 3.14: # Rotated view around at least 180 degrees
					_complete_current_milestone()
					
		"sprint_listen":
			# Milestone 8: Walk and hold shift
			if player:
				var is_moving = player.velocity.length_squared() > 1.0
				var is_sprinting = Input.is_key_pressed(KEY_SHIFT) and is_moving
				if is_sprinting:
					sprint_time_tracker += delta
					if formula_panel:
						formula_panel.set_progress(sprint_time_tracker / 2.0)
						formula_panel.set_status("Sprinting with 1.35x Pitch! (%d%%)" % int((sprint_time_tracker / 2.0) * 100), Color(0.8, 0.4, 1.0))
					if sprint_time_tracker >= 2.0:
						_complete_current_milestone()
						
		"orbit_camera":
			# Milestone 13: Orbit camera
			if camera:
				var current_forward = -camera.global_transform.basis.z.normalized()
				var angle = current_forward.angle_to(last_cam_forward)
				yaw_accumulated += angle
				last_cam_forward = current_forward
				if formula_panel:
					formula_panel.set_progress(clamp(yaw_accumulated / 2.5, 0.0, 1.0))
				if yaw_accumulated >= 2.5:
					_complete_current_milestone()
					
		"clamp_pitch":
			# Milestone 14: Pitch upper and lower limits
			if camera:
				var p = camera.global_rotation.x
				if p > camera_pitch_max: camera_pitch_max = p
				if p < camera_pitch_min: camera_pitch_min = p
				# Checked if player looked up (>30 deg = 0.5 rad) and down (<-30 deg = -0.5 rad)
				var hit_high = camera_pitch_max > 0.45
				var hit_low = camera_pitch_min < -0.45
				if hit_high and hit_low:
					_complete_current_milestone()
				elif formula_panel:
					formula_panel.set_status("Pitch Range: [%.0f°, %.0f°] (Need -30° and +30°)" % [rad_to_deg(camera_pitch_min), rad_to_deg(camera_pitch_max)])
					
		"lod_walk":
			# Milestone 16: Move away (>18m) from chunk center, then return
			if player:
				var dist = player.global_position.distance_to(initial_player_spawn)
				if dist > 18.0:
					lod_moved_away = true
					if formula_panel:
						formula_panel.set_status("Far Distance (>18m) Reached! Now return to center.", Color(1.0, 0.8, 0.2))
				if lod_moved_away and dist < 8.0:
					_complete_current_milestone()
					
		"jump_land":
			# Milestone 18: Jump and land
			if player:
				if Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
					jump_performed = true
				if jump_performed and player.is_on_floor() and milestone_timer > 0.8:
					_complete_current_milestone()
					
		"full_kinematics":
			# Milestone 19: Walk, Sprint, Jump
			if player:
				var is_moving = player.velocity.length_squared() > 1.0
				var is_sprinting = Input.is_key_pressed(KEY_SHIFT) and is_moving
				if is_moving: walk_time_tracker += delta
				if is_sprinting: sprint_time_tracker += delta
				if Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
					jump_performed = true
					
				var pct = 0
				if walk_time_tracker > 1.5: pct += 33
				if sprint_time_tracker > 1.5: pct += 33
				if jump_performed: pct += 34
				if formula_panel:
					formula_panel.set_progress(float(pct) / 100.0)
					formula_panel.set_status("Kinematics: Walk(%s) Sprint(%s) Jump(%s)" % [
						"✓" if walk_time_tracker > 1.5 else "...",
						"✓" if sprint_time_tracker > 1.5 else "...",
						"✓" if jump_performed else "..."
					])
					
				if walk_time_tracker > 1.5 and sprint_time_tracker > 1.5 and jump_performed and player.is_on_floor():
					_complete_current_milestone()

func _on_highlight_entered(_hl: TutorialHighlight) -> void:
	var data = milestones[current_milestone_idx]
	if data["completion_type"] == "proximity":
		_complete_current_milestone()

func _on_highlight_interacted(_hl: TutorialHighlight) -> void:
	var data = milestones[current_milestone_idx]
	if data["completion_type"] == "interact":
		_complete_current_milestone()

func _on_transform_demo_completed(type: String) -> void:
	var data = milestones[current_milestone_idx]
	if data.get("gizmo_mode", "") == type:
		_complete_current_milestone()

func _on_transform_demo_interacted() -> void:
	# Interaction started
	pass

func _input(event: InputEvent) -> void:
	# Ctrl + / Ctrl - to adjust font sizes across the UI
	if event is InputEventKey and event.is_pressed() and not event.echo:
		if event.ctrl_pressed:
			if event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS or event.keycode == KEY_KP_ADD:
				_adjust_font_size(1)
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
				_adjust_font_size(-1)
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_0 or event.keycode == KEY_KP_0:
				_adjust_font_size(0, true)
				get_viewport().set_input_as_handled()
				return

func _unhandled_input(event: InputEvent) -> void:
	# Milestone 7 check: opening QuizUI with E
	if current_milestone_idx == 7 and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			var quiz_ui = get_tree().root.find_child("QuizUI", true, false)
			if quiz_ui and quiz_ui.is_quiz_open:
				_complete_current_milestone()
				
	# Replay / restart toggle
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			set_milestone(1)

func _complete_current_milestone() -> void:
	if formula_panel:
		formula_panel.set_status("Objective Completed! ✅", Color(0.2, 1.0, 0.4))
		
	# Brief celebratory pause before advancing
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(func():
		set_milestone(current_milestone_idx + 1)
	)

func _on_next_button_pressed() -> void:
	if current_milestone_idx >= 19:
		_finish_all_milestones()
	else:
		set_milestone(current_milestone_idx + 1)

func _finish_all_milestones() -> void:
	is_active = false
	emit_signal("tutorial_completed")
	
	# Hide all narrative and tutorial overlay panels across the screen
	if left_panel:
		left_panel.visible = false
	if formula_panel:
		formula_panel.visible = false
	if objective_hud:
		objective_hud.visible = false
	if active_highlight:
		active_highlight.visible = false
	if transform_gizmo:
		transform_gizmo.visible = false
	if glowing_grass:
		glowing_grass.visible = false
	if glowing_tree:
		glowing_tree.visible = false

	# Mark all core unit quests complete in QuestLocationManager
	var qlm = QuestLocationManager.instance
	if not qlm:
		qlm = get_tree().root.find_child("QuestLocationManager", true, false)
	if qlm:
		for qid in ["m1_trees", "m3_terrain", "m5_multimesh", "m2_camera", "m4_aabb_lod"]:
			qlm.set_quest_status(qid, QuestMarker.QuestStatus.COMPLETED)

	# Trigger Ancient Stone Monolith magical screen and set minimap destination
	var monolith = get_tree().root.find_child("AncientStoneMonolith", true, false)
	if monolith and monolith.has_method("activate_magical_screen"):
		monolith.activate_magical_screen()

func _display_dialogue(text: String) -> void:
	if dialogue_tween and dialogue_tween.is_valid():
		dialogue_tween.kill()
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
		
	if explanation_label:
		explanation_label.text = text
		explanation_label.visible_ratio = 0.0
		
		typewriter_tween = create_tween()
		var duration = clamp(float(text.length()) * 0.015, 0.4, 1.5)
		typewriter_tween.tween_property(explanation_label, "visible_ratio", 1.0, duration)

func _save_progress(idx: int) -> void:
	var cfg = ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("tutorial", "milestone", idx)
	cfg.save(SAVE_PATH)

func _load_progress() -> int:
	var cfg = ConfigFile.new()
	var err = cfg.load(SAVE_PATH)
	if err == OK:
		return cfg.get_value("tutorial", "milestone", 1)
	return 1
