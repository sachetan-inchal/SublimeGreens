extends Node
class_name QuestLocationManager

signal quest_status_changed(quest_id: String, new_status: QuestMarker.QuestStatus)
signal active_quest_changed(quest_id: String)
signal quests_updated()
signal all_units_complete()   # Fired once when all non-bonus core quests are COMPLETED

# Which quest IDs count as the five core unit milestones (bonus excluded)
const CORE_UNIT_QUEST_IDS: Array[String] = [
	"m1_trees",      # Unit I
	"m3_terrain",    # Unit I & III
	"m5_multimesh",  # Unit I (Display Lists)
	"m2_camera",     # Unit II & IV
	"m4_aabb_lod",   # Unit IV & V
]

var _all_units_complete_fired: bool = false

static var instance: QuestLocationManager = null

# Dictionary of quest_id -> QuestMarker
var quests: Dictionary = {}
var active_quest_id: String = ""
var player_ref: Node3D = null

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	# Scan for existing MilestoneMarker nodes in scene
	call_deferred("_discover_milestones")

func set_player(p: Node3D) -> void:
	player_ref = p

func _discover_milestones() -> void:
	var markers = get_tree().get_nodes_in_group("milestone_markers")
	if markers.is_empty():
		# Search by class or type in root
		var found = _find_all_milestone_markers(get_tree().root)
		for m in found:
			register_milestone(m)
	else:
		for m in markers:
			register_milestone(m)

	# Register default unit checkpoints across the procedural world if not already present
	_ensure_default_cgvr_checkpoints()
	quests_updated.emit()

func _find_all_milestone_markers(node: Node) -> Array[Node]:
	var res: Array[Node] = []
	if node is MilestoneMarker or node.name.begins_with("Milestone_"):
		res.append(node)
	for child in node.get_children():
		res.append_array(_find_all_milestone_markers(child))
	return res

func register_milestone(marker_node: Node) -> void:
	if not marker_node:
		return
	var qid = marker_node.get("milestone_id")
	if not qid:
		qid = marker_node.name

	var qm = QuestMarker.new()
	qm.id = qid
	qm.title = marker_node.get("title") if marker_node.get("title") else marker_node.name
	qm.syllabus_unit = marker_node.get("syllabus_unit") if marker_node.get("syllabus_unit") else "CGVR Curriculum"
	qm.world_position = marker_node.global_position
	qm.status = QuestMarker.QuestStatus.AVAILABLE
	qm.associated_node = marker_node
	quests[qid] = qm

	# Set default active if none selected
	if active_quest_id == "":
		active_quest_id = qid

func _ensure_default_cgvr_checkpoints() -> void:
	# Defined syllabus locations placed strategically within generated chunks
	var default_list = [
		{
			"id": "m1_trees",
			"title": "Unit I: Procedural Cuboid Tree",
			"unit": "Unit I: Primitives & Attributes",
			"pos": Vector3(5.0, 0.0, -6.0),
			"status": QuestMarker.QuestStatus.AVAILABLE,
			"bonus": false
		},
		{
			"id": "m3_terrain",
			"title": "Unit I & III: Terrain Normals & Shading",
			"unit": "Unit I & III: Surface Normals",
			"pos": Vector3(-8.0, 0.0, -4.0),
			"status": QuestMarker.QuestStatus.AVAILABLE,
			"bonus": false
		},
		{
			"id": "m5_multimesh",
			"title": "Unit I: MultiMesh Hardware Instancing",
			"unit": "Unit I: Display Lists & Batching",
			"pos": Vector3(0.0, 0.0, -14.0),
			"status": QuestMarker.QuestStatus.AVAILABLE,
			"bonus": false
		},
		{
			"id": "m2_camera",
			"title": "Unit II: Hierarchical Viewing & Euler Clamping",
			"unit": "Unit II: Event-Driven Input",
			"pos": Vector3(18.0, 0.0, 15.0),
			"status": QuestMarker.QuestStatus.AVAILABLE,
			"bonus": false
		},
		{
			"id": "m4_aabb_lod",
			"title": "Unit IV: AABB Distance & Visible Surface LOD",
			"unit": "Unit IV: 3-D Bounding Volumes & Culling",
			"pos": Vector3(-25.0, 0.0, 20.0),
			"status": QuestMarker.QuestStatus.LOCKED,
			"bonus": false
		},
		{
			"id": "m_final_stone",
			"title": "Ancient Stone: Final Assessment",
			"unit": "Units I - V: Comprehensive Assessment",
			"pos": Vector3(35.0, 44.5, 30.0),
			"status": QuestMarker.QuestStatus.LOCKED,
			"bonus": false
		},
		{
			"id": "m_bonus_treasure",
			"title": "Hidden Artifact: Discrete Sierpinski Gasket",
			"unit": "Unit I: Fractal Primitives (Bonus)",
			"pos": Vector3(32.0, 0.0, -28.0),
			"status": QuestMarker.QuestStatus.BONUS,
			"bonus": true
		}
	]

	for data in default_list:
		if not quests.has(data["id"]):
			var qm = QuestMarker.new()
			qm.id = data["id"]
			qm.title = data["title"]
			qm.syllabus_unit = data["unit"]
			qm.world_position = data["pos"]
			qm.status = data["status"]
			qm.is_bonus = data["bonus"]
			_snap_marker_to_terrain(qm)
			quests[data["id"]] = qm

	if active_quest_id == "" and not quests.is_empty():
		active_quest_id = quests.keys()[0]

func _snap_marker_to_terrain(marker: QuestMarker) -> void:
	if not is_inside_tree():
		return
	var space_state = get_tree().root.get_world_3d().direct_space_state
	if not space_state:
		return
	var ray_origin = Vector3(marker.world_position.x, 300.0, marker.world_position.z)
	var ray_end = Vector3(marker.world_position.x, -100.0, marker.world_position.z)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)
	if result:
		marker.world_position.y = result.position.y

func set_quest_status(qid: String, new_status: QuestMarker.QuestStatus) -> void:
	if quests.has(qid):
		quests[qid].status = new_status
		quest_status_changed.emit(qid, new_status)
		quests_updated.emit()
		_check_all_units_complete()

func _check_all_units_complete() -> void:
	if _all_units_complete_fired:
		return
	for core_id in CORE_UNIT_QUEST_IDS:
		if not quests.has(core_id):
			return
		if quests[core_id].status != QuestMarker.QuestStatus.COMPLETED:
			return
	# All five core milestones are COMPLETED
	_all_units_complete_fired = true
	if quests.has("m_final_stone"):
		quests["m_final_stone"].status = QuestMarker.QuestStatus.FINAL_TARGET
		set_active_quest("m_final_stone")
	all_units_complete.emit()

func set_active_quest(qid: String) -> void:
	if quests.has(qid):
		active_quest_id = qid
		active_quest_changed.emit(qid)
		quests_updated.emit()

func get_active_quest() -> QuestMarker:
	if quests.has(active_quest_id):
		return quests[active_quest_id]
	return null

func get_distance_to_active(player_pos: Vector3) -> float:
	var aq = get_active_quest()
	if aq:
		var diff = aq.world_position - player_pos
		return Vector2(diff.x, diff.z).length()
	return 0.0
