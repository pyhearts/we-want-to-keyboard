extends Label

var active_tween: Tween
var base_color: Color = Color(0.385, 0.385, 0.385, 1.0)


func _ready() -> void:
	# 피벗 중심을 라벨 중앙으로 설정
	pivot_offset = size / 2.0
	if has_theme_color_override("font_color"):
		base_color = get_theme_color("font_color")
		
	Global.combo_changed.connect(_on_combo_changed)
	_on_combo_changed(Global.combo)


func _on_combo_changed(new_combo: int) -> void:
	text = str(new_combo)
	
	if new_combo == 0:
		scale = Vector2.ONE
		add_theme_color_override("font_color", base_color)
		return
		
	# 텍스트가 바뀜에 따른 크기 변화 대응 피벗 설정
	pivot_offset = size / 2.0
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	active_tween = create_tween().set_parallel(true)
	
	# 순간 1.3배 팝업 후 부드러운 Elastic Ease Out으로 원복
	scale = Vector2(1.3, 1.3)
	active_tween.tween_property(self, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC) \
		.set_ease(Tween.EASE_OUT)
		
	# 마일스톤 연출: 50콤보의 배수일 때 황금빛으로 화려하게 반짝임
	if new_combo > 0 and new_combo % 50 == 0:
		add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0)) # 네온 골드
		var color_tween = create_tween()
		color_tween.tween_interval(0.4)
		color_tween.tween_callback(func(): add_theme_color_override("font_color", base_color))
	else:
		add_theme_color_override("font_color", base_color)
