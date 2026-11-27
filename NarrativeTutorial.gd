extends CanvasLayer

signal tutorial_stage_changed(stage: int)
signal tutorial_completed()

enum Stage {
	INACTIVE = 0,
	STAGE_1_INTRO = 1,
	STAGE_2_MOVEMENT = 2,
	STAGE_3_SUN_SEEK = 3,
	STAGE_4_SUN_FOUND = 4,
	STAGE_5_COMPLETION = 5
}

const SAVE_PATH: String = "user://tutorial.cfg"
const SECTION_NAME: String = "tutorial"
const KEY_NAME: String = "completed"

# Configurable nodes (auto-discovered if left empty)
@export var player: CharacterBody3D
@export var sun_light: DirectionalLight3D

# UI Node References
@onready var panel_container: PanelContainer = $CenterContainer/PanelContainer
@onready var badge_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/Badge
@onready var step_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/StepLabel
@onready var message_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MessageLabel
@onready var progress_bar: ProgressBar = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ProgressBar
@onready var hint_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HintLabel
@onready var action_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ActionButton
@onready var replay_hint: Label = $ReplayHint

# Internal State
var current_stage: Stage = Stage.INACTIVE
var is_active: bool = false
var camera: Camera3D

# Stage 1 tracking
var stage_1_timer: float = 0.0
const STAGE_1_MIN_READ_TIME: float = 3.5

# Stage 2 tracking
var movement_origin: Vector3 = Vector3.ZERO
var accumulated_distance: float = 0.0
const REQUIRED_MOVE_DISTANCE: float = 6.0

# Stage 3 tracking (Sun detection)
var sun_gaze_time: float = 0.0
const REQUIRED_SUN_GAZE_TIME: float = 0.8 # Gaze duration in seconds to avoid accidental trigger
const SUN_DOT_THRESHOLD: float = 0.72      # Within ~43 degrees of direct sun alignment

# Stage 4 tracking
var stage_4_timer: float = 0.0
const STAGE_4_READ_TIME: float = 7.0

# Animation Tweens
var fade_tween: Tween
var typewriter_tween: Tween

func _ready() -> void:
	# Hide UI initially
	panel_container.modulate.a = 0.0
	panel_container.visible = false
	progress_bar.visible = false
	action_button.visible = false
	hint_label.visible = false
	replay_hint.visible = false
	
	action_button.pressed.connect(_on_action_button_pressed)
	
	# Resolve node dependencies
	_resolve_nodes()
	
	# Check first-time launch status
	if not has_completed_tutorial():
		# Automatically start tutorial for first-time players
		start_tutorial()
	else:
		set_process(false)
		print("[NarrativeTutorial] Tutorial previously completed. Press 'T' to replay.")

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

func has_completed_tutorial() -> bool:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		return config.get_value(SECTION_NAME, KEY_NAME, false)
	return false

func save_completion_state(completed: bool) -> void:
	var config = ConfigFile.new()
	config.load(SAVE_PATH) # Preserve other settings if present
	config.set_value(SECTION_NAME, KEY_NAME, completed)
	config.save(SAVE_PATH)

func start_tutorial() -> void:
	_resolve_nodes()
	is_active = true
	set_process(true)
	panel_container.visible = true
	set_stage(Stage.STAGE_1_INTRO)

func restart_tutorial() -> void:
	print("[NarrativeTutorial] Restarting narrative tutorial...")
	_show_temporary_hint("Tutorial restarted! Press 'T' anytime to replay.")
	start_tutorial()

func _unhandled_input(event: InputEvent) -> void:
	# Allow pressing T to replay the tutorial at any time
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			restart_tutorial()
			return
			
	# In Stage 5, allow Enter or Space to also confirm Continue Exploring
	if current_stage == Stage.STAGE_5_COMPLETION and is_active:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_on_action_button_pressed()
				get_viewport().set_input_as_handled()

func set_stage(new_stage: Stage) -> void:
	current_stage = new_stage
	emit_signal("tutorial_stage_changed", int(new_stage))
	
	match current_stage:
		Stage.STAGE_1_INTRO:
			_setup_stage_1()
		Stage.STAGE_2_MOVEMENT:
			_setup_stage_2()
		Stage.STAGE_3_SUN_SEEK:
			_setup_stage_3()
		Stage.STAGE_4_SUN_FOUND:
			_setup_stage_4()
		Stage.STAGE_5_COMPLETION:
			_setup_stage_5()
		Stage.INACTIVE:
			_finish_tutorial()

func _setup_stage_1() -> void:
	badge_label.text = "TUTORIAL"
	badge_label.modulate = Color(0.35, 0.75, 1.0)
	step_label.text = "Step 1 of 5"
	progress_bar.visible = false
	action_button.visible = false
	hint_label.visible = false
	
	stage_1_timer = 0.0
	var text = "Welcome, Explorer! Before we begin, let's discover how to navigate this 3D world. Use the W, A, S and D keys to move around. You can also move your mouse to look around your surroundings."
	_display_message(text)

func _setup_stage_2() -> void:
	badge_label.text = "EXPLORATION"
	badge_label.modulate = Color(0.4, 0.9, 0.6)
	step_label.text = "Step 2 of 5"
	progress_bar.visible = false
	action_button.visible = false
	
	if player:
		movement_origin = player.global_position
	accumulated_distance = 0.0
	
	hint_label.visible = true
	hint_label.text = "Walk around to get familiar with navigation"
	
	var text = "Great! Try moving around using W, A, S and D. Explore your surroundings and get comfortable navigating this world."
	_display_message(text)

func _setup_stage_3() -> void:
	badge_label.text = "DISCOVERY"
	badge_label.modulate = Color(1.0, 0.82, 0.35)
	step_label.text = "Step 3 of 5"
	
	sun_gaze_time = 0.0
	progress_bar.visible = true
	progress_bar.value = 0.0
	action_button.visible = false
	
	hint_label.visible = true
	hint_label.text = "Look up into the sky and face the glowing Sun"
	
	var text = "Now, look towards the sky! Move your mouse upwards and explore what is above you. Can you spot the Sun?"
	_display_message(text)

func _setup_stage_4() -> void:
	badge_label.text = "LIGHT SOURCE FOUND"
	badge_label.modulate = Color(1.0, 0.72, 0.2)
	step_label.text = "Step 4 of 5"
	progress_bar.visible = false
	action_button.visible = false
	hint_label.visible = false
	stage_4_timer = 0.0
	
	var text = "Well done! You discovered the Sun! It is the light source illuminating our 3D world. Notice how its light brightens the environment and helps us see the objects around us. This is an example of lighting in 3D computer graphics!"
	_display_message(text)

func _setup_stage_5() -> void:
	badge_label.text = "COMPLETED"
	badge_label.modulate = Color(0.5, 0.95, 0.5)
	step_label.text = "Step 5 of 5"
	progress_bar.visible = false
	hint_label.visible = false
	
	# Reveal Continue button and free mouse cursor so it can be clicked easily
	action_button.visible = true
	action_button.text = "Continue Exploring  [ Space ]"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var text = "Excellent work, Explorer! You've learned how to navigate this world and discovered its primary light source. Continue exploring and observe how lighting affects your surroundings. Enjoy your adventure!"
	_display_message(text)

func _process(delta: float) -> void:
	if not is_active:
		return
		
	match current_stage:
		Stage.STAGE_1_INTRO:
			stage_1_timer += delta
			# Transition to stage 2 once player had time to read or started moving
			var player_moved = false
			if player:
				player_moved = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) \
					or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D)
			if stage_1_timer >= STAGE_1_MIN_READ_TIME and (player_moved or stage_1_timer >= 6.0):
				set_stage(Stage.STAGE_2_MOVEMENT)
				
		Stage.STAGE_2_MOVEMENT:
			if player:
				var current_pos = player.global_position
				var dist = current_pos.distance_to(movement_origin)
				if dist > accumulated_distance:
					accumulated_distance = dist
				if accumulated_distance >= REQUIRED_MOVE_DISTANCE:
					set_stage(Stage.STAGE_3_SUN_SEEK)
					
		Stage.STAGE_3_SUN_SEEK:
			_check_sun_detection(delta)
			
		Stage.STAGE_4_SUN_FOUND:
			stage_4_timer += delta
			if stage_4_timer >= STAGE_4_READ_TIME:
				set_stage(Stage.STAGE_5_COMPLETION)

func _check_sun_detection(delta: float) -> void:
	if not sun_light or not camera:
		_resolve_nodes()
		if not sun_light or not camera:
			return
			
	# Direction towards the Sun in the sky
	# In Godot, DirectionalLight3D points in -basis.z.
	# The Sun source in the sky is in the direction of +basis.z.
	var sun_dir: Vector3 = sun_light.global_transform.basis.z.normalized()
	var cam_forward: Vector3 = -camera.global_transform.basis.z.normalized()
	
	# Check dot product between camera forward vector and sun direction
	var dot: float = cam_forward.dot(sun_dir)
	
	# Camera pitch check: camera must be pitched upwards into the sky
	var is_looking_up: bool = cam_forward.y > 0.15
	
	# Screen projection check: ensure the Sun position projects onto the viewport
	var sun_world_pos: Vector3 = camera.global_position + sun_dir * 1000.0
	var is_in_viewport: bool = false
	if not camera.is_position_behind(sun_world_pos):
		var screen_pos = camera.unproject_position(sun_world_pos)
		var vp_rect = camera.get_viewport().get_visible_rect()
		is_in_viewport = vp_rect.has_point(screen_pos)
	
	# Sun is confirmed visible when looking up towards the actual sun direction
	var sun_is_visible: bool = (dot >= SUN_DOT_THRESHOLD) and is_looking_up and is_in_viewport
	
	if sun_is_visible:
		sun_gaze_time += delta
		var progress_ratio = clamp(sun_gaze_time / REQUIRED_SUN_GAZE_TIME, 0.0, 1.0)
		progress_bar.value = progress_ratio * 100.0
		hint_label.text = "Sun detected! Keep looking at it... (%d%%)" % int(progress_ratio * 100.0)
		hint_label.modulate = Color(1.0, 0.9, 0.4)
		
		if sun_gaze_time >= REQUIRED_SUN_GAZE_TIME:
			set_stage(Stage.STAGE_4_SUN_FOUND)
	else:
		# Gradually decay gaze timer if player looks away
		sun_gaze_time = max(0.0, sun_gaze_time - delta * 2.5)
		var progress_ratio = clamp(sun_gaze_time / REQUIRED_SUN_GAZE_TIME, 0.0, 1.0)
		progress_bar.value = progress_ratio * 100.0
		hint_label.text = "Look up into the sky and face the glowing Sun"
		hint_label.modulate = Color(0.8, 0.85, 0.9)

func _display_message(text: String) -> void:
	# Cancel existing tweens
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
		
	# Smooth fade out, change text, then smooth fade in
	fade_tween = create_tween().set_parallel(false)
	
	if panel_container.modulate.a > 0.05:
		fade_tween.tween_property(panel_container, "modulate:a", 0.0, 0.15)
		
	fade_tween.tween_callback(func():
		message_label.text = text
		message_label.visible_ratio = 0.0
	)
	
	fade_tween.tween_property(panel_container, "modulate:a", 1.0, 0.3)
	fade_tween.tween_callback(func():
		# Typewriter animation
		var char_count = text.length()
		var duration = clamp(float(char_count) * 0.016, 0.5, 1.8)
		typewriter_tween = create_tween()
		typewriter_tween.tween_property(message_label, "visible_ratio", 1.0, duration)
	)

func _on_action_button_pressed() -> void:
	# Dismiss tutorial, save state, and return to game
	save_completion_state(true)
	emit_signal("tutorial_completed")
	_finish_tutorial()

func _finish_tutorial() -> void:
	is_active = false
	set_process(false)
	
	# Recapture mouse for normal gameplay
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Smooth fade out panel
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(panel_container, "modulate:a", 0.0, 0.4)
	fade_tween.tween_callback(func():
		panel_container.visible = false
	)
	
	_show_temporary_hint("Tutorial complete! Press 'T' anytime to replay.")

func _show_temporary_hint(msg: String) -> void:
	replay_hint.text = msg
	replay_hint.visible = true
	replay_hint.modulate.a = 0.0
	
	var hint_tween = create_tween()
	hint_tween.tween_property(replay_hint, "modulate:a", 1.0, 0.4)
	hint_tween.tween_interval(3.5)
	hint_tween.tween_property(replay_hint, "modulate:a", 0.0, 0.5)
	hint_tween.tween_callback(func():
		replay_hint.visible = false
	)
