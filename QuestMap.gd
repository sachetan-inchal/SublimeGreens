extends Control
class_name QuestMap

# Radius of radar on screen in pixels
@export var radar_radius: float = 95.0
# World units visible from center to border of circular radar
@export var radar_world_range: float = 120.0

var player_node: Node3D = null
var qlm: QuestLocationManager = null

func setup(player: Node3D, manager: QuestLocationManager) -> void:
	player_node = player
	qlm = manager
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center = Vector2(radar_radius + 15.0, radar_radius + 15.0)

	# 1. Dark translucent radar background (GTA style)
	draw_circle(center, radar_radius + 4.0, Color(0.05, 0.05, 0.08, 0.85))
	draw_circle(center, radar_radius, Color(0.08, 0.12, 0.15, 0.75))

	# Subtle range ring grid
	draw_arc(center, radar_radius * 0.5, 0, TAU, 32, Color(0.2, 0.4, 0.5, 0.3), 1.0)
	draw_arc(center, radar_radius, 0, TAU, 48, Color(0.2, 0.6, 0.8, 0.8), 2.0)

	if not player_node or not is_instance_valid(player_node):
		return

	var p_pos = player_node.global_position
	# In Godot, forward is -basis.z. Player yaw in radians:
	var p_fwd = -player_node.global_transform.basis.z
	var player_yaw = atan2(p_fwd.x, p_fwd.z)

	# 2. Draw North Indicator on rim (GTA V compass)
	# World North is along -Z. In radar coords relative to player yaw:
	var north_angle_rel = -player_yaw - PI/2.0
	var north_pos = center + Vector2(cos(north_angle_rel), sin(north_angle_rel)) * (radar_radius - 8.0)
	draw_string(ThemeDB.fallback_font, north_pos + Vector2(-4, 4), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(1.0, 0.25, 0.25, 1.0))

	# 3. Draw Waypoint Route Line if an active quest exists
	if qlm:
		var active_quest = qlm.get_active_quest()
		if active_quest:
			var world_delta = active_quest.world_position - p_pos
			var rel_map_pos = _world_to_radar(world_delta, player_yaw)
			var dest_pt = center + rel_map_pos
			# Clamp line to circle edge
			var line_end = dest_pt
			if (dest_pt - center).length() > radar_radius:
				line_end = center + (dest_pt - center).normalized() * radar_radius
			# Draw dashed/translucent route line
			draw_line(center, line_end, Color(1.0, 0.84, 0.0, 0.5), 2.0, true)

		# 4. Draw Quest Checkpoint Markers
		for qid in qlm.quests:
			var quest = qlm.quests[qid]
			var w_delta = quest.world_position - p_pos
			var rel_map_pos = _world_to_radar(w_delta, player_yaw)
			var dist = rel_map_pos.length()

			var marker_pos = center + rel_map_pos
			var is_edge_clamped = false

			# Clamp to edge if beyond radar range (like GTA radar blips)
			if dist > radar_radius - 8.0:
				marker_pos = center + rel_map_pos.normalized() * (radar_radius - 8.0)
				is_edge_clamped = true

			var m_color = QuestMarker.get_status_color(quest.status)

			# If active quest, draw pulsing outer ring
			if qid == qlm.active_quest_id:
				draw_circle(marker_pos, 7.0, Color(1.0, 0.84, 0.0, 0.4))
				draw_circle(marker_pos, 4.5, m_color)
				draw_arc(marker_pos, 7.0, 0, TAU, 16, Color.WHITE, 1.5)
			else:
				draw_circle(marker_pos, 4.0, m_color)
				draw_arc(marker_pos, 4.0, 0, TAU, 16, Color(0, 0, 0, 0.8), 1.0)

	# 5. Draw Player Arrow at Center (Rotated 180° opposite)
	var arrow_size = 7.0
	var tip = center + Vector2(0, arrow_size)
	var left = center + Vector2(-arrow_size * 0.7, -arrow_size * 0.7)
	var right = center + Vector2(arrow_size * 0.7, -arrow_size * 0.7)
	var inner = center + Vector2(0, -arrow_size * 0.3)

	var poly = PackedVector2Array([tip, left, inner, right])
	draw_colored_polygon(poly, Color(0.1, 0.9, 1.0, 1.0)) # Cyan
	draw_polyline(PackedVector2Array([tip, left, inner, right, tip]), Color(0.0, 0.2, 0.3, 1.0), 1.5)

func _world_to_radar(world_delta: Vector3, player_yaw: float) -> Vector2:
	# World coordinates: X is East, Z is South.
	# Scale delta to radar radius
	var scale_factor = radar_radius / radar_world_range
	var dx = world_delta.x * scale_factor
	var dy = world_delta.z * scale_factor # Godot world Z corresponds to screen Y

	# Rotate relative to player heading so forward is always UP on radar
	var angle = -player_yaw - PI/2.0
	var rx = dx * cos(angle) - dy * sin(angle)
	var ry = dx * sin(angle) + dy * cos(angle)

	return Vector2(rx, ry)
