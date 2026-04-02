extends Control

var judgment_time: float = 1.0 
var speed = 100
@onready var point: TextureButton = $Point

var is_clone: bool = false 

@export var prevent_overlap_count: int = 3 
@export var prevent_overlap_radius: float = 200.0 

@export var min_x: float = 200.0
@export var max_x: float = 1400.0
@export var min_y: float = 200.0
@export var max_y: float = 700.0

static var recent_positions: Array[Vector2] = []

func _ready():
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if not is_clone:
		self.hide() # 원본은 숨김 처리
	
	if point and not point.pressed.is_connected(_on_point_pressed):
		point.pressed.connect(_on_point_pressed)

func rng_point():
	var clone = self.duplicate()
	var new_pos = Vector2.ZERO
	var is_valid_pos = false
	var max_attempts = 50 
	
	for attempt in range(max_attempts):
		new_pos.x = randf_range(min_x, max_x)
		new_pos.y = randf_range(min_y, max_y)
		is_valid_pos = true
		for past_pos in recent_positions:
			if new_pos.distance_to(past_pos) < prevent_overlap_radius:
				is_valid_pos = false
				break 
		if is_valid_pos:
			break 
			
	recent_positions.append(new_pos)
	if recent_positions.size() > prevent_overlap_count:
		recent_positions.pop_front()
	
	# 🌟 1. 씬 트리에 먼저 안전하게 추가합니다.
	get_parent().call_deferred("add_child", clone)
	
	# 🌟 2. 씬 트리에 추가된 후, 초기화 함수를 지연 호출하여 타이머와 애니메이션을 실행합니다.
	clone.call_deferred("activate_clone", new_pos)

# 🌟 복제본이 트리에 추가된 후 부모가 호출해주는 셋업 함수
func activate_clone(new_pos: Vector2):
	is_clone = true
	global_position = new_pos
	self.show() # 원본에서 복제된 '숨김' 상태를 해제
	
	# 자식 노드 중 원(TextureRect)을 찾아 애니메이션 강제 시작
	# (자식 노드에 start_shrinking 함수가 있다면 실행합니다)
	for child in get_children():
		if child.has_method("start_shrinking"):
			child.start_shrinking()
			
	# 타이머 시작: judgment_time + 0.2초 후 삭제
	get_tree().create_timer(judgment_time + 0.3).timeout.connect(_on_time_out)

func _on_time_out():
	if is_instance_valid(self):
		queue_free()
		Global.score -= 70 # 시간 초과 시 삭제

func _on_point_pressed():
	if not is_clone: return # 원본은 클릭 무시
	Global.score += 100
	self.queue_free()
	
