extends Control

@export_category("Timing & Score Settings")
@export var judgment_time: float = 1.0       # 기본 대기 시간
@export var perfect_margin: float = 0.3      # 원이 사라지기 전 100점을 받는 시간 (0.3초)
@export var penalty_score: int = -70         # 시간 초과 시 감점

@export_category("Spawn Settings")
@export var prevent_overlap_count: int = 3 
@export var prevent_overlap_radius: float = 200.0 
@export var min_x: float = 200.0 
@export var max_x: float = 1400.0
@export var min_y: float = 200.0
@export var max_y: float = 700.0

var speed = 100
var is_clone: bool = false 
var spawn_time_msec: int = 0 

@onready var point: TextureButton = $Point

static var recent_positions: Array[Vector2] = []
# 🌟 현재 화면에 존재하는 노트들을 생성 순서대로 저장하는 배열
static var active_notes: Array[Control] = [] 

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
	
	get_parent().call_deferred("add_child", clone)
	clone.call_deferred("activate_clone", new_pos)

func activate_clone(new_pos: Vector2):
	is_clone = true
	global_position = new_pos
	self.show() 
	
	spawn_time_msec = Time.get_ticks_msec()
	
	# 🌟 생성된 노트를 활성화 배열에 추가하고 시각적 효과 업데이트
	active_notes.append(self)
	update_target_visuals()
	
	for child in get_children():
		if child.has_method("start_shrinking"):
			child.start_shrinking()
			
	var total_life_time = judgment_time + perfect_margin
	get_tree().create_timer(total_life_time).timeout.connect(_on_time_out)

func _on_time_out():
	if is_instance_valid(self):
		Global.score += penalty_score
		Global.combo = 0
		
		# 🌟 시간 초과된 노트는 배열에서 제거 후 다음 타겟 갱신
		active_notes.erase(self)
		update_target_visuals()
		queue_free()

func _on_point_pressed():
	if not is_clone: return 
	
	# 안전장치: 이미 삭제 처리된 노드가 배열에 섞여있다면 필터링
	active_notes = active_notes.filter(func(note): return is_instance_valid(note))
	
	var earned_score: int = 0
	
	# 🌟 순서 판정 로직
	if active_notes.size() > 0 and active_notes[0] == self:
		# 1. 올바른 순서로 눌렀을 때 (배열의 가장 첫 번째 요소일 때)
		Global.combo += 1
		
		var time_alive: float = (Time.get_ticks_msec() - spawn_time_msec) / 1000.0
		
		if time_alive >= judgment_time:
			earned_score = 100
		else:
			var step: int = int(time_alive / (judgment_time / 5.0))
			earned_score = 50 + (step * 10)
	else:
		# 2. 잘못된 순서로 눌렀을 때 (배열의 첫 번째가 아닌 것을 눌렀을 때)
		earned_score = 50
	
	# 점수 추가, 배열에서 자기 자신 제거, 시각적 효과 갱신 후 노드 삭제
	Global.score += earned_score
	active_notes.erase(self)
	update_target_visuals()
	self.queue_free()

# 🌟 남은 노트들의 시각적 힌트를 업데이트하는 함수
func update_target_visuals():
	active_notes = active_notes.filter(func(note): return is_instance_valid(note))
	
	for i in range(active_notes.size()):
		var note = active_notes[i]
		if i == 0:
			# 눌러야 할 1순위 타겟 (원래 색상, 불투명 100%)
			note.modulate = Color(1.0, 1.0, 1.0, 1.0) 
		else:
			# 순서가 아직 오지 않은 대기 노트들 (어둡고 살짝 투명하게)
			note.modulate = Color(0.5, 0.5, 0.5, 0.7)
