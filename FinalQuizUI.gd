extends CanvasLayer
class_name FinalQuizUI

# --- Nodes: Invitation ---
@onready var invitation_root: Control      = $InvitationRoot
@onready var inv_title: Label              = $InvitationRoot/GlowPanel/VBox/InvTitle
@onready var inv_start_btn: Button         = $InvitationRoot/GlowPanel/VBox/BtnRow/StartBtn
@onready var inv_later_btn: Button         = $InvitationRoot/GlowPanel/VBox/BtnRow/LaterBtn

# --- Nodes: Quiz ---
@onready var quiz_root: Control            = $QuizRoot
@onready var quiz_title: Label             = $QuizRoot/GlowPanel/VBox/Header/QuizTitle
@onready var unit_badge: Label             = $QuizRoot/GlowPanel/VBox/Header/UnitBadge
@onready var progress_bar: ProgressBar     = $QuizRoot/GlowPanel/VBox/ProgressBar
@onready var progress_lbl: Label           = $QuizRoot/GlowPanel/VBox/ProgressBar/ProgressLbl
@onready var question_lbl: Label           = $QuizRoot/GlowPanel/VBox/QuestionLbl
@onready var options_vbox: VBoxContainer   = $QuizRoot/GlowPanel/VBox/OptionsVBox
@onready var feedback_panel: PanelContainer= $QuizRoot/GlowPanel/VBox/FeedbackPanel
@onready var feedback_lbl: Label           = $QuizRoot/GlowPanel/VBox/FeedbackPanel/Margin/FeedbackLbl
@onready var next_btn: Button              = $QuizRoot/GlowPanel/VBox/Footer/NextBtn
@onready var quit_btn: Button              = $QuizRoot/GlowPanel/VBox/Footer/QuitBtn

# --- Nodes: Results ---
@onready var results_root: Control         = $ResultsRoot
@onready var score_lbl: Label              = $ResultsRoot/GlowPanel/VBox/ScoreLbl
@onready var grade_lbl: Label              = $ResultsRoot/GlowPanel/VBox/GradeLbl
@onready var unit_perf_lbl: Label          = $ResultsRoot/GlowPanel/VBox/UnitPerfLbl
@onready var retake_btn: Button            = $ResultsRoot/GlowPanel/VBox/BtnRow/RetakeBtn
@onready var close_btn: Button             = $ResultsRoot/GlowPanel/VBox/BtnRow/CloseBtn

# --- State ---
var is_active: bool = false
var is_invitation_open: bool = false
var is_quiz_open: bool = false
var invitation_pending: bool = false  # dismissed but can re-open

var questions: Array[Dictionary] = []
var current_q: int = 0
var score: int = 0
var answered: bool = false
var unit_scores: Dictionary = {}  # unit_name -> [correct, total]
var wrong_answers: Array[Dictionary] = []

var _score_tween: Tween

func _ready() -> void:
	invitation_root.visible = false
	quiz_root.visible = false
	results_root.visible = false

	inv_start_btn.pressed.connect(_on_start_pressed)
	inv_later_btn.pressed.connect(_on_later_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	quit_btn.pressed.connect(_dismiss)
	retake_btn.pressed.connect(_retake)
	close_btn.pressed.connect(_dismiss)

	# Connect to QuestLocationManager when it becomes available
	call_deferred("_connect_to_manager")

func _connect_to_manager() -> void:
	await get_tree().process_frame
	var qlm = QuestLocationManager.instance
	if qlm:
		if not qlm.all_units_complete.is_connected(_on_all_units_complete):
			qlm.all_units_complete.connect(_on_all_units_complete)

func _on_all_units_complete() -> void:
	invitation_pending = true
	# Small delay so the last milestone close animation finishes
	await get_tree().create_timer(1.2).timeout
	show_invitation()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_quiz_open or is_invitation_open:
				_dismiss()
				return
		
		# Re-open invitation with F5 key if pending but dismissed
		if event.keycode == KEY_F5 and invitation_pending and not is_active:
			show_invitation()
			return

		# Handle Invitation keyboard controls (Y / Space / Enter to start, N to dismiss)
		if is_invitation_open:
			if event.keycode in [KEY_Y, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
				_on_start_pressed()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_N:
				_on_later_pressed()
				get_viewport().set_input_as_handled()
				return

		# Handle Quiz keyboard controls (1-4, A-D for options, Space/Enter for Next)
		if is_quiz_open:
			if not answered:
				var chosen_idx: int = -1
				match event.keycode:
					KEY_1, KEY_KP_1, KEY_A:
						chosen_idx = 0
					KEY_2, KEY_KP_2, KEY_B:
						chosen_idx = 1
					KEY_3, KEY_KP_3, KEY_C:
						chosen_idx = 2
					KEY_4, KEY_KP_4, KEY_D:
						chosen_idx = 3
				if chosen_idx != -1 and chosen_idx < options_vbox.get_child_count():
					_on_answer(chosen_idx)
					get_viewport().set_input_as_handled()
					return
			else:
				# Question is already answered: Space / Enter / E / Right Arrow moves to Next Question
				if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_RIGHT]:
					_on_next_pressed()
					get_viewport().set_input_as_handled()
					return

		# Handle Results keyboard controls (R to Retake, Space / Enter / Escape to Close)
		if results_root.visible:
			if event.keycode == KEY_R:
				_retake()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				_dismiss()
				get_viewport().set_input_as_handled()
				return

# ───────────────────────────────────────────
# INVITATION
# ───────────────────────────────────────────
func show_invitation() -> void:
	is_invitation_open = true
	is_active = true
	invitation_root.visible = true
	quiz_root.visible = false
	results_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_animate_in(invitation_root)

func _on_start_pressed() -> void:
	is_invitation_open = false
	invitation_root.visible = false
	_begin_quiz()

func _on_later_pressed() -> void:
	invitation_pending = true  # keep flag; F5 can reopen
	_dismiss()

# ───────────────────────────────────────────
# QUIZ
# ───────────────────────────────────────────
func _begin_quiz() -> void:
	questions = _build_full_question_bank()
	# Randomize questions order and randomize answer options within each question
	questions.shuffle()
	for q in questions:
		_randomize_question_options(q)

	current_q = 0
	score = 0
	unit_scores = {}
	wrong_answers = []
	answered = false
	is_quiz_open = true
	quiz_root.visible = true
	_animate_in(quiz_root)
	_show_question()

func _randomize_question_options(q: Dictionary) -> void:
	var original_opts: Array = q.get("options", []).duplicate()
	var original_correct_idx: int = q.get("correct_index", 0)
	var original_inc_exps: Array = q.get("incorrect_explanations", []).duplicate()
	var correct_text: String = original_opts[original_correct_idx] if original_correct_idx < original_opts.size() else ""

	# Pair option with its explanation
	var items: Array[Dictionary] = []
	for i in range(original_opts.size()):
		var inc_exp = original_inc_exps[i] if i < original_inc_exps.size() else ""
		items.append({
			"text": original_opts[i],
			"is_correct": (i == original_correct_idx),
			"inc_exp": inc_exp
		})

	items.shuffle()

	var new_opts: Array[String] = []
	var new_inc_exps: Array[String] = []
	var new_correct_idx: int = 0

	for i in range(items.size()):
		new_opts.append(items[i]["text"])
		new_inc_exps.append(items[i]["inc_exp"])
		if items[i]["is_correct"]:
			new_correct_idx = i

	q["options"] = new_opts
	q["incorrect_explanations"] = new_inc_exps
	q["correct_index"] = new_correct_idx

func _show_question() -> void:
	answered = false
	next_btn.visible = false
	feedback_panel.visible = false

	var q: Dictionary = questions[current_q]
	var total: int = questions.size()

	quiz_title.text = "CGVR Final Assessment"
	unit_badge.text = q.get("unit", "")
	progress_bar.max_value = total
	progress_bar.value = current_q
	progress_lbl.text = "Question %d / %d" % [current_q + 1, total]
	question_lbl.text = q.get("statement", "")

	for child in options_vbox.get_children():
		child.queue_free()
	await get_tree().process_frame

	for i in range(q.get("options", []).size()):
		var btn := Button.new()
		var opt_key = ["A", "B", "C", "D"][i] if i < 4 else str(i + 1)
		btn.text = "[ %s / %d ]  %s" % [opt_key, i + 1, q["options"][i]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0, 46)
		btn.add_theme_font_size_override("font_size", 13)
		var idx = i
		btn.pressed.connect(func(): _on_answer(idx))
		options_vbox.add_child(btn)

func _on_answer(selected: int) -> void:
	if answered:
		return
	answered = true

	var q: Dictionary = questions[current_q]
	var correct: int = q.get("correct_index", 0)
	var unit_name: String = q.get("unit_key", "General")

	if not unit_scores.has(unit_name):
		unit_scores[unit_name] = [0, 0]
	unit_scores[unit_name][1] += 1

	var btns := options_vbox.get_children()
	for i in btns.size():
		var b := btns[i] as Button
		if i == correct:
			b.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
		elif i == selected:
			b.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			b.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))

	feedback_panel.visible = true
	if selected == correct:
		score += 1
		unit_scores[unit_name][0] += 1
		feedback_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
		feedback_lbl.text = "✅  Correct!   " + q.get("correct_explanation", "")
	else:
		var inc_exps: Array = q.get("incorrect_explanations", [])
		var inc_exp: String = inc_exps[selected] if selected < inc_exps.size() else ""
		feedback_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		feedback_lbl.text = "❌  " + inc_exp + "\n\n✅  " + q.get("correct_explanation", "")
		wrong_answers.append({"q": q.get("statement",""), "correct": q["options"][correct]})

	if current_q < questions.size() - 1:
		next_btn.text = "Next  →  [Space / Enter]"
	else:
		next_btn.text = "See Results  [Space / Enter]"
	next_btn.visible = true

func _on_next_pressed() -> void:
	if current_q < questions.size() - 1:
		current_q += 1
		_show_question()
	else:
		_show_results()

# ───────────────────────────────────────────
# RESULTS
# ───────────────────────────────────────────
func _show_results() -> void:
	is_quiz_open = false
	quiz_root.visible = false
	results_root.visible = true
	invitation_pending = false
	_animate_in(results_root)

	var total := questions.size()
	var pct := int(float(score) / float(total) * 100.0)

	# Animated score count-up
	score_lbl.text = "Score: 0 / %d" % total
	if _score_tween and _score_tween.is_valid():
		_score_tween.kill()
	_score_tween = create_tween()
	var t_val := 0.0
	_score_tween.tween_method(func(v: float):
		score_lbl.text = "Score: %d / %d  (%d%%)" % [int(v), total, int(v / float(total) * 100.0)]
	, 0.0, float(score), 1.8)

	# Grade
	var grade: String
	var grade_color: Color
	if pct >= 90:
		grade = "🏆  Outstanding — O"
		grade_color = Color(1.0, 0.84, 0.0)
	elif pct >= 75:
		grade = "⭐  Distinction — A+"
		grade_color = Color(0.4, 1.0, 0.6)
	elif pct >= 60:
		grade = "✅  First Class — A"
		grade_color = Color(0.4, 0.8, 1.0)
	elif pct >= 50:
		grade = "👍  Pass — B"
		grade_color = Color(0.8, 0.8, 0.5)
	else:
		grade = "📚  Needs Review — Retake Recommended"
		grade_color = Color(1.0, 0.45, 0.35)
	grade_lbl.text = grade
	grade_lbl.add_theme_color_override("font_color", grade_color)

	# Unit-wise breakdown
	var perf := "── Unit Performance ──\n"
	for unit_key in unit_scores:
		var arr: Array = unit_scores[unit_key]
		perf += "%s:  %d / %d\n" % [unit_key, arr[0], arr[1]]
	unit_perf_lbl.text = perf

func _retake() -> void:
	results_root.visible = false
	_begin_quiz()

func _dismiss() -> void:
	is_active = false
	is_quiz_open = false
	is_invitation_open = false
	invitation_root.visible = false
	quiz_root.visible = false
	results_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ───────────────────────────────────────────
# ANIMATION HELPER
# ───────────────────────────────────────────
func _animate_in(node: Control) -> void:
	node.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.35)

# ───────────────────────────────────────────
# FULL 20-QUESTION BANK (all 5 units)
# ───────────────────────────────────────────
func _build_full_question_bank() -> Array[Dictionary]:
	var bank: Array[Dictionary] = []

	# ---- UNIT I: Computer Graphics Fundamentals ----
	bank.append({
		"unit": "Unit I: Computer Graphics & OpenGL",
		"unit_key": "Unit I",
		"statement": "Which OpenGL primitive type renders a series of connected line segments where the last vertex connects back to the first?",
		"options": ["GL_LINE_LOOP", "GL_LINE_STRIP", "GL_LINES", "GL_LINE_POLYGON"],
		"correct_index": 0,
		"correct_explanation": "GL_LINE_LOOP draws connected line segments and closes the loop from the last vertex back to the first vertex.",
		"incorrect_explanations": ["", "GL_LINE_STRIP connects vertices sequentially but does NOT close the loop.", "GL_LINES draws isolated pairs of line segments with no connection between pairs.", "GL_LINE_POLYGON does not exist in standard OpenGL."]
	})

	bank.append({
		"unit": "Unit I: RGB Color & Display Lists",
		"unit_key": "Unit I",
		"statement": "A display list in OpenGL compiled with glNewList(1, GL_COMPILE_AND_EXECUTE) will:",
		"options": ["Both compile the commands AND execute them immediately.", "Only store the commands for later; nothing executes at definition time.", "Execute the list once and then permanently delete it.", "Replace vertex buffer objects in OpenGL 4.x."],
		"correct_index": 0,
		"correct_explanation": "GL_COMPILE_AND_EXECUTE compiles the command list into display-list memory AND executes it immediately on the first definition call.",
		"incorrect_explanations": ["", "GL_COMPILE (not GL_COMPILE_AND_EXECUTE) only stores; it does not execute.", "Display lists persist in memory until explicitly deleted with glDeleteLists.", "Display lists are legacy OpenGL 1.x; modern OpenGL uses VAOs/VBOs, but that is a separate API."]
	})

	bank.append({
		"unit": "Unit I: OpenGL Graphics Pipeline",
		"unit_key": "Unit I",
		"statement": "In the OpenGL fixed-function pipeline, what is the correct stage order?",
		"options": ["Vertex → Primitive Assembly → Rasterization → Fragment → Framebuffer", "Fragment → Rasterization → Vertex → Framebuffer", "Rasterization → Vertex → Fragment → Display", "Vertex → Fragment → Primitive Assembly → Rasterization"],
		"correct_index": 0,
		"correct_explanation": "The classical OpenGL pipeline processes: Vertices → Primitive Assembly → Rasterization → Fragment shading → Final Framebuffer output.",
		"incorrect_explanations": ["", "Fragment processing cannot precede vertex processing.", "Rasterization always follows primitive assembly, never precedes vertex processing.", "Fragment shading always comes after rasterization, never before primitive assembly."]
	})

	bank.append({
		"unit": "Unit I: Primitives & Sierpinski Gasket",
		"unit_key": "Unit I",
		"statement": "In the recursive Sierpinski Gasket (3D tetrahedron), starting with 1 tetrahedron at level 0, how many sub-tetrahedrons exist at recursion level 2?",
		"options": ["16", "4", "8", "12"],
		"correct_index": 0,
		"correct_explanation": "At each level, 1 tetrahedron becomes 4. Level 1: 4¹ = 4. Level 2: 4² = 16 sub-tetrahedrons.",
		"incorrect_explanations": ["", "4 is only the count at level 1, not level 2.", "8 applies to binary (2-way) subdivision, not tetrahedral (4-way).", "12 has no mathematical basis for this recursion."]
	})

	# ---- UNIT II: Input Devices & VR I/O ----
	bank.append({
		"unit": "Unit II: Logical Input Devices",
		"unit_key": "Unit II",
		"statement": "Which logical input device class returns a single real value within a specified range, such as a slider or dial?",
		"options": ["Valuator", "Locator", "Stroke", "Pick"],
		"correct_index": 0,
		"correct_explanation": "A Valuator logical device returns a single scalar value (e.g. brightness slider or volume dial).",
		"incorrect_explanations": ["", "A Locator returns a 2D or 3D position (x, y) in the world coordinate system.", "A Stroke logical device returns a sequence of multiple positions, like a drawn path.", "A Pick device returns the identifier of a displayed object selected by the user."]
	})

	bank.append({
		"unit": "Unit II: VR Input Devices",
		"unit_key": "Unit II",
		"statement": "Which VR tracker technology uses light-emitting diodes (LEDs) sensed by external cameras to calculate the 6-DOF position and orientation of a controller?",
		"options": ["Optical (outside-in) tracking", "Electromagnetic field tracking", "Ultrasonic tracking", "Mechanical exoskeleton tracking"],
		"correct_index": 0,
		"correct_explanation": "Optical outside-in tracking (e.g. Valve Lighthouse, PlayStation Move) uses external cameras or laser sweeps to track LED/reflective markers on the device.",
		"incorrect_explanations": ["", "Electromagnetic tracking generates a magnetic field and senses distortion, but is susceptible to metal interference.", "Ultrasonic tracking uses sound wave time-of-flight, which is affected by air temperature and limited range.", "Mechanical exoskeletons track joint angles via encoders, not camera-sensor systems."]
	})

	bank.append({
		"unit": "Unit II: Measure & Trigger",
		"unit_key": "Unit II",
		"statement": "In the INPUT model, the mouse cursor position (continuous coordinate) corresponds to which device abstraction concept?",
		"options": ["Measure", "Trigger", "Device mode", "Event queue"],
		"correct_index": 0,
		"correct_explanation": "The 'measure' is the data value returned by the input device (position, displacement, force), independent of when or whether the application reads it.",
		"incorrect_explanations": ["", "A trigger is the signal that initiates data transfer from device to application, not the data itself.", "Device mode (request, sample, event) describes how data is retrieved, not the data value.", "An event queue is the buffer structure holding pending input events."]
	})

	# ---- UNIT III: Raster Algorithms & 2D Transformations ----
	bank.append({
		"unit": "Unit III: DDA Line Algorithm",
		"unit_key": "Unit III",
		"statement": "Using the DDA algorithm to draw a line from P1(2, 3) to P2(6, 7), what is the sampling step count and the value of Δx per step?",
		"options": ["Steps = 4, Δx = 1.0", "Steps = 8, Δx = 0.5", "Steps = 2, Δx = 2.0", "Steps = 4, Δx = 0.5"],
		"correct_index": 0,
		"correct_explanation": "dx = 6-2 = 4, dy = 7-3 = 4. Steps = max(|dx|, |dy|) = 4. Δx = dx/steps = 4/4 = 1.0, Δy = 1.0.",
		"incorrect_explanations": ["", "Steps of 8 would halve the sampling rate unnecessarily.", "Steps of 2 would skip pixels.", "Δx = 0.5 would result in 8 steps, not 4."]
	})

	bank.append({
		"unit": "Unit III: 2D Rotation Transformation",
		"unit_key": "Unit III",
		"statement": "A point P(0, 5) is rotated 90° counter-clockwise about the origin. What are its transformed coordinates P'?",
		"options": ["P' = (-5, 0)", "P' = (5, 0)", "P' = (0, -5)", "P' = (-5, -5)"],
		"correct_index": 0,
		"correct_explanation": "CCW 90° rotation: x' = x·cos90 − y·sin90 = 0·0 − 5·1 = −5; y' = x·sin90 + y·cos90 = 0·1 + 5·0 = 0. So P' = (−5, 0).",
		"incorrect_explanations": ["", "(5, 0) corresponds to 270° CCW (or 90° CW) rotation.", "(0, -5) is 180° rotation, not 90° CCW.", "(-5, -5) is a reflection, not a rotation by 90°."]
	})

	bank.append({
		"unit": "Unit III: Sutherland-Hodgman Clipping",
		"unit_key": "Unit III",
		"statement": "The Sutherland-Hodgman polygon clipping algorithm clips a polygon against:",
		"options": ["One clipping edge at a time, processing the full polygon for each boundary.", "All four window edges simultaneously in a single pass.", "Only horizontal clip lines, then rotates the polygon for vertical edges.", "Individual vertices, discarding entire edges at once."],
		"correct_index": 0,
		"correct_explanation": "Sutherland-Hodgman clips the polygon sequentially against one half-plane boundary edge at a time, passing the output polygon as input to the next boundary clip.",
		"incorrect_explanations": ["", "Processing all four boundaries simultaneously is the approach of the Cyrus-Beck or other algorithms, not Sutherland-Hodgman.", "It clips against arbitrary oriented boundaries, not exclusively horizontal lines.", "It tests each polygon edge (not just vertices) against the boundary and computes intersection points."]
	})

	bank.append({
		"unit": "Unit III: Filled Area — Scanline",
		"unit_key": "Unit III",
		"statement": "In the scanline polygon fill algorithm, the Active Edge Table (AET) stores which data for each edge intersecting the current scanline?",
		"options": ["x-intercept of the current scanline, 1/slope (Δx), and the maximum y of the edge.", "The pixel color, z-depth, and polygon ID.", "The UV texture coordinates and normal vector.", "The midpoint of the edge and its length."],
		"correct_index": 0,
		"correct_explanation": "The AET stores: current x-intercept (x), inverse slope (1/m = Δx per scanline), and upper y_max to know when to remove the edge.",
		"incorrect_explanations": ["", "Color and z-depth belong to the framebuffer/z-buffer, not the AET geometric structure.", "UV and normals are shading attributes; AET only tracks geometric edge properties.", "Midpoints and lengths are unused; the AET is updated incrementally using x += Δx each scanline."]
	})

	# ---- UNIT IV: 3D Viewing, Projections, Visible Surfaces ----
	bank.append({
		"unit": "Unit IV: Perspective Projection",
		"unit_key": "Unit IV",
		"statement": "In a perspective projection with centre of projection at the origin, a point P(x, y, z) projects onto the view plane at z = d. What is the projected x coordinate xp?",
		"options": ["xp = (d · x) / z", "xp = x / d", "xp = x · z / d", "xp = x − d"],
		"correct_index": 0,
		"correct_explanation": "By similar triangles: xp/d = x/z → xp = d·x/z. This is the standard perspective divide.",
		"incorrect_explanations": ["", "x/d ignores the depth z and produces an orthographic-like result.", "x·z/d inverts the perspective relationship; objects further away would appear larger.", "x−d is a linear offset, not a projective transformation."]
	})

	bank.append({
		"unit": "Unit IV: Back-Face Detection",
		"unit_key": "Unit IV",
		"statement": "Back-face culling determines a polygon face as invisible when the dot product of its surface normal N and the view vector V satisfies:",
		"options": ["N · V < 0  (normal pointing away from camera)", "N · V > 0", "N · V = 1", "N · V ≥ 0"],
		"correct_index": 0,
		"correct_explanation": "If N·V < 0, the face normal points away from the viewer (into the object), meaning it is a back face and can be discarded safely.",
		"incorrect_explanations": ["", "N·V > 0 means the face is frontfacing (normal toward viewer) and must be rendered.", "N·V = 1 means the face is perpendicular to the view ray — it is a front face edge-on case.", "N·V ≥ 0 includes all front-facing and silhouette faces, which are the ones to render, not cull."]
	})

	bank.append({
		"unit": "Unit IV: Z-Buffer Algorithm",
		"unit_key": "Unit IV",
		"statement": "The Z-buffer (depth-buffer) visible surface algorithm initialises the depth buffer to:",
		"options": ["Maximum depth value (z_max = ∞ or far plane)", "Zero", "The depth of the nearest triangle", "−1 (NDC far plane)"],
		"correct_index": 0,
		"correct_explanation": "The depth buffer is initialised to the maximum representable depth value so any rendered polygon depth value will be closer and pass the depth test.",
		"incorrect_explanations": ["", "Initialising to zero means all fragments at z > 0 fail the depth test immediately.", "Initialising to the nearest triangle depth would corrupt the algorithm for other triangles.", "NDC far plane is −1 in OpenGL with reversed depth (depth clamping) — standard initialisation is still the far plane value."]
	})

	bank.append({
		"unit": "Unit IV: 3D Scaling Transformation",
		"unit_key": "Unit IV",
		"statement": "A cube with vertices at (±1, ±1, ±1) is scaled uniformly by factor S = 3. What are the new extents?",
		"options": ["(±3, ±3, ±3)", "(±1, ±1, ±1) — no change", "(±4, ±4, ±4)", "(±9, ±9, ±9)"],
		"correct_index": 0,
		"correct_explanation": "Uniform scaling multiplies all coordinates by S: 1 × 3 = 3. New extents = (±3, ±3, ±3).",
		"incorrect_explanations": ["", "No change would only occur for S = 1.", "(±4) results from adding 3, not multiplying (translation, not scaling).", "(±9) = 3² would result from two successive S=3 scalings, not one."]
	})

	# ---- UNIT V: VR Modelling ----
	bank.append({
		"unit": "Unit V: VR Geometric Modelling",
		"unit_key": "Unit V",
		"statement": "Which of the following best describes Boundary Representation (B-Rep) modelling used for VR objects?",
		"options": ["Defines a solid by its bounding surfaces (faces, edges, vertices) with topological adjacency.", "Voxelises the interior space at a uniform grid resolution.", "Parameterically defines the volume using SDF (signed distance functions).", "Applies recursive triangle subdivision until a smooth limit surface is reached."],
		"correct_index": 0,
		"correct_explanation": "B-Rep models store the boundary (faces/edges/vertices) with their topological relationships — the standard representation for CAD and VR object geometry.",
		"incorrect_explanations": ["", "Voxelisation is a volumetric discrete representation, not B-Rep.", "SDFs are implicit surfaces represented by a scalar field, not boundary topology.", "Recursive subdivision describes Catmull-Clark or Loop subdivision surfaces, not B-Rep."]
	})

	bank.append({
		"unit": "Unit V: Homogeneous Transformation Invariants",
		"unit_key": "Unit V",
		"statement": "In VR kinematics, which geometric property is preserved (invariant) under homogeneous rotation and translation transformations?",
		"options": ["Relative distances between points (rigid body motion)", "Absolute coordinates of every point", "Surface area of all polygons", "Colour and texture of surfaces"],
		"correct_index": 0,
		"correct_explanation": "Rigid body transformations (rotation + translation) preserve Euclidean distances between all pairs of points — the defining invariant of isometric motions.",
		"incorrect_explanations": ["", "Absolute coordinates change with every transformation.", "Surface area is preserved only for isometric deformations — not guaranteed for all homogeneous transforms.", "Colour and texture are surface attributes, not geometric properties of the transformation group."]
	})

	bank.append({
		"unit": "Unit V: Collision Detection",
		"unit_key": "Unit V",
		"statement": "In SublimeGreens, the terrain collision uses ConcavePolygonShape3D built from mesh.get_faces(). What is the primary limitation of using concave shapes for dynamic bodies?",
		"options": ["Concave collision shapes only work correctly as static bodies; dynamic physics simulation requires convex decomposition.", "They consume no memory regardless of polygon count.", "They automatically generate convex hulls for all child meshes.", "Concave shapes can only detect point-to-mesh contacts, not edge-to-edge."],
		"correct_index": 0,
		"correct_explanation": "Physics engines (including Godot's Jolt/Bullet) cannot apply dynamic forces to concave shapes directly due to tunnelling and normal ambiguity — static bodies only.",
		"incorrect_explanations": ["", "Memory usage grows proportionally with the polygon triangle count.", "Convex hull generation is a separate operation, not automatic for ConcavePolygonShape.", "Concave shapes support full mesh-mesh contact detection when used as static colliders."]
	})

	bank.append({
		"unit": "Unit V: Behaviour Modelling",
		"unit_key": "Unit V",
		"statement": "In VR behaviour modelling, which term describes a system where individual agents follow simple local rules (separation, alignment, cohesion) to produce complex emergent group motion?",
		"options": ["Flocking (Boids algorithm)", "Forward kinematics", "Inverse kinematics", "Rigid body dynamics"],
		"correct_index": 0,
		"correct_explanation": "Craig Reynolds' Boids model (1987) produces emergent flocking behaviour from three simple local rules applied to each individual agent.",
		"incorrect_explanations": ["", "Forward kinematics computes end-effector position from known joint angles — a single-chain articulated body.", "Inverse kinematics calculates required joint angles from a desired end-effector position.", "Rigid body dynamics applies Newton's laws of force and torque, not agent-based local rules."]
	})

	bank.append({
		"unit": "Unit V: Object Hierarchies",
		"unit_key": "Unit V",
		"statement": "In a scene graph (such as Godot's SceneTree), when a parent node is rotated, what happens to its children?",
		"options": ["Children inherit the parent transform — they rotate with the parent in world space.", "Children remain in their original world positions.", "Children's local transforms are reset to identity.", "Children independently calculate their own world transforms."],
		"correct_index": 0,
		"correct_explanation": "Scene graph transform inheritance: child world_transform = parent_transform × child_local_transform. Rotating the parent rotates all children in world space.",
		"incorrect_explanations": ["", "Children do not remain fixed in world space unless their global transform is explicitly overridden.", "Child local transforms are preserved; the world-space result changes due to parent's transform change.", "Child world transforms are derived from the product of all ancestor transforms, not independently."]
	})

	return bank
