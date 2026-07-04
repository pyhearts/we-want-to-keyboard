extends Control
class_name HoldNote

# HOLD 노트 설정 변수
var duration: float = 3.0
var bpm: float = 120.0
var beat_division: int = 4 # 몇 박자 분할할지 (예: 4박자=4분음표, 8박자=8분음표, 16박자=16분음표)

# 허용 임계 게이지 (Tolerance Buffer) 변수 추가
@export var max_tolerance_gauge: float = 0.8 # 최대 유예 시간 (초 단위, 예: 0.8초 동안 놓치면 미스 판정)
var tolerance_gauge: float = 0.8
var is_currently_missed: bool = false # 현재 미스 상태에 진입해 있는지 여부

var remaining_time: float = 0.0
var elapsed_time: float = 0.0
var beat_interval: float = 0.5
var beat_timer: float = 0.0
var is_ending = false

var bg_rect: ColorRect
var vignette_rect: TextureRect # 동적 비네트 추가
var hold_label: Label
var time_label: Label

const FONT_PATH = "res://assets/fonts/Pretendard-Black.otf"
var custom_font: FontFile


func _ready() -> void:
	# 화면 전체를 덮도록 명시적인 앵커 및 오프셋 지정 (CanvasLayer 동적 생성 시 절대 좌표 꼬임 방지)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	
	remaining_time = duration
	tolerance_gauge = max_tolerance_gauge
	
	# 자동으로 곡의 BPM과 유저가 차트에 설정한 박자 수(beat_division)를 기준으로 정확한 비트 간격 계산
	# 4분음표(4박자) = 60/BPM, 8분음표(8박자) = 30/BPM, 16분음표(16박자) = 15/BPM
	beat_interval = (60.0 / bpm) * (4.0 / float(beat_division))
	
	if FileAccess.file_exists(FONT_PATH):
		custom_font = load(FONT_PATH)
		
	# 1. 뒷배경 검정색 레이어 (반투명한 검정색 레이어로 변경)
	bg_rect = ColorRect.new()
	bg_rect.color = Color(0, 0, 0, 0.6) # 60% 반투명 검정
	bg_rect.anchor_left = 0.0
	bg_rect.anchor_top = 0.0
	bg_rect.anchor_right = 1.0
	bg_rect.anchor_bottom = 1.0
	bg_rect.offset_left = 0.0
	bg_rect.offset_top = 0.0
	bg_rect.offset_right = 0.0
	bg_rect.offset_bottom = 0.0
	bg_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(bg_rect)
	
	# [비네트(Vignette) 감쇠 연출] 화면 가장자리를 어둡고 붉게 처리할 비네트 동적 생성
	vignette_rect = TextureRect.new()
	vignette_rect.name = "Vignette"
	vignette_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette_rect.anchor_left = 0.0
	vignette_rect.anchor_top = 0.0
	vignette_rect.anchor_right = 1.0
	vignette_rect.anchor_bottom = 1.0
	vignette_rect.offset_left = 0.0
	vignette_rect.offset_top = 0.0
	vignette_rect.offset_right = 0.0
	vignette_rect.offset_bottom = 0.0
	vignette_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vignette_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	vignette_rect.self_modulate = Color(0, 0, 0, 0) # 초기 투명 상태
	
	var grad_tex = GradientTexture2D.new()
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0)) # 내부 중앙은 투명
	grad.set_color(1, Color(1, 1, 1, 1)) # 외곽은 하얀색 (self_modulate로 동적 컬러링 가능)
	grad_tex.gradient = grad
	vignette_rect.texture = grad_tex
	add_child(vignette_rect)
	
	# 2. 완벽한 화면 정중앙 정렬을 위한 CenterContainer
	var center_container = CenterContainer.new()
	center_container.anchor_left = 0.0
	center_container.anchor_top = 0.0
	center_container.anchor_right = 1.0
	center_container.anchor_bottom = 1.0
	center_container.offset_left = 0.0
	center_container.offset_top = 0.0
	center_container.offset_right = 0.0
	center_container.offset_bottom = 0.0
	center_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(center_container)
	
	# 3. 텍스트 수직 정렬을 위한 VBoxContainer
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	center_container.add_child(container)
	
	# 3. HOLD 대형 글자 생성
	hold_label = Label.new()
	hold_label.text = "HOLD"
	hold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if custom_font:
		hold_label.add_theme_font_override("font", custom_font)
	hold_label.add_theme_font_size_override("font_size", 120)
	hold_label.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(hold_label)
	
	# 크기 변경 시 피벗을 자동으로 중앙으로 세팅하여 리듬감 있는 바운스 효과 최적화
	hold_label.item_rect_changed.connect(func():
		hold_label.pivot_offset = hold_label.size / 2.0
	)
	
	# 4. 남은 초 표시 레이블
	time_label = Label.new()
	time_label.text = "%.1fs" % remaining_time
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if custom_font:
		time_label.add_theme_font_override("font", custom_font)
	time_label.add_theme_font_size_override("font_size", 50)
	time_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	container.add_child(time_label)
	
	# 6. 부드럽게 0.3초 이내에 나타나기 (Fade In)
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _process(delta: float) -> void:
	if is_ending:
		return
		
	remaining_time -= delta
	elapsed_time += delta
	time_label.text = "%.1fs" % max(0.0, remaining_time)
	
	var holding = _is_holding()
	
	# [허용 임계 게이지(Tolerance Buffer) 및 실시간 복원 로직]
	if holding:
		# 다시 누르기 시작했다면 즉시 미스 상태 해제 및 게이지 회복
		is_currently_missed = false
		tolerance_gauge = min(max_tolerance_gauge, tolerance_gauge + delta * 1.5)
		
		# 글자가 MISS 상태였다면 다시 원래의 HOLD 상태로 복귀
		if is_instance_valid(hold_label) and hold_label.text == "MISS":
			hold_label.text = "HOLD"
			hold_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		# 손을 떼고 있으면 유예 게이지 감소
		tolerance_gauge -= delta
		if tolerance_gauge <= 0.0:
			tolerance_gauge = 0.0
			if not is_currently_missed:
				_trigger_miss_penalty()
				
	# [비네트 감쇠 연출 업데이트] 게이지 잔량에 따라 부드러운 외곽 경고 연출
	_update_vignette_visual(delta, holding)
	
	# BPM과 박자 수(beat_division)에 완벽하게 맞춘 비트 주기 타이머
	beat_timer += delta
	if beat_timer >= beat_interval:
		beat_timer -= beat_interval
		
		# 다시 꾹 누르는 도중에는 실시간으로 가점/콤보 재개! (최적의 복구 메커니즘)
		if holding:
			_bump_effect()
			Global.add_combo()
			Global.add_score(10)
			
	if remaining_time <= 0.0:
		_end_hold_note()


# 현재 키보드 Space 또는 마우스 왼쪽 클릭을 꾹 누르고 있는지 판정
func _is_holding() -> bool:
	return Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


# [비네트 감쇠 연출 업데이트] 유예 시간 깎임에 따라 외곽선을 빨갛고 은은하게 밝히는 웰메이드 UX
func _update_vignette_visual(delta: float, holding: bool) -> void:
	if not is_instance_valid(vignette_rect):
		return
		
	if is_currently_missed:
		# 판정이 완전히 깨졌을 때: 붉은색 외곽선 60% 투명도로 정착
		vignette_rect.self_modulate.a = lerp(vignette_rect.self_modulate.a, 0.6, delta * 5.0)
		vignette_rect.self_modulate.r = lerp(vignette_rect.self_modulate.r, 1.0, delta * 5.0)
		vignette_rect.self_modulate.g = lerp(vignette_rect.self_modulate.g, 0.0, delta * 5.0)
		vignette_rect.self_modulate.b = lerp(vignette_rect.self_modulate.b, 0.0, delta * 5.0)
	else:
		# 게이지 소실 비율 계산 (0.0 ~ 1.0)
		var depletion_ratio = 1.0 - (tolerance_gauge / max_tolerance_gauge)
		var target_alpha = depletion_ratio * 0.8 # 최대 80% 투명도까지 연출
		vignette_rect.self_modulate.a = lerp(vignette_rect.self_modulate.a, target_alpha, delta * 8.0)
		
		# 잘 홀딩하고 있으면 원래의 차분한 다크 섀도우(Vignette Focus)로 회귀, 놓치면 붉은빛 경고로 이주
		if holding:
			vignette_rect.self_modulate.r = lerp(vignette_rect.self_modulate.r, 0.0, delta * 5.0)
			vignette_rect.self_modulate.g = lerp(vignette_rect.self_modulate.g, 0.0, delta * 5.0)
			vignette_rect.self_modulate.b = lerp(vignette_rect.self_modulate.b, 0.0, delta * 5.0)
		else:
			vignette_rect.self_modulate.r = lerp(vignette_rect.self_modulate.r, 0.8, delta * 5.0)
			vignette_rect.self_modulate.g = lerp(vignette_rect.self_modulate.g, 0.0, delta * 5.0)
			vignette_rect.self_modulate.b = lerp(vignette_rect.self_modulate.b, 0.0, delta * 5.0)


# [허용 임계 게이지 고갈] 최종 1회 MISS 판정 및 패널티 부과
func _trigger_miss_penalty() -> void:
	is_currently_missed = true
	Global.reset_combo()
	Global.add_score(0)
	
	# 비네트에 강한 붉은 플래시 타격 임팩트
	if is_instance_valid(vignette_rect):
		vignette_rect.self_modulate = Color(1.0, 0.0, 0.0, 1.0)
		var flash_tween = create_tween()
		flash_tween.tween_property(vignette_rect, "self_modulate:a", 0.6, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# 홀드 대형 라벨을 무기력한 회색 "MISS"로 전환
	if is_instance_valid(hold_label):
		hold_label.text = "MISS"
		hold_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		
	# 화면 흔들림(Camera Shake) 피드백으로 조작감 완성
	Global.camera_shake_requested.emit(8.0, 0.15)


# BPM 비트에 맞춘 홀드 텍스트 바운스 범프 효과 및 배경 비트 플래시 효과
func _bump_effect() -> void:
	if is_ending:
		return
		
	# 박자 쪼개기 속도에 맞춰 애니메이션 트랜지션 시간도 유연하게 비례하도록 설계
	var attack = min(0.05, beat_interval * 0.25)
	var decay = min(0.15, beat_interval * 0.75)
		
	if is_instance_valid(hold_label):
		hold_label.pivot_offset = hold_label.size / 2.0 # 가운데 기준 크기 변경 보장
		var bump_tween = create_tween()
		bump_tween.tween_property(hold_label, "scale", Vector2(1.18, 1.18), attack)
		bump_tween.tween_property(hold_label, "scale", Vector2(1.0, 1.0), decay)
		
	if is_instance_valid(bg_rect):
		var bg_tween = create_tween()
		bg_tween.tween_property(bg_rect, "color", Color(0.25, 0.25, 0.25, 0.6), attack)
		bg_tween.tween_property(bg_rect, "color", Color(0, 0, 0, 0.6), decay)


# [소멸 연출 진입 시 물리/프로세스 즉각 동결] 추가 점수 및 입력 판정 원천 차단
func _end_hold_note() -> void:
	if is_ending:
		return
	is_ending = true
	
	# 동결 핵심: 페이드아웃 연출 중에 점수나 콤보 틱이 일절 돌지 못하도록 프로세스 완전 정지!
	set_process(false)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
