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
	_init_milestones_data()
	_resolve_nodes()
	_setup_ui_events()
	_setup_world_objects()
	
	# Load or start milestone 1
	var saved_idx = _load_progress()
	set_milestone(saved_idx)

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
		next_button.pressed.connect(func(): set_milestone(current_milestone_idx + 1))
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
		"title": "Milestone 1: Discover the Grass",
		"pos": Vector3(3.0, 44.5, 3.0),
		"color": Color(0.0, 0.9, 1.0), # Cyan
		"target_name": "Procedural Grass Blade Mesh",
		"dialogue": "Look around you! Those thousands of grass blades are not imported 3D models. Each blade is procedurally synthesized from vertices and triangles using SurfaceTool.",
		"action": "Walk towards the glowing cyan grass patch.",
		"code_file": "Chunk.gd",
		"code_func": "_create_grass_blade_mesh()",
		"impl_type": "Implemented Directly (SurfaceTool Mesh.PRIMITIVE_TRIANGLES)",
		"math_text": "[b]Grass Geometry Parameters:[/b]\nBase Width = 0.04m, Tip Width = 0.004m, Height = 0.2m\n\n[b]Indexed Triangles:[/b]\nT₁ = (V₀, V₁, V₃)\nT₂ = (V₁, V₂, V₃)",
		"diagram_text": "[code]     V3 (-0.002, 0.2) --- V2 (0.002, 0.2)\n     |   \\              / |\n     |     \\    T2    /   |\n     |  T1   \\      /     |\n     V0 (-0.02, 0) ------ V1 (0.02, 0)[/code]",
		"vars_text": "• [b]V₀, V₁[/b]: Base vertices (UV.y = 1.0, planted on ground)\n• [b]V₂, V₃[/b]: Tip vertices (UV.y = 0.0, sway endpoint)\n• [b]T₁, T₂[/b]: 2 counter-clockwise triangles forming 1 blade",
		"completion_type": "proximity",
		"status": "Approach the highlighted grass"
	}
	
	milestones[2] = {
		"unit": "UNIT I: INTRODUCTION TO COMPUTER GRAPHICS",
		"unit_tag": "UNIT I: SHADERS",
		"concept_title": "VERTEX SHADER WIND DEFORMATION",
		"title": "Milestone 2: Experience Grass Animation",
		"pos": Vector3(3.0, 44.5, 3.0),
		"color": Color(0.1, 1.0, 0.6), # Mint green
		"target_name": "Animated Grass Field",
		"dialogue": "Notice how the grass blades sway realistically in the wind! This movement is computed entirely on the GPU via a vertex shader deformer, leaving the CPU completely free.",
		"action": "Stand near the grass and observe the GPU wind displacement for a few seconds.",
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
		"target_name": "Procedural Tree & Beacon",
		"dialogue": "Look at the procedural trees dotting the landscape. Each tree is formed by combining distinct 3D cuboid primitives for trunk and foliage, submitted as separate sub-mesh surfaces.",
		"action": "Walk towards the highlighted procedural tree.",
		"code_file": "Chunk.gd",
		"code_func": "_create_tree_mesh()",
		"impl_type": "Implemented Directly (st_trunk + st_leaves SurfaceTools)",
		"math_text": "[b]Polygonal Box Assembly:[/b]\nV = {v₁, v₂, ..., v₈} per cuboid component\n6 Quad Faces × 2 Triangles = 12 Triangles per Box\n\n[b]Dimensions:[/b]\nTrunk: 0.3m × 1.5m × 0.3m  (Surface 0 - Wood Material)\nFoliage: 1.4m × 1.2m × 1.4m (Surface 1 - Leaves Material)",
		"diagram_text": "[code]     +-------------+   <- Foliage Box (Green)\n    /             /|      SurfaceTool st_leaves\n   +-------------+ |      12 Triangles\n   |             | +\n   +-------------+\n        |   |          <- Trunk Box (Brown)\n        |   |             SurfaceTool st_trunk\n        +---+             12 Triangles[/code]",
		"vars_text": "• [b]SurfaceTool[/b]: Generates indexed vertex arrays & normals\n• [b]commit()[/b]: Appends multiple surfaces to a single ArrayMesh",
		"completion_type": "proximity",
		"status": "Approach the procedural tree"
	}
	
	milestones[4] = {
		"unit": "UNIT I: INTRODUCTION TO COMPUTER GRAPHICS",
		"unit_tag": "UNIT I: GPU BATCHING",
		"concept_title": "GPU HARDWARE INSTANCING (MULTIMESH)",
		"title": "Milestone 4: GPU Instancing",
		"pos": Vector3(0.0, 45.0, -12.0),
		"color": Color(1.0, 0.85, 0.2), # Gold
		"target_name": "Terrain Overlook Point",
		"dialogue": "Rendering thousands of individual tree and grass nodes would choke the CPU with draw calls. Instead, SublimeGreens uses GPU Hardware Instancing via MultiMeshInstance3D.",
		"action": "Walk to the designated overlook point to observe GPU instancing across the plains.",
		"code_file": "Chunk.gd",
		"code_func": "generate_grass(), generate_trees()",
		"impl_type": "Engine GPU Hardware Batching configured via GDScript",
		"math_text": "[b]Affine Transform Matrix per Instance:[/b]\nP' = Transform3D × P\n\n[b]Buffer Layout (12 floats / instance):[/b]\nBuffer = [ Xx, Xy, Xz, Tx,  Yx, Yy, Yz, Ty,  Zx, Zy, Zz, Tz ]\n\n[b]Draw Calls:[/b] 1 single draw call draws 10,000+ blades!",
		"diagram_text": "[code]   [Base Mesh Data] ---+---> [GPU Instance Buffer: T0] -> Instance 0\n   (4 Verts, 2 Tris)   +---> [GPU Instance Buffer: T1] -> Instance 1\n                       +---> [GPU Instance Buffer: T2] -> Instance 2\n                       +---> [GPU Instance Buffer: Tn] -> Instance n[/code]",
		"vars_text": "• [b]MultiMesh[/b]: Modern engine replacement for display lists\n• [b]PackedFloat32Array[/b]: Direct contiguous memory buffer to VRAM",
		"completion_type": "proximity",
		"status": "Reach the overlook waypoint"
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
		
	# 4. Position and Configure World Highlight Waypoint
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
	
	# Update distance in Objective HUD
	if player and active_highlight and active_highlight.visible:
		var dist = player.global_position.distance_to(data["pos"])
		if hud_distance_label:
			hud_distance_label.text = "[ %.1fm ]" % dist
	else:
		if hud_distance_label:
			hud_distance_label.text = ""
			
	# Process Milestone Specific Completion Conditions
	match data["completion_type"]:
		"observe_near":
			# Milestone 2: Stand near grass and observe sway for 3.5 seconds
			if player and player.global_position.distance_to(data["pos"]) < 6.0:
				walk_time_tracker += delta
				if formula_panel:
					formula_panel.set_progress(walk_time_tracker / 3.5)
					formula_panel.set_status("Observing Shader Deformation... (%d%%)" % int((walk_time_tracker / 3.5) * 100), Color(0.2, 1.0, 0.5))
				if walk_time_tracker >= 3.5:
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

func _finish_all_milestones() -> void:
	is_active = false
	if formula_panel:
		formula_panel.set_status("CONGRATULATIONS! ALL 5 UNITS COMPLETED 🎉", Color(1.0, 0.85, 0.2))
	if concept_title:
		concept_title.text = "CGVR LEARNING JOURNEY COMPLETED"
	if explanation_label:
		explanation_label.text = "Outstanding work, Explorer! You have explored and experienced all core concepts across CGVR Units I through V: Primitives, Shaders, Input/Output, Transformations, 3D Viewing, and VR Modelling!"
	if action_box_label:
		action_box_label.text = "Press 'T' anytime to replay or select any Unit from the dropdown menu to revisit specific concepts."
	if active_highlight:
		active_highlight.visible = false

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
