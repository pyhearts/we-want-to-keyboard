extends Control
class_name HoldNote

# HOLD 노트 설정 변수
var duration: float = 3.0
var bpm: float = 120.0
var beat_division: int = 4 # 몇 박자 분할할지 (예: 4박자=4분음표, 8박자=8분음표, 16박자=16분음표)

var remaining_time: float = 0.0
var elapsed_time: float = 0.0
var beat_interval: float = 0.5
var beat_timer: float = 0.0
var is_ending := false

var bg_rect: ColorRect
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
	
	# BPM과 박자 수(beat_division)에 완벽하게 맞춘 비트 주기 타이머
	beat_timer += delta
	if beat_timer >= beat_interval:
		beat_timer -= beat_interval
		
		if _is_holding():
			# 꾹 잘 누르고 있을 때: 노트 커짐 + 배경 화이트 플래시 + 점수 얻기 + 콤보 쌓기
			_bump_effect()
			Global.add_combo()
			Global.add_score(10)
		else:
			# 누르지 않고 놓치고 있을 때: 배경 레드 플래시 + 점수 잃기 + 콤보 깨지기
			_flash_red_effect()
			Global.reset_combo()
			Global.add_score(-30)
			
	if remaining_time <= 0.0:
		_end_hold_note()


# 현재 키보드 Space 또는 마우스 왼쪽 클릭을 꾹 누르고 있는지 판정
func _is_holding() -> bool:
	return Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


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


# 비트에 맞춘 미입력 시 배경을 잠깐 빨간색으로 변경하는 이펙트
func _flash_red_effect() -> void:
	if not is_instance_valid(bg_rect) or is_ending:
		return
		
	var attack = min(0.05, beat_interval * 0.25)
	var decay = min(0.15, beat_interval * 0.75)
	
	var flash_tween = create_tween()
	flash_tween.tween_property(bg_rect, "color", Color(0.8, 0.1, 0.1, 0.8), attack)
	flash_tween.tween_property(bg_rect, "color", Color(0, 0, 0, 0.6), decay)


# 부드럽게 0.3초 이내에 사라지기 (Fade Out) 및 메모리 해제
func _end_hold_note() -> void:
	if is_ending:
		return
	is_ending = true
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
