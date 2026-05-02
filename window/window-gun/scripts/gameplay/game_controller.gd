extends Control

const NORMAL_NOTE_MODE := "normal"
const MOVING_NOTE_MODE := "moving"

@onready var target_spawner: Control = $TargetNoteSpawner


func _ready() -> void:
	Global.reset_run()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("1"):
		_spawn_note(NORMAL_NOTE_MODE)
	elif event.is_action_pressed("2"):
		_spawn_note(MOVING_NOTE_MODE)
	elif event.is_action_pressed("3"):
		# 원하는 지정 좌표를 설정합니다. (예: X=600, Y=400)
		var custom_position := Vector2(2000.0, 1000.0) 
		# 모드(정상 또는 이동)와 지정한 좌표를 함께 전달합니다.
		_spawn_note(NORMAL_NOTE_MODE, custom_position) 


# target_pos 매개변수를 추가하고 기본값을 null로 설정합니다. (기존 1, 2번 입력과 호환 유지)
func _spawn_note(mode: String, target_pos: Variant = null) -> void:
	if target_spawner and target_spawner.has_method("spawn_node"):
		# target_spawner(자식 노드)의 spawn_node 함수에 모드와 좌표를 모두 넘겨줍니다.
		target_spawner.spawn_node(mode, target_pos)
