extends Node2D

var current_radius: float = 15.0
var thickness: float = 8.0
var color: Color = Color(0.0, 1.0, 1.0, 1.0) # 기본 네온 블루
var duration: float = 0.35

var flash_radius: float = 35.0
var flash_color: Color = Color.WHITE


func _ready() -> void:
	var tween = create_tween().set_parallel(true)
	
	# 1. 쇼크웨이브 링 반경 확대 (Ease Out)
	tween.tween_property(self, "current_radius", 180.0, duration) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
		
	# 2. 링 두께 점차 감소
	tween.tween_property(self, "thickness", 1.0, duration) \
		.set_trans(Tween.TRANS_LINEAR)
		
	# 3. 링 투명도 페이드아웃
	var target_color = Color(color.r, color.g, color.b, 0.0)
	tween.tween_property(self, "color", target_color, duration) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)
		
	# 4. 중앙 백색 플래시 축소 및 페이드 (매우 빠르게 진행)
	tween.tween_property(self, "flash_radius", 0.0, duration * 0.45) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
		
	# 트윈 완료 시 메모리 해제
	tween.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# 중앙 백색 빛무리 플래시 그리기 (반경이 유효할 때만)
	if flash_radius > 0.1:
		var current_flash_color = Color(flash_color.r, flash_color.g, flash_color.b, color.a)
		draw_circle(Vector2.ZERO, flash_radius, current_flash_color)
		
	# 바깥쪽 동심원 쇼크웨이브 링 그리기
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 64, color, thickness, true)
