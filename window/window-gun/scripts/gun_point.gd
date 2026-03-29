extends Control

var speed = 100
@onready var point: TextureButton = $Point

var is_clone: bool = false 


@export var prevent_overlap_count: int = 3 
@export var prevent_overlap_radius: float = 200.0 

@export var min_x: float = 200.0
@export var max_x: float = 1400.0
@export var min_y: float = 200.0
@export var max_y: float = 700.0

# 최근에 생성된 노트들의 위치를 저장할 배열
var recent_positions: Array[Vector2] = []

func _ready():
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if not is_clone:
		self.hide()
	
	if point:
		point.pressed.connect(_on_point_pressed)

func rng_point():
	var clone = self.duplicate()
	clone.is_clone = true
	
	var new_pos = Vector2.ZERO
	var is_valid_pos = false
	var max_attempts = 50 # 🌟 무한 루프 방지용 (공간이 부족할 때 게임이 멈추는 것 방지)
	
	# 🌟 겹치지 않는 자리를 찾을 때까지 반복 (최대 50번 시도)
	for attempt in range(max_attempts):
		new_pos.x = randf_range(min_x, max_x)
		new_pos.y = randf_range(min_y, max_y)
		
		is_valid_pos = true
		
		# 기억해둔 최근 위치들과 거리 비교
		for past_pos in recent_positions:
			# 새로 뽑은 좌표와 과거 좌표의 거리가 설정한 범위보다 가깝다면
			if new_pos.distance_to(past_pos) < prevent_overlap_radius:
				is_valid_pos = false
				break # 겹치므로 내부 반복문을 멈추고 새로운 좌표를 다시 뽑습니다.
				
		# 모든 과거 좌표와 비교했는데도 겹치지 않는다면 (is_valid_pos == true)
		if is_valid_pos:
			break # 성공! 자리찾기 반복문을 완전히 탈출합니다.
			
	# 최종 결정된 위치를 복제본에 적용
	clone.global_position = new_pos
	
	# 🌟 방금 찾은 안전한 위치를 기록에 추가
	recent_positions.append(new_pos)
	
	# 기록된 위치의 개수가 설정한 개수(prevent_overlap_count)를 넘어가면 가장 오래된 기록 삭제
	if recent_positions.size() > prevent_overlap_count:
		recent_positions.pop_front()
	
	clone.visible = true 
	get_parent().call_deferred("add_child", clone)
	
func _on_point_pressed():
	self.queue_free()
	Global.score += 1
