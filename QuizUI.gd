extends CanvasLayer
class_name QuizUI

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var syllabus_label: Label = $Panel/VBoxContainer/SyllabusLabel
@onready var question_label: Label = $Panel/VBoxContainer/QuestionLabel
@onready var options_container: VBoxContainer = $Panel/VBoxContainer/OptionsContainer
@onready var feedback_label: Label = $Panel/VBoxContainer/FeedbackLabel
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

var current_marker: MilestoneMarker = null
var active_marker_near: MilestoneMarker = null
var is_quiz_open: bool = false

func _ready() -> void:
	panel.visible = false
	close_button.pressed.connect(close_quiz)

func notify_marker_entered(marker: MilestoneMarker) -> void:
	active_marker_near = marker

func notify_marker_exited(marker: MilestoneMarker) -> void:
	if active_marker_near == marker:
		active_marker_near = null
	if current_marker == marker and is_quiz_open:
		close_quiz()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.echo:
		if event.keycode == KEY_E:
			if is_quiz_open:
				close_quiz()
			elif active_marker_near != null:
				open_quiz(active_marker_near)
		elif event.keycode == KEY_ESCAPE and is_quiz_open:
			close_quiz()

func open_quiz(marker: MilestoneMarker) -> void:
	current_marker = marker
	is_quiz_open = true
	panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	title_label.text = marker.title
	syllabus_label.text = "📚 Syllabus: " + marker.syllabus_unit
	question_label.text = marker.question
	feedback_label.text = ""

	# Clear previous options
	for child in options_container.get_children():
		child.queue_free()

	# Create option buttons
	for i in range(marker.options.size()):
		var btn = Button.new()
		btn.text = marker.options[i]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var opt_idx = i
		btn.pressed.connect(func(): _on_option_selected(opt_idx))
		options_container.add_child(btn)

func _on_option_selected(index: int) -> void:
	if not current_marker:
		return

	if index == current_marker.correct_option_index:
		feedback_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		feedback_label.text = "✅ Correct! " + current_marker.explanation
	else:
		feedback_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		feedback_label.text = "❌ Incorrect. Try again!"

func close_quiz() -> void:
	is_quiz_open = false
	panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
