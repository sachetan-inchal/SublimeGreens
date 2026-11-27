extends CanvasLayer

# --- Node References: Invitation Modal ---
@onready var invitation_modal: PanelContainer = $InvitationModal
@onready var inv_title: Label = $InvitationModal/Margin/VBox/InvTitle
@onready var start_quiz_btn: Button = $InvitationModal/Margin/VBox/HBox/StartQuizBtn
@onready var cancel_inv_btn: Button = $InvitationModal/Margin/VBox/HBox/CancelInvBtn

# --- Node References: Quiz Panel ---
@onready var quiz_panel: PanelContainer = $QuizPanel
@onready var title_label: Label = $QuizPanel/Margin/VBox/HeaderHBox/TitleLabel
@onready var progress_label: Label = $QuizPanel/Margin/VBox/HeaderHBox/ProgressLabel
@onready var syllabus_label: Label = $QuizPanel/Margin/VBox/SyllabusLabel
@onready var question_label: Label = $QuizPanel/Margin/VBox/QuestionLabel
@onready var options_container: VBoxContainer = $QuizPanel/Margin/VBox/OptionsContainer
@onready var feedback_label: Label = $QuizPanel/Margin/VBox/FeedbackPanel/Margin/FeedbackLabel
@onready var close_button: Button = $QuizPanel/Margin/VBox/FooterHBox/CloseButton
@onready var next_button: Button = $QuizPanel/Margin/VBox/FooterHBox/NextButton

# --- State ---
var current_marker: MilestoneMarker = null
var active_marker_near: MilestoneMarker = null
var is_invitation_open: bool = false
var is_quiz_open: bool = false

var questions: Array[Dictionary] = []
var current_q_index: int = 0
var answered_current: bool = false
var score: int = 0

func _ready() -> void:
	invitation_modal.visible = false
	quiz_panel.visible = false
	next_button.visible = false

	start_quiz_btn.pressed.connect(_on_start_quiz_pressed)
	cancel_inv_btn.pressed.connect(_on_cancel_inv_pressed)
	close_button.pressed.connect(close_quiz)
	next_button.pressed.connect(_on_next_question)

func notify_marker_entered(marker: MilestoneMarker) -> void:
	active_marker_near = marker

func notify_marker_exited(marker: MilestoneMarker) -> void:
	if active_marker_near == marker:
		active_marker_near = null
	if current_marker == marker and (is_invitation_open or is_quiz_open):
		_dismiss_all()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.echo:
		match event.keycode:
			KEY_E:
				if is_invitation_open:
					_on_start_quiz_pressed()
				elif is_quiz_open:
					pass # E does nothing during active quiz
				elif active_marker_near != null:
					open_invitation(active_marker_near)
			KEY_ESCAPE:
				if is_quiz_open:
					close_quiz()
				elif is_invitation_open:
					_on_cancel_inv_pressed()

# ---------------------------
# INVITATION MODAL
# ---------------------------
func open_invitation(marker: MilestoneMarker) -> void:
	current_marker = marker
	is_invitation_open = true
	invitation_modal.visible = true
	inv_title.text = marker.title
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_cancel_inv_pressed() -> void:
	_dismiss_all()

func _on_start_quiz_pressed() -> void:
	if not current_marker:
		return
	is_invitation_open = false
	invitation_modal.visible = false
	_load_and_start_quiz()

# ---------------------------
# QUIZ FLOW (Reverted to single milestone question as originally asked)
# ---------------------------
func _load_and_start_quiz() -> void:
	questions = [_build_legacy_question()]
	current_q_index = 0
	score = 0
	is_quiz_open = true
	quiz_panel.visible = true
	title_label.text = current_marker.title
	_show_question(current_q_index)

func _build_legacy_question() -> Dictionary:
	return {
		"id": "legacy",
		"type": "mcq",
		"unit": current_marker.syllabus_unit,
		"statement": current_marker.question,
		"options": current_marker.options,
		"correct_index": current_marker.correct_option_index,
		"correct_explanation": "✅ Correct! " + current_marker.explanation,
		"incorrect_explanations": ["", "", "", ""]
	}

func _show_question(index: int) -> void:
	answered_current = false
	next_button.visible = false
	var q: Dictionary = questions[index]

	progress_label.text = "Q %d of %d" % [index + 1, questions.size()]
	syllabus_label.text = "📚 " + q.get("unit", "")
	question_label.text = q.get("statement", "")
	feedback_label.text = "Select an answer to view the syllabus explanation."
	feedback_label.remove_theme_color_override("font_color")

	# Clear and rebuild option buttons
	for child in options_container.get_children():
		child.queue_free()

	await get_tree().process_frame  # Ensure freed nodes are removed

	var opts: Array = q.get("options", [])
	for i in range(opts.size()):
		var btn := Button.new()
		btn.text = opts[i]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0, 44)
		var captured_i = i
		btn.pressed.connect(func(): _on_option_selected(captured_i))
		options_container.add_child(btn)

func _on_option_selected(selected_index: int) -> void:
	if answered_current:
		return
	answered_current = true

	var q: Dictionary = questions[current_q_index]
	var correct_idx: int = q.get("correct_index", 0)
	var incorrect_explanations: Array = q.get("incorrect_explanations", [])

	# Color all buttons
	var btns = options_container.get_children()
	for i in range(btns.size()):
		var b = btns[i]
		if i == correct_idx:
			b.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		elif i == selected_index:
			b.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			b.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	# Build feedback text
	var feedback: String = ""
	if selected_index == correct_idx:
		score += 1
		feedback_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		feedback = "✅ Correct!   " + q.get("correct_explanation", "")
		# Mark milestone completed in quest manager
		if QuestLocationManager.instance and current_marker:
			QuestLocationManager.instance.set_quest_status(current_marker.milestone_id, QuestMarker.QuestStatus.COMPLETED)
	else:
		feedback_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		var wrong_exp: String = ""
		if incorrect_explanations.size() > selected_index:
			wrong_exp = incorrect_explanations[selected_index]
		feedback = "❌ Incorrect.   " + wrong_exp + "\n\n✅ Correct answer:   " + q.get("correct_explanation", "")

	feedback_label.text = feedback

	# Show Next button unless this is the last question
	if current_q_index < questions.size() - 1:
		next_button.visible = true
		next_button.text = "Next Question  →"
	else:
		next_button.visible = true
		next_button.text = "Finish (%d / %d correct)" % [score, questions.size()]

func _on_next_question() -> void:
	if current_q_index < questions.size() - 1:
		current_q_index += 1
		_show_question(current_q_index)
	else:
		# Quiz complete
		close_quiz()

# ---------------------------
# CLOSE / DISMISS
# ---------------------------
func close_quiz() -> void:
	_dismiss_all()

func _dismiss_all() -> void:
	is_quiz_open = false
	is_invitation_open = false
	quiz_panel.visible = false
	invitation_modal.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
