extends SubViewportContainer
class_name OrthographicMinimap

@export var view_radius: float = 65.0 # World radius in meters captured by orthographic camera
@export var rotate_with_player: bool = true

@onready var sub_viewport: SubViewport = $SubViewport
@onready var minimap_camera: Camera3D = $SubViewport/MinimapCamera
@onready var blip_overlay: Control = $BlipOverlay
@onready var objective_panel: PanelContainer = get_node_or_null("../ObjectivePanel")
@onready var title_label: Label = get_node_or_null("../ObjectivePanel/Margin/VBox/TitleLabel")
@onready var dist_label: Label = get_node_or_null("../ObjectivePanel/Margin/VBox/DistLabel")

var player_node: Node3D = null
var qlm: QuestLocationManager = null

func _ready() -> void:
	# Find player and quest manager
	call_deferred("_setup_nodes")

func _setup_nodes() -> void:
	if not player_node:
		player_node = get_tree().root.find_child("Player", true, false)
	if not qlm:
		qlm = QuestLocationManager.instance
		if not qlm:
			qlm = get_tree().root.find_child("QuestLocationManager", true, false)

	if minimap_camera:
		minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		minimap_camera.size = view_radius * 2.0
		minimap_camera.far = 400.0

func _process(_delta: float) -> void:
	if not player_node or not is_instance_valid(player_node):
		player_node = get_tree().root.find_child("Player", true, false)
		return

	var p_pos = player_node.global_position
	# Position top-down camera high directly above the player
	if minimap_camera:
		minimap_camera.global_position = Vector3(p_pos.x, p_pos.y + 120.0, p_pos.z)
		if rotate_with_player:
			# Player forward vector (-basis.z)
			var fwd = -player_node.global_transform.basis.z
			var yaw = atan2(fwd.x, fwd.z)
			# Top-down camera pointing down (-90 deg pitch) with player yaw
			minimap_camera.rotation = Vector3(-PI / 2.0, yaw, 0.0)
		else:
			minimap_camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)

	if blip_overlay:
		blip_overlay.queue_redraw()

	# Update objective panel text if present
	if qlm and objective_panel and is_instance_valid(player_node):
		var aq = qlm.get_active_quest()
		if aq:
			objective_panel.visible = true
			if title_label:
				title_label.text = aq.title
			if dist_label:
				var d = qlm.get_distance_to_active(player_node.global_position)
				dist_label.text = "🎯 Objective: %.1f m" % d
		else:
			objective_panel.visible = false
