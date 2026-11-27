extends CanvasLayer
class_name QuestMapUI

@onready var minimap_container: Control = $MinimapContainer
@onready var quest_map_radar: QuestMap = $MinimapContainer/QuestMap
@onready var objective_panel: PanelContainer = $MinimapContainer/ObjectivePanel
@onready var objective_title: Label = $MinimapContainer/ObjectivePanel/Margin/VBox/TitleLabel
@onready var objective_dist: Label = $MinimapContainer/ObjectivePanel/Margin/VBox/DistLabel

@onready var expanded_map_modal: PanelContainer = $ExpandedMapModal
@onready var quest_list_container: VBoxContainer = $ExpandedMapModal/Margin/HBox/Sidebar/Scroll/QuestList
@onready var map_canvas: Control = $ExpandedMapModal/Margin/HBox/MapCanvas
@onready var close_btn: Button = $ExpandedMapModal/Margin/HBox/Sidebar/CloseButton

var player_ref: Node3D = null
var qlm: QuestLocationManager = null
var is_expanded_open: bool = false

func _ready() -> void:
	expanded_map_modal.visible = false
	close_btn.pressed.connect(toggle_expanded_map)

	call_deferred("_setup_references")

func _setup_references() -> void:
	if not player_ref:
		player_ref = get_tree().root.find_child("Player", true, false)
	if not qlm:
		qlm = QuestLocationManager.instance
		if not qlm:
			qlm = QuestLocationManager.new()
			qlm.name = "QuestLocationManager"
			get_tree().root.add_child(qlm)

	if qlm and player_ref:
		qlm.set_player(player_ref)

	if quest_map_radar and player_ref and qlm:
		quest_map_radar.setup(player_ref, qlm)

	map_canvas.draw.connect(_on_map_canvas_draw)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			toggle_expanded_map()
		elif event.keycode == KEY_ESCAPE and is_expanded_open:
			toggle_expanded_map()

func toggle_expanded_map() -> void:
	is_expanded_open = not is_expanded_open
	expanded_map_modal.visible = is_expanded_open

	if is_expanded_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_quest_list()
		map_canvas.queue_redraw()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(_delta: float) -> void:
	if not player_ref or not qlm:
		return

	# Update Minimap HUD Objective details
	var aq = qlm.get_active_quest()
	if aq:
		objective_panel.visible = true
		objective_title.text = aq.title
		var dist = qlm.get_distance_to_active(player_ref.global_position)
		objective_dist.text = "🎯 Objective: %.1f m" % dist
	else:
		objective_panel.visible = false

	if is_expanded_open:
		map_canvas.queue_redraw()

func _refresh_quest_list() -> void:
	if not qlm:
		return

	for c in quest_list_container.get_children():
		c.queue_free()

	for qid in qlm.quests:
		var q = qlm.quests[qid]
		var btn = Button.new()
		var col_hex = QuestMarker.get_status_color(q.status).to_html(false)
		btn.text = "[ %s ] %s" % [q.syllabus_unit.split(":")[0], q.title]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_color_override("font_color", QuestMarker.get_status_color(q.status))

		var quest_id_copy = qid
		btn.pressed.connect(func():
			qlm.set_active_quest(quest_id_copy)
			_refresh_quest_list()
			map_canvas.queue_redraw()
		)
		quest_list_container.add_child(btn)

func _on_map_canvas_draw() -> void:
	var canvas_size = map_canvas.size
	var center = canvas_size / 2.0

	# Dark grid background for tactical GTA full map look
	map_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.04, 0.06, 0.08, 0.95))

	# Coordinate grid lines
	var step = 50.0
	for x in range(0, int(canvas_size.x), int(step)):
		map_canvas.draw_line(Vector2(x, 0), Vector2(x, canvas_size.y), Color(0.1, 0.2, 0.25, 0.4), 1.0)
	for y in range(0, int(canvas_size.y), int(step)):
		map_canvas.draw_line(Vector2(0, y), Vector2(canvas_size.x, y), Color(0.1, 0.2, 0.25, 0.4), 1.0)

	if not player_ref or not qlm:
		return

	# World boundaries mapping:
	# Assume comfortable 250m radius view centered around player
	var map_world_scale = 1.6 # pixels per world unit

	var p_pos = player_ref.global_position

	# Draw destination guide line
	var aq = qlm.get_active_quest()
	if aq:
		var dest_2d = center + Vector2(aq.world_position.x - p_pos.x, aq.world_position.z - p_pos.z) * map_world_scale
		map_canvas.draw_line(center, dest_2d, Color(1.0, 0.84, 0.0, 0.7), 2.0, true)

	# Draw all quest checkpoints
	for qid in qlm.quests:
		var q = qlm.quests[qid]
		var marker_2d = center + Vector2(q.world_position.x - p_pos.x, q.world_position.z - p_pos.z) * map_world_scale

		if Rect2(Vector2.ZERO, canvas_size).has_point(marker_2d):
			var m_color = QuestMarker.get_status_color(q.status)
			if qid == qlm.active_quest_id:
				map_canvas.draw_circle(marker_2d, 10.0, Color(1.0, 0.84, 0.0, 0.35))
				map_canvas.draw_circle(marker_2d, 6.0, m_color)
				map_canvas.draw_arc(marker_2d, 10.0, 0, TAU, 24, Color.WHITE, 2.0)
			else:
				map_canvas.draw_circle(marker_2d, 5.0, m_color)
				map_canvas.draw_arc(marker_2d, 5.0, 0, TAU, 16, Color(0, 0, 0, 0.8), 1.0)

			# Label with title
			map_canvas.draw_string(ThemeDB.fallback_font, marker_2d + Vector2(9, 4), q.title.split(":")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, m_color)

	# Draw Player marker at center (Cyan arrow oriented to player yaw)
	var p_fwd = -player_ref.global_transform.basis.z
	var angle = atan2(p_fwd.x, -p_fwd.z) # Screen 2D heading

	var arrow_sz = 10.0
	var tip = center + Vector2(sin(angle), -cos(angle)) * arrow_sz
	var left = center + Vector2(sin(angle + 2.4), -cos(angle + 2.4)) * (arrow_sz * 0.8)
	var right = center + Vector2(sin(angle - 2.4), -cos(angle - 2.4)) * (arrow_sz * 0.8)

	map_canvas.draw_colored_polygon(PackedVector2Array([tip, left, center, right]), Color(0.1, 0.9, 1.0))
	map_canvas.draw_polyline(PackedVector2Array([tip, left, center, right, tip]), Color.WHITE, 1.5)
