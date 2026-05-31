extends Control

# 결과 화면(Result Scene) GDScript 소스 코드
# 이 스크립트는 게임 종료 후 플레이어의 성적과 통계를 #ff86a5 핑크 테마 및 글래스모피즘 카드로 연출합니다.
# [올 퍼펙트 전용 실시간 무지개 색상 변환(Rainbow Hue Shift)] 연출 로직이 완벽하게 실장되어 있습니다.

const MUSIC_SELECT_SCENE = "res://scenes/menu/music_select.tscn"
const GAME_SCENE = "res://scenes/game/game.tscn"
const FONT_PATH = "res://assets/fonts/Pretendard-Black.otf"
const PINK_COLOR = Color("ff86a5")
const DEEP_DARK_COLOR = Color("2e091b") # 밝은 핑크 배경과의 대비를 위한 깊은 버건디/차콜 색상

# 주스(Juice) 연출 강도 및 시간 튜닝 변수들
@export var rank_bounce_duration: float = 0.65 # 랭크 등장 바운스 시간 (초)
@export var rank_initial_scale: float = 6.0    # 랭크 최초 스폰 크기 배율 (거대하게 낙하)
@export var rank_initial_rotation: float = -40.0 # 랭크 최초 스폰 회전각 (도)
@export var hover_amplitude: float = 14.0       # S랭크 둥둥 뜨기 진폭 (픽셀)
@export var hover_duration: float = 1.3        # S랭크 둥둥 뜨기 편도 시간 (초)
@export var breath_duration: float = 1.1       # S랭크 네온 글로우 숨쉬기 편도 시간 (초)

# [무지개 삐까쩍 연출 변수]
@export var hue_shift_speed: float = 0.35      # 1초당 무지개색 순환 속도 (약 2.8초에 한 바퀴 순환)
var is_all_perfect: bool = false               # 올 퍼펙트 달성 여부 (100만 점 여부)
var hue_accum: float = 0.0                     # Hue 값 실시간 누적 변수

# UI 노드 참조
@onready var title_label: Label = $MainContainer/TopInfo/TitleLabel
@onready var artist_label: Label = $MainContainer/TopInfo/ArtistLabel
@onready var difficulty_label: Label = $MainContainer/TopInfo/DifficultyLabel

@onready var rank_label: Label = $MainContainer/CenterLayout/LeftCard/LeftPanel/RankLabel
@onready var all_perfect_badge: Label = $MainContainer/CenterLayout/LeftCard/LeftPanel/AllPerfectBadge

@onready var score_val: Label = $MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/ScoreRow/ScoreVal
@onready var combo_val: Label = $MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/ComboRow/ComboVal

@onready var retry_button: Button = $MainContainer/BottomButtons/RetryButton
@onready var select_button: Button = $MainContainer/BottomButtons/SelectButton

# 파티클 효과 노드 (올 퍼펙트용)
@onready var score_particles: CPUParticles2D = $ScoreParticles

var final_score: int = 0
var final_combo: int = 0
var final_rank: String = "F"
var custom_font: FontFile


func _ready() -> void:
	# 마우스 입력 차단 무시하여 버튼 클릭 보장
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 한국어 폰트 적용
	if FileAccess.file_exists(FONT_PATH):
		custom_font = load(FONT_PATH)
		_apply_font_overrides()

	# #ff86a5 테마 전용 프로그램 스타일 버튼 및 패널 디자인 적용
	_style_elements()

	# 올 퍼펙트 배지 및 파티클은 기본적으로 비활성화
	all_perfect_badge = $MainContainer/CenterLayout/LeftCard/LeftPanel/AllPerfectBadge
	if all_perfect_badge:
		all_perfect_badge.visible = false
		all_perfect_badge.modulate = PINK_COLOR
	if score_particles:
		score_particles.emitting = false
		score_particles.color = PINK_COLOR

	# 전역 데이터로부터 최종 점수, 콤보, 랭크 취득
	final_score = Global.score
	final_combo = Global.max_combo
	final_rank = _calculate_rank(final_score)

	# [올 퍼펙트 판단] 정확히 1,000,000점인 만점일 때만 무지개색 연출 플래그 ON
	is_all_perfect = (final_score == 1000000)

	# 곡명/아티스트 정보 채우기
	_display_song_info()

	# 연출 시작 전 투명도 및 스케일 세팅
	_prepare_intro_animations()

	# [화면 전환 연동 - 진입 시점]
	if SceneTransition and SceneTransition._is_transitioning:
		await get_tree().create_timer(0.4).timeout

	# 트윈(Tween) 애니메이션 기동
	_play_result_animations()


# 매 프레임 올 퍼펙트 전용 무지개색 색상 사이클 연동
func _process(delta: float) -> void:
	if is_all_perfect:
		_process_rainbow_effects(delta)


# 올 퍼펙트 무지개 색상 순환(Hue Shift) 및 삐까뻔쩍 글로우 처리 핵심 로직
func _process_rainbow_effects(delta: float) -> void:
	# 시간에 따른 Hue(색상값) 순환 증가 (0.0 ~ 1.0 범위 내에서 무한 보간)
	hue_accum = fmod(hue_accum + delta * hue_shift_speed, 1.0)
	
	# HSV 모델을 활용해 부드럽게 이어지는 무지개색 추출 (채도 0.85, 명도 1.0)
	var rainbow_color = Color.from_hsv(hue_accum, 0.85, 1.0, 1.0)
	
	# 1. 랭크 텍스트 본체 무지개 시프트
	if rank_label:
		rank_label.add_theme_color_override("font_color", rainbow_color)
		
	# 2. 랭크 뒷단 네온 글로우 무지개 테두리 시프트
	var glow_node = $MainContainer/CenterLayout/LeftCard/LeftPanel.get_node_or_null("GlowRankLabel") as Label
	if glow_node:
		# 글로우 레이어는 두꺼운 테두리(outline) 아웃라인을 무지개색으로 변환
		glow_node.add_theme_color_override("font_outline_color", rainbow_color)
		
	# 3. 올 퍼펙트 전용 배지 무지개 시프트
	if all_perfect_badge:
		all_perfect_badge.add_theme_color_override("font_color", rainbow_color)
		
	# 4. 터져 나오는 파티클 입자들의 색상 무지개 시프트 (VFX 극대화)
	if score_particles:
		score_particles.color = rainbow_color


# 폰트 오버라이드 일괄 적용 함수
func _apply_font_overrides() -> void:
	var labels = [
		title_label, artist_label, difficulty_label, rank_label, all_perfect_badge,
		score_val, combo_val,
		$MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/ScoreRow/ScoreLabel,
		$MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/ComboRow/ComboLabel,
		$MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/JudgmentsGrid/PerfectLabel,
		$MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/JudgmentsGrid/PerfectVal,
		$MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/JudgmentsGrid/GreatLabel,
		$MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/JudgmentsGrid/GreatVal,
		$MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/JudgmentsGrid/GoodLabel,
		$MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/JudgmentsGrid/GoodVal,
		$MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/JudgmentsGrid/MissLabel,
		$MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/JudgmentsGrid/MissVal,
		retry_button, select_button
	]
	for label in labels:
		if label:
			label.add_theme_font_override("font", custom_font)


# UI 요소들의 고급 스타일 코딩 함수
func _style_elements() -> void:
	# 1. 탑 레이블 가시성 확보 (밝은 핑크 배경 대비용 짙은 컬러 지정)
	title_label.add_theme_color_override("font_color", DEEP_DARK_COLOR)
	artist_label.add_theme_color_override("font_color", Color(DEEP_DARK_COLOR.r, DEEP_DARK_COLOR.g, DEEP_DARK_COLOR.b, 0.75)) # 투명한 버건디
	difficulty_label.add_theme_color_override("font_color", DEEP_DARK_COLOR)

	# 2. 유리 느낌의 반투명 어두운 카드 스타일 (Glassmorphism Panel)
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.03, 0.05, 0.65) # 매우 어두운 핑크빛 도는 차콜 (65% 반투명)
	card_style.set_corner_radius_all(16)
	card_style.set_border_width_all(2)
	card_style.border_color = Color(1.0, 1.0, 1.0, 0.15) # 미세한 흰색 외곽선으로 유리의 두께감 연출
	
	$MainContainer/CenterLayout/LeftCard.add_theme_stylebox_override("panel", card_style)
	$MainContainer/CenterLayout/RightCard.add_theme_stylebox_override("panel", card_style)

	# 3. #ff86a5 테마 기반 버튼 스타일 박스 설정
	var button_normal_bg = Color("240715") # 짙은 버건디/차콜 버튼 기본 배경
	var button_hover_bg = PINK_COLOR       # 오버 시 메인 핑크 컬러로 가득 채움
	var button_pressed_bg = Color("d15a77") # 클릭 시 눌림 색상 적용 (어두운 핑크)
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = button_normal_bg
	normal_style.border_color = PINK_COLOR
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = button_hover_bg
	hover_style.border_color = Color("ffa6bd") # 밝은 핑크 보더라인
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(8)
	
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = button_pressed_bg
	pressed_style.border_color = PINK_COLOR
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(8)
	
	# 다시하기 버튼 스타일 적용
	retry_button.add_theme_stylebox_override("normal", normal_style)
	retry_button.add_theme_stylebox_override("hover", hover_style)
	retry_button.add_theme_stylebox_override("pressed", pressed_style)
	retry_button.add_theme_stylebox_override("focus", normal_style)
	retry_button.add_theme_color_override("font_color", Color.WHITE)
	retry_button.add_theme_color_override("font_hover_color", Color.WHITE)
	
	# 악곡 선택하기 버튼 스타일 적용
	select_button.add_theme_stylebox_override("normal", normal_style)
	select_button.add_theme_stylebox_override("hover", hover_style)
	select_button.add_theme_stylebox_override("pressed", pressed_style)
	select_button.add_theme_stylebox_override("focus", normal_style)
	select_button.add_theme_color_override("font_color", Color.WHITE)
	select_button.add_theme_color_override("font_hover_color", Color.WHITE)


# 최종 점수에 따른 리듬게임 전통 랭크 판단
func _calculate_rank(score_val_int: int) -> String:
	if score_val_int >= 950000:
		return "S"
	elif score_val_int >= 850000:
		return "A"
	elif score_val_int >= 750000:
		return "B"
	elif score_val_int >= 600000:
		return "C"
	else:
		return "F"


# 악곡 고유 메타데이터 로드 및 표시
func _display_song_info() -> void:
	if Global.selected_music != "":
		# 곡 정보를 Res.tres에서 가져오기
		var res_path = Global.get_music_res_path(Global.selected_music)
		if FileAccess.file_exists(res_path):
			var music_res = load(res_path)
			if music_res:
				if music_res.title == "" or music_res.title == "Unknown Title":
					title_label.text = Global.selected_music
				else:
					title_label.text = music_res.title
				
				if music_res.composer == "" or music_res.composer == "Unknown Composer":
					artist_label.text = "Unknown Composer"
				else:
					artist_label.text = music_res.composer
				
				difficulty_label.text = "BPM: %d" % music_res.bpm
				return
		title_label.text = Global.selected_music
		artist_label.text = "자체 제작 차트"
		difficulty_label.text = "BPM: 120"
	else:
		title_label.text = "선택된 곡 없음"
		artist_label.text = "아티스트 미상"
		difficulty_label.text = "난이도: Normal"


# 애니메이션 준비를 위해 투명도 및 스케일 초기화 설정 (컨테이너 내에서 안전한 연출)
func _prepare_intro_animations() -> void:
	var animated_groups = [
		$MainContainer/TopInfo,
		$MainContainer/CenterLayout/LeftCard,
		$MainContainer/CenterLayout/RightCard,
		$MainContainer/BottomButtons
	]
	for group in animated_groups:
		if group:
			group.modulate.a = 0.0
			
			# 스케일의 중심(Pivot Offset)이 정중앙이 되도록 동적 및 정적 초기 설정
			group.item_rect_changed.connect(func():
				group.pivot_offset = group.size / 2.0
			)
			group.pivot_offset = group.size / 2.0
			group.scale = Vector2(0.95, 0.95) # 95% 크기에서 100%로 커지도록 설정
			
	# 랭크 라벨의 바운스 임팩트 연출을 위한 사전 숨김 처리
	if rank_label:
		rank_label.modulate.a = 0.0


# 위에서 아래로 흘러가는 스태거드 딜레이 결과 애니메이션 실행 (Modulate 및 Scale 트윈 사용)
func _play_result_animations() -> void:
	var tween = create_tween().set_parallel(true)
	
	# 1단계: 상단 곡 정보 페이드인 + 스케일 복원 (딜레이 0.0s)
	var top_node = $MainContainer/TopInfo
	tween.tween_property(top_node, "modulate:a", 1.0, 0.4).set_delay(0.0)
	tween.tween_property(top_node, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.0)
	
	# 2단계: 중앙 우측 상세 기록 판넬 페이드인 + 스케일 복원 (딜레이 0.2s)
	var right_panel = $MainContainer/CenterLayout/RightCard
	tween.tween_property(right_panel, "modulate:a", 1.0, 0.4).set_delay(0.2)
	tween.tween_property(right_panel, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.2)
	
	# 판정 개수 매핑
	var p_val = $MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/JudgmentsGrid/PerfectVal
	var gt_val = $MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/JudgmentsGrid/GreatVal
	var gd_val = $MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/JudgmentsGrid/GoodVal
	var m_val = $MainContainer/CenterLayout/RightCard/MarginContainer/RightPanel/JudgmentsGrid/MissVal
	
	p_val.text = str(Global.perfect_count)
	gt_val.text = str(Global.great_count)
	gd_val.text = str(Global.good_count)
	m_val.text = str(Global.miss_count)
	
	# 점수 및 최대 콤보 0부터 타겟까지 드르륵 굴려 오르는 카운팅 효과 구현 (1.2초 소요)
	var count_tween = create_tween().set_parallel(true)
	count_tween.tween_method(
		func(val: int): score_val.text = "%07d" % val,
		0, final_score, 1.2
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	count_tween.tween_method(
		func(val: int): combo_val.text = "%d" % val,
		0, final_combo, 1.0
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 3단계: 중앙 좌측 랭크 카드 패널 등장 (딜레이 0.6s)
	var left_panel = $MainContainer/CenterLayout/LeftCard
	tween.parallel().tween_property(left_panel, "modulate:a", 1.0, 0.4).set_delay(0.6)
	tween.parallel().tween_property(left_panel, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.6)
	
	# [주스 연동 - 임팩트 모션] 점수와 콤보 카운팅이 완료된 직후 최종 랭크가 "쾅!" 하고 꽂히도록 스케줄링
	count_tween.chain().tween_callback(_play_rank_slam_animation)

	# 4단계: 하단 푸터(Footer) 버튼 가로배치 판넬 등장 + 스케일 복원 (딜레이 1.4s)
	var bottom_buttons = $MainContainer/BottomButtons
	tween.parallel().tween_property(bottom_buttons, "modulate:a", 1.0, 0.4).set_delay(1.4)
	tween.parallel().tween_property(bottom_buttons, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(1.4)


# 최종 랭크가 "쿠궁!" 하고 회전하며 꽂히는 엘라스틱 슬램 애니메이션 (Juice!)
func _play_rank_slam_animation() -> void:
	if not rank_label:
		return
		
	# 1. 랭크 라벨의 내용 및 초기 비틀기 상태 부여
	rank_label.text = final_rank
	rank_label.modulate.a = 1.0
	
	# 피벗 포인트 강제 갱신
	rank_label.pivot_offset = rank_label.size / 2.0
	
	# 최초 거대한 낙하 스케일 및 비스듬한 회전 각도 설정
	rank_label.scale = Vector2(rank_initial_scale, rank_initial_scale)
	rank_label.rotation = deg_to_rad(rank_initial_rotation)
	
	# [올퍼펙트 예외] 올퍼펙트 상태인 경우 무지개 실시간 루프로 색상을 결정하므로
	# 일반 기동 시 랭크 텍스트 컬러 오버라이드 처리는 올퍼펙트가 아닐 때만 처리합니다.
	if not is_all_perfect:
		if final_rank == "S":
			rank_label.add_theme_color_override("font_color", PINK_COLOR)
		else:
			rank_label.add_theme_color_override("font_color", Color.WHITE)

	# 2. 크기 및 각도 복귀 트윈 가동 (탄성 바운스 TRANS_BOUNCE)
	var slam_tween = create_tween().set_parallel(true)
	
	slam_tween.tween_property(rank_label, "scale", Vector2(1.0, 1.0), rank_bounce_duration) 		.set_trans(Tween.TRANS_BOUNCE) 		.set_ease(Tween.EASE_OUT)
		
	slam_tween.tween_property(rank_label, "rotation", 0.0, rank_bounce_duration) 		.set_trans(Tween.TRANS_CUBIC) 		.set_ease(Tween.EASE_OUT)
		
	# 3. 바운스 타격 쾌감을 완성하기 위한 화면 흔들림(Camera Shake) 피드백 연동
	var camera_tween = create_tween()
	camera_tween.tween_interval(0.12)
	camera_tween.tween_callback(func(): Global.camera_shake_requested.emit(12.0, 0.22))
	
	# 4. 연출이 다 끝난 뒤 고등급 특수 반복 루프 및 올퍼펙트 이벤트 활성화
	slam_tween.chain().tween_callback(func():
		if final_rank == "S":
			_start_high_rank_loop()
		if final_score == 1000000:
			_trigger_all_perfect_effects()
	)


# S랭크 이상 고등급 달성 시 작동하는 무한 둥둥 뜨기(Hovering) 및 숨쉬는 광택(Breathing Glow) 연출
func _start_high_rank_loop() -> void:
	if not rank_label:
		return
		
	# 1. 랭크 라벨의 외곽 글로우용 레이어를 코드로 복제 생성
	var glow_label = rank_label.duplicate() as Label
	glow_label.name = "GlowRankLabel"
	
	# 글로우 라벨 세팅 (보더를 두껍게 주고 중심부를 투명하게 하여 은은한 그림자 형성)
	glow_label.pivot_offset = rank_label.pivot_offset
	glow_label.add_theme_constant_override("outline_size", 28)
	
	# [올퍼펙트 예외] 올퍼펙트 상태 시에는 아웃라인 컬러도 실시간 무지개로 시프트되므로 오버라이드를 건너뜁니다.
	if not is_all_perfect:
		glow_label.add_theme_color_override("font_outline_color", PINK_COLOR)
	glow_label.add_theme_color_override("font_color", Color(0, 0, 0, 0)) # 센터 구멍은 투명
	
	# 씬 렌더링 뎁스를 위해 원본 랭크 라벨 바로 뒷단(Sibling Index 아래)에 삽입
	rank_label.get_parent().add_child(glow_label)
	rank_label.get_parent().move_child(glow_label, rank_label.get_index())
	
	# 2. 은은하게 숨쉬는 네온 블러(Breathing Glow) 루프 시작
	var breath_tween = create_tween().set_loops()
	breath_tween.tween_property(glow_label, "modulate:a", 0.2, breath_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath_tween.tween_property(glow_label, "modulate:a", 0.8, breath_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 3. 랭크 텍스트 본체와 빛 그림자가 일체화되어 위아래로 유려하게 뜨는(Hovering) 루프 가동
	var original_pos_y = rank_label.position.y
	
	# 무한 루프 병렬 트윈 정의
	var hover_tween = create_tween().set_loops()
	
	# (1) 위로 둥둥 뜨기
	var hover_up = hover_tween.parallel()
	hover_up.tween_property(rank_label, "position:y", original_pos_y - hover_amplitude, hover_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hover_up.tween_property(glow_label, "position:y", original_pos_y - hover_amplitude, hover_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# (2) 아래로 가라앉기
	var hover_down = hover_tween.chain().parallel()
	hover_down.tween_property(rank_label, "position:y", original_pos_y + hover_amplitude, hover_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hover_down.tween_property(glow_label, "position:y", original_pos_y + hover_amplitude, hover_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# 올 퍼펙트 달성 시 펼쳐지는 축하 효과 연출 함수
func _trigger_all_perfect_effects() -> void:
	print("CONGRATULATIONS: ALL PERFECT!")
	
	# 1. 무지개색 폭죽 파티클 스파클 발사
	if score_particles:
		score_particles.emitting = true
		
	# 2. 'ALL PERFECT' 배지 회전/크기 애니메이션으로 등장
	all_perfect_badge = $MainContainer/CenterLayout/LeftCard/LeftPanel/AllPerfectBadge
	if all_perfect_badge:
		all_perfect_badge.visible = true
		all_perfect_badge.modulate.a = 0.0
		all_perfect_badge.rotation_degrees = -30.0
		all_perfect_badge.scale = Vector2.ZERO
		
		var ap_tween = create_tween().set_parallel(true)
		ap_tween.tween_property(all_perfect_badge, "modulate:a", 1.0, 0.5)
		ap_tween.tween_property(all_perfect_badge, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ap_tween.tween_property(all_perfect_badge, "rotation_degrees", 0.0, 0.5).set_trans(Tween.TRANS_QUAD)
		
		# 등장 후 화려하게 고동치는 무한 심장박동 & 밝기 블링킹(Blink) 효과 실행
		ap_tween.chain().tween_callback(func():
			var pulse_tween = create_tween().set_loops()
			pulse_tween.tween_property(all_perfect_badge, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_SINE)
			pulse_tween.parallel().tween_property(all_perfect_badge, "modulate:a", 0.6, 0.4).set_trans(Tween.TRANS_SINE)
			pulse_tween.tween_property(all_perfect_badge, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_SINE)
			pulse_tween.parallel().tween_property(all_perfect_badge, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
		)


# 다시하기 시그널 버튼 바인딩 함수
func _on_retry_button_pressed() -> void:
	Global.reset_run()
	
	# 기존 화면 전환 매니저(싱글톤 SceneTransition) 연동을 통한 자연스러운 씬 교체
	if has_node("/root/SceneTransition") or SceneTransition != null:
		SceneTransition.transition_to_scene(GAME_SCENE)
	else:
		# 폴백 안전 처리 (싱글톤이 없을 경우 기본 로드)
		get_tree().change_scene_to_file(GAME_SCENE)


# 악곡 선택하기 시그널 버튼 바인딩 함수
func _on_select_button_pressed() -> void:
	if has_node("/root/SceneTransition") or SceneTransition != null:
		SceneTransition.transition_to_scene(MUSIC_SELECT_SCENE)
	else:
		# 폴백 안전 처리 (싱글톤이 없을 경우 기본 로드)
		get_tree().change_scene_to_file(MUSIC_SELECT_SCENE)
