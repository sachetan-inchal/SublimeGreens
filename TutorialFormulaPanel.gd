extends Control
class_name TutorialFormulaPanel

@onready var panel_container: PanelContainer = find_child("PanelContainer", true, false)
@onready var concept_title: Label = find_child("ConceptTitle", true, false)
@onready var unit_tag: Label = find_child("UnitTag", true, false)
@onready var math_content: RichTextLabel = find_child("MathContent", true, false)
@onready var diagram_content: RichTextLabel = find_child("DiagramContent", true, false)
@onready var vars_content: RichTextLabel = find_child("VarsContent", true, false)
@onready var code_file_label: Label = find_child("FileLabel", true, false)
@onready var code_func_label: Label = find_child("FuncLabel", true, false)
@onready var implementation_type_label: Label = find_child("TypeLabel", true, false)
@onready var status_label: Label = find_child("StatusLabel", true, false)
@onready var status_bar: ProgressBar = find_child("ProgressBar", true, false)

var transition_tween: Tween

func _ready() -> void:
	_resolve_nodes()
	if panel_container:
		panel_container.modulate.a = 0.0
	if status_bar:
		status_bar.visible = false

func _resolve_nodes() -> void:
	if not panel_container: panel_container = find_child("PanelContainer", true, false)
	if not concept_title: concept_title = find_child("ConceptTitle", true, false)
	if not unit_tag: unit_tag = find_child("UnitTag", true, false)
	if not math_content: math_content = find_child("MathContent", true, false)
	if not diagram_content: diagram_content = find_child("DiagramContent", true, false)
	if not vars_content: vars_content = find_child("VarsContent", true, false)
	if not code_file_label: code_file_label = find_child("FileLabel", true, false)
	if not code_func_label: code_func_label = find_child("FuncLabel", true, false)
	if not implementation_type_label: implementation_type_label = find_child("TypeLabel", true, false)
	if not status_label: status_label = find_child("StatusLabel", true, false)
	if not status_bar: status_bar = find_child("ProgressBar", true, false)

func display_formula(data: Dictionary) -> void:
	_resolve_nodes()
	if transition_tween and transition_tween.is_valid():
		transition_tween.kill()
		
	transition_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if panel_container:
		transition_tween.tween_property(panel_container, "modulate:a", 0.2, 0.12)
		transition_tween.tween_callback(func():
			_apply_data(data)
		)
		transition_tween.tween_property(panel_container, "modulate:a", 1.0, 0.2)
	else:
		_apply_data(data)

func _apply_data(data: Dictionary) -> void:
	_resolve_nodes()
	if concept_title:
		concept_title.text = data.get("concept_title", "Concept Name")
	if unit_tag:
		unit_tag.text = data.get("unit_tag", "UNIT I")
	
	# Math formulas
	if math_content:
		math_content.text = data.get("math_text", "")
	
	# Diagram / visualization
	if diagram_content:
		diagram_content.text = data.get("diagram_text", "")
	
	# Variable definitions
	if vars_content:
		vars_content.text = data.get("vars_text", "")
	
	# Code reference
	if code_file_label:
		code_file_label.text = "📁 " + data.get("code_file", "Chunk.gd")
	if code_func_label:
		code_func_label.text = "⚙️ " + data.get("code_func", "_process()")
	if implementation_type_label:
		implementation_type_label.text = "📌 " + data.get("impl_type", "Implemented Directly")
	
	set_status(data.get("status", "Waiting for Player..."), Color(0.3, 0.8, 1.0))

func set_status(text: String, col: Color = Color(0.3, 0.8, 1.0)) -> void:
	if status_label:
		status_label.text = "● STATUS: " + text
		status_label.modulate = col

func set_progress(val: float) -> void:
	if status_bar:
		status_bar.visible = val > 0.0 and val < 1.0
		status_bar.value = val * 100.0

func set_panel_visible(vis: bool) -> void:
	if transition_tween and transition_tween.is_valid():
		transition_tween.kill()
	transition_tween = create_tween()
	var target_a = 1.0 if vis else 0.0
	if panel_container:
		transition_tween.tween_property(panel_container, "modulate:a", target_a, 0.3)
