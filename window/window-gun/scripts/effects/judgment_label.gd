extends Label

@export var duration: float = 0.5
@export var drift_distance: float = 60.0

var active_tween: Tween


func _ready() -> void:
	# 피벗 중심점 자동 설정
	pivot_offset = size / 2.0


func start(judgment_type: String) -> void:
	# 기존 트윈 정리
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	# 판정 등급별 텍스트, 색상 및 애니메이션 커스텀
	var final_color = Color.WHITE
	var angle_offset = randf_range(-10.0, 10.0) # 살짝 삐딱하게 회전
	var start_scale = Vector2(0.4, 0.4)
	var peak_scale = Vector2(1.3, 1.3)
	var end_scale = Vector2(1.0, 1.0)
	var direction_multiplier = -1.0 # 기본 위로 상승

	match judgment_type.to_lower():
		"perfect":
			text = "PERFECT"
			final_color = Color(0.0, 1.0, 0.9, 1.0) # 강렬한 네온 민트/하늘
			peak_scale = Vector2(1.4, 1.4)
			# 더 강한 윤곽선
			add_theme_constant_override("outline_size", 12)
			add_theme_color_override("font_outline_color", Color(0.0, 0.3, 0.5, 0.8))
		"great":
			text = "GREAT"
			final_color = Color(0.2, 1.0, 0.3, 1.0) # 밝은 네온 에메랄드
			add_theme_constant_override("outline_size", 10)
			add_theme_color_override("font_outline_color", Color(0.05, 0.4, 0.1, 0.8))
		"good":
			text = "GOOD"
			final_color = Color(0.8, 0.3, 1.0, 1.0) # 네온 퍼플
			add_theme_constant_override("outline_size", 8)
			add_theme_color_override("font_outline_color", Color(0.3, 0.0, 0.4, 0.8))
		"miss":
			text = "MISS"
			final_color = Color(1.0, 0.15, 0.15, 1.0) # 강렬한 네온 레드
			direction_multiplier = 1.2 # 미스는 아래로 툭 떨어지는 처진 효과
			peak_scale = Vector2(1.1, 1.1)
			add_theme_constant_override("outline_size", 8)
			add_theme_color_override("font_outline_color", Color(0.4, 0.0, 0.0, 0.8))

	add_theme_color_override("font_color", final_color)
	rotation_degrees = angle_offset
	scale = start_scale
	modulate.a = 1.0

	# 세련된 트윈 애니메이션
	active_tween = create_tween().set_parallel(true)
	
	# 1. 크기 애니메이션 (팝)
	var scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", peak_scale, duration * 0.25) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(self, "scale", end_scale, duration * 0.75) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
		
	# 2. 이동 애니메이션
	var target_y = position.y + (drift_distance * direction_multiplier)
	active_tween.tween_property(self, "position:y", target_y, duration) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
		
	# 3. 서서히 사라짐
	active_tween.tween_property(self, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_LINEAR) \
		.set_delay(duration * 0.2) # 살짝 켜져있다가 사라짐

	# 4. 종료 후 자기 삭제
	active_tween.chain().tween_callback(queue_free)
