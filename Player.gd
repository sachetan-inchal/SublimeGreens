extends CharacterBody3D

const SPEED = 10.0
const JUMP_VELOCITY = 5.0
@onready var pivot: Node3D = $Node3D
@onready var footstep_player: AudioStreamPlayer3D = $FootstepPlayer
@export var sensitivity = 0.25
var is_mouse_input_enabled = true

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	var quiz_ui = get_tree().root.find_child("QuizUI", true, false)
	if quiz_ui and quiz_ui.is_quiz_open:
		return

	# Toggle mouse mode between Look (Captured) and Cursor (Visible)
	if event is InputEventKey and event.is_pressed() and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_ALT or event.keycode == KEY_QUOTELEFT:
			toggle_mouse_mode()
			get_viewport().set_input_as_handled()
			return

	# Only rotate camera when mouse is captured
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * sensitivity))
		pivot.rotate_x(deg_to_rad(-event.relative.y * sensitivity))
		pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-90), deg_to_rad(45))

func toggle_mouse_mode() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
func _physics_process(delta: float) -> void:
	var quiz_ui = get_tree().root.find_child("QuizUI", true, false)
	if quiz_ui and quiz_ui.is_quiz_open:
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= 9.8 * delta * 2
		move_and_slide()
		if footstep_player and footstep_player.playing and not footstep_player.stream_paused:
			footstep_player.stream_paused = true
		return

	if Input.is_action_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	var direction = Vector3.ZERO 

	if Input.is_key_pressed(KEY_W):
		direction -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		direction += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		direction -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		direction += transform.basis.x

	direction.y = 0 
	direction = direction.normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	var is_sprinting = Input.is_key_pressed(KEY_SHIFT)
	if is_sprinting:
		velocity.x *= 2
		velocity.z *= 2

	velocity.y -= 9.8 * delta * 2

	move_and_slide()

	_handle_movement_audio(direction, is_sprinting)

func _handle_movement_audio(direction: Vector3, is_sprinting: bool) -> void:
	if not footstep_player:
		return

	# Only play footsteps when actively moving along the ground
	var is_moving = direction.length_squared() > 0.001 and is_on_floor()

	if is_moving:
		# Pitch scale: normal walk = 1.0, sprint = 1.35 (faster pace)
		footstep_player.pitch_scale = 1.35 if is_sprinting else 1.0
		
		# Resume if paused or start playing if stopped, without resetting position
		if footstep_player.stream_paused:
			footstep_player.stream_paused = false
		elif not footstep_player.playing:
			footstep_player.play()
	else:
		# Pause playback so it stops instantly and resumes seamlessly from where it left off
		if footstep_player.playing and not footstep_player.stream_paused:
			footstep_player.stream_paused = true

