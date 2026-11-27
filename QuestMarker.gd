extends RefCounted
class_name QuestMarker

enum QuestStatus {
	LOCKED,       # Grey
	AVAILABLE,    # Gold
	COMPLETED,    # Green
	BONUS,        # Purple
	FINAL_TARGET  # Cyan / Glowing destination
}

var id: String = ""
var title: String = ""
var syllabus_unit: String = ""
var world_position: Vector3 = Vector3.ZERO
var status: QuestStatus = QuestStatus.AVAILABLE
var is_bonus: bool = false
var associated_node: Node = null

# Colors as specified:
# Gold: Available, Green: Completed, Grey: Locked, Purple: Bonus, Cyan: Player
static func get_status_color(st: QuestStatus) -> Color:
	match st:
		QuestStatus.AVAILABLE:
			return Color(1.0, 0.84, 0.0)      # Gold
		QuestStatus.COMPLETED:
			return Color(0.2, 0.9, 0.25)     # Green
		QuestStatus.LOCKED:
			return Color(0.55, 0.55, 0.6)     # Grey
		QuestStatus.BONUS:
			return Color(0.75, 0.2, 0.95)     # Purple
		QuestStatus.FINAL_TARGET:
			return Color(0.1, 0.95, 1.0)      # Cyan Magic
		_:
			return Color.WHITE
