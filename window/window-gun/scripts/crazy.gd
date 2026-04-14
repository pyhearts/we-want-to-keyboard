extends Control

# 배경 노드 참조
@onready var background_rect = $"."

# 최대 기울기 각도 (도)
@export var max_tilt_angle : float = 2.0
# 부드러운 움직임을 위한 속도
@export var lerp_speed : float = 5.0

func _process(delta):
	# 1. 마우스 위치 가져오기
	var mouse_pos = get_global_mouse_position()
	# 2. 화면 중앙 좌표 계산
	var screen_size = get_viewport_rect().size
	var screen_center = screen_size / 2.0
	
	# 3. 중앙으로부터의 거리 정규화 (-1.0 ~ 1.0)
	# 중앙은 (0,0), 우상단은 (1,-1), 좌하단은 (-1,1)에 가까워집니다.
	var normalized_dist = (mouse_pos - screen_center) / screen_center
	
	# 4. 기울기 목표값 계산 (마우스를 따라감)
	# X축 거리는 Y축 회전에, Y축 거리는 X축 회전에 영향을 줍니다 (반대).
	# 단, 고도 2D에서는 rotation_degrees가 Z축 회전(평면 회전)이므로, 
	# 간단한 효과를 위해 하나의 값으로 통합하여 사용합니다.
	# 더 깊은 입체감을 원한다면 3D Perspective 카메라를 사용해야 합니다.
	
	# 여기서는 간단하게 마우스의 X 위치에 따라 전체를 약간 회전시키는 방식을 사용합니다.
	var target_rotation = normalized_dist.x * max_tilt_angle
	
	# 5. 부드럽게 이동시킴 (Lerp)
	background_rect.rotation_degrees = lerp(background_rect.rotation_degrees, target_rotation, lerp_speed * delta)
	
	# (선택 사항) 입체감을 더하기 위해 약간의 이동 효과 추가
	# var target_offset = normalized_dist * -20.0 # 반대 방향으로 약간 이동
	# background_rect.position = lerp(background_rect.position, target_offset, lerp_speed * delta)
