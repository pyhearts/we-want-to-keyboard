extends TextureRect

var judgment_time: float = 0.8

func _ready() -> void:
	# 기본 크기를 목표 크기인 1080으로 미리 맞춰둡니다.
	size = Vector2(1080, 1080)
	
	# 중심을 피벗으로 설정
	pivot_offset = size / 2.0
	
	# 시작할 때 크기(scale)를 약 1.85배로 뻥튀기합니다 (1080 * 1.85... = 약 2000)
	var start_scale_ratio = 2500.0 / 1080.0
	scale = Vector2(start_scale_ratio, start_scale_ratio)
	
	# judgment_time 동안 scale을 원래 크기(1, 1)로 줄어들게 합니다.
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), judgment_time)
