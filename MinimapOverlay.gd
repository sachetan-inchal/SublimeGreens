extends Control
class_name MinimapOverlay

@onready var minimap_container: OrthographicMinimap = get_parent()

func _draw() -> void:
	var w = size.x
	var h = size.y
	var center = Vector2(w * 0.5, h * 0.5)
	var radius = min(w, h) * 0.5 - 6.0

	# 1. Dark circular outer vignette / border
	draw_arc(center, radius + 2.0, 0, TAU, 64, Color(0.05, 0.08, 0.12, 0.95), 4.0)
	draw_arc(center, radius, 0, TAU, 64, Color(0.1, 0.85, 1.0, 0.8), 2.0)
	
	# Concentric subtle radar range rings
	draw_arc(center, radius * 0.5, 0, TAU, 32, Color(0.1, 0.85, 1.0, 0.25), 1.0)
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(0.1, 0.85, 1.0, 0.15), 1.0)
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(0.1, 0.85, 1.0, 0.15), 1.0)

	if not minimap_container or not minimap_container.player_node or not is_instance_valid(minimap_container.player_node):
		return

	var p = minimap_container.player_node
	var p_pos = p.global_position
	var fwd = -p.global_transform.basis.z
	var player_yaw = atan2(fwd.x, fwd.z)
	var view_r = minimap_container.view_radius

	# 2. North Compass Indicator
	var north_angle = -player_yaw - PI / 2.0 if minimap_container.rotate_with_player else -PI / 2.0
	var north_pos = center + Vector2(cos(north_angle), sin(north_angle)) * (radius - 10.0)
	draw_circle(north_pos, 7.0, Color(0.1, 0.1, 0.15, 0.8))
	draw_string(ThemeDB.fallback_font, north_pos + Vector2(-4, 4), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1.0, 0.25, 0.25, 1.0))

	# 3. Quest & Objective Blips
	var qlm = minimap_container.qlm
	if not qlm:
		qlm = QuestLocationManager.instance
	if qlm:
		var active_q = qlm.get_active_quest()
		if active_q:
			var world_diff = active_q.world_position - p_pos
			var rel_map = _world_to_map(world_diff, player_yaw, view_r, radius)
			var dest_pt = center + rel_map
			# Clamp waypoint line to radar radius
			var line_end = dest_pt
			if (dest_pt - center).length() > radius:
				line_end = center + (dest_pt - center).normalized() * radius
			draw_line(center, line_end, Color(1.0, 0.84, 0.0, 0.55), 2.0, true)

		for qid in qlm.quests:
			var quest = qlm.quests[qid]
			var w_diff = quest.world_position - p_pos
			var rel = _world_to_map(w_diff, player_yaw, view_r, radius)
			var m_pos = center + rel
			var dist = rel.length()
			if dist > radius - 8.0:
				m_pos = center + rel.normalized() * (radius - 8.0)

			var col = QuestMarker.get_status_color(quest.status)
			if qid == qlm.active_quest_id:
				draw_circle(m_pos, 7.5, Color(1.0, 0.85, 0.0, 0.4))
				draw_circle(m_pos, 4.5, col)
				draw_arc(m_pos, 7.5, 0, TAU, 16, Color.WHITE, 1.5)
			else:
				draw_circle(m_pos, 4.0, col)
				draw_arc(m_pos, 4.0, 0, TAU, 16, Color(0, 0, 0, 0.8), 1.0)

	# 4. Player Indicator in Center (Pointed 180° opposite)
	var arrow_sz = 8.0
	var tip = center + Vector2(0, arrow_sz)
	var left = center + Vector2(-arrow_sz * 0.7, -arrow_sz * 0.7)
	var right = center + Vector2(arrow_sz * 0.7, -arrow_sz * 0.7)
	var notch = center + Vector2(0, -arrow_sz * 0.25)
	var poly = PackedVector2Array([tip, left, notch, right])
	draw_colored_polygon(poly, Color(0.1, 0.95, 1.0))
	draw_polyline(PackedVector2Array([tip, left, notch, right, tip]), Color(0.0, 0.2, 0.3), 1.5)

func _world_to_map(world_delta: Vector3, player_yaw: float, view_radius: float, map_radius: float) -> Vector2:
	var scale_factor = map_radius / view_radius
	var dx = world_delta.x * scale_factor
	var dy = world_delta.z * scale_factor # In Godot Z is south / down in 2D

	if minimap_container.rotate_with_player:
		# Rotate opposite to player yaw so forward (+fwd) is up (-Y)
		var cos_y = cos(-player_yaw)
		var sin_y = sin(-player_yaw)
		var rx = dx * cos_y - dy * sin_y
		var ry = dx * sin_y + dy * cos_y
		return Vector2(rx, ry)
	else:
		return Vector2(dx, dy)
