extends VideoStreamPlayer

const MUSIC_BASE_PATH = "res://assets/musics/"

var bga_loaded: bool = false
var bga_started: bool = false
var ratio_container: AspectRatioContainer = null

# --- 배경 연출 및 비주얼라이저 관련 변수 ---
var bg_player: VideoStreamPlayer = null
var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance = null
var left_bars: Array[ColorRect] = []
var right_bars: Array[ColorRect] = []
const BAR_COUNT = 16
const MAX_BAR_HEIGHT = 180.0
var bar_heights: Array[float] = []

# 가우시안 블러 및 디밍(어둡게) 처리를 위한 GLSL 셰이더
const BLUR_SHADER_CODE = """
shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 10.0) = 5.0;
uniform float brightness : hint_range(0.0, 2.0) = 0.45;

void fragment() {
	vec4 color = vec4(0.0);
	float total = 0.0;
	
	// 가우시안 9-탭 블러 필터 적용
	for (float x = -2.0; x <= 2.0; x += 1.0) {
		for (float y = -2.0; y <= 2.0; y += 1.0) {
			vec2 offset = vec2(x, y) * blur_amount * 0.0015;
			color += texture(TEXTURE, UV + offset);
			total += 1.0;
		}
	}
	
	color /= total;
	color.rgb *= brightness; // 배경 톤을 어둡게 하여 전경 동영상이 부각되도록 함
	COLOR = color;
}
"""

func _ready() -> void:
	# 1. BGA 활성화 여부 세팅
	var is_bga_enabled = true
	if "enable_bga" in Global:
		is_bga_enabled = Global.enable_bga
		
	if not is_bga_enabled:
		visible = false
		return
		
	# 2. AspectRatioContainer 마스킹 래핑 지연 생성 (Parent busy 스레드 충돌 완벽 방지)
	call_deferred("_setup_aspect_ratio_wrapper")
	
	visible = true
	volume_db = -80.0  # 전경 비디오 음소거 (오디오 트랙은 메인 MP3 플레이어 사용)
	audio_track = -1
	expand = true      # 비율유지 컨테이너 안에서 재생
	
	# 3. 오디오 스펙트럼 애널라이저 및 연출 세팅 (지연 실행하여 트리 안전 확보)
	call_deferred("_setup_visualizer_effects")
	
	if Global.selected_music == "":
		return
		
	# 4. OGV 동적 로딩
	var bga_path = MUSIC_BASE_PATH + Global.selected_music + "/bga.ogv"
	
	if ResourceLoader.exists(bga_path):
		var video_stream = load(bga_path)
		if video_stream:
			stream = video_stream
			bga_loaded = true
			print("[VideoStreamPlayer] BGA 로드 성공: ", bga_path)
		else:
			push_error("[VideoStreamPlayer] BGA 스트림 로딩 에러: " + bga_path)
	else:
		push_warning("[VideoStreamPlayer] BGA 파일이 없습니다: " + bga_path)
		visible = false


func _setup_aspect_ratio_wrapper() -> void:
	# 이미 래핑되어 있다면 중복 실행 차단
	if get_parent() is AspectRatioContainer and get_parent().name == "BgaRatioContainer":
		ratio_container = get_parent()
		return
		
	# 1. AspectRatioContainer 생성
	ratio_container = AspectRatioContainer.new()
	ratio_container.name = "BgaRatioContainer"
	ratio_container.stretch_mode = AspectRatioContainer.STRETCH_FIT
	ratio_container.ratio = 16.0 / 9.0 # 기본 16:9 비율
	ratio_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 2. BGA를 화면 전체 크기(Full Screen Rect) 및 중앙 정렬로 강제 설정하여 밖으로 나가지 않는 최대 크기 구현
	ratio_container.layout_mode = 1 # Control.LAYOUT_MODE_ANCHORS
	ratio_container.anchors_preset = Control.PRESET_FULL_RECT
	ratio_container.anchor_left = 0.0
	ratio_container.anchor_top = 0.0
	ratio_container.anchor_right = 1.0
	ratio_container.anchor_bottom = 1.0
	ratio_container.offset_left = 0.0
	ratio_container.offset_top = 0.0
	ratio_container.offset_right = 0.0
	ratio_container.offset_bottom = 0.0
	ratio_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ratio_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	ratio_container.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	ratio_container.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
	
	# 3. 트리 구조 교체
	var orig_parent = get_parent()
	if orig_parent:
		var orig_index = get_index()
		orig_parent.add_child(ratio_container)
		orig_parent.move_child(ratio_container, orig_index)
		
		# 자기(VideoStreamPlayer)를 컨테이너 안으로 이동
		orig_parent.remove_child(self)
		ratio_container.add_child(self)
		
		# 자기 레이아웃을 컨테이너 안에서 꽉 차도록 설정
		anchors_preset = Control.PRESET_FULL_RECT
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


# --- 실시간 연출 & 비주얼라이저 설치 함수 ---
func _setup_visualizer_effects() -> void:
	var root = get_parent()
	if not root:
		return
		
	# A. 듀얼 VideoStreamPlayer 중 블러된 "배경 비디오" 플레이어 동적 생성
	bg_player = VideoStreamPlayer.new()
	bg_player.name = "BgaBackgroundPlayer"
	bg_player.expand = true
	bg_player.volume_db = -80.0
	bg_player.audio_track = -1
	bg_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_player.stream = stream # 전경과 비디오 소스 공유
	
	# 화면 비율에 무관하게 화면 전체를 꽉 채우도록 강제 (Stretched)
	bg_player.layout_mode = 1
	bg_player.anchors_preset = Control.PRESET_FULL_RECT
	bg_player.anchor_left = 0.0
	bg_player.anchor_top = 0.0
	bg_player.anchor_right = 1.0
	bg_player.anchor_bottom = 1.0
	bg_player.offset_left = 0.0
	bg_player.offset_top = 0.0
	bg_player.offset_right = 0.0
	bg_player.offset_bottom = 0.0
	bg_player.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg_player.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# 가우시안 블러 및 디밍 셰이더 머티리얼 입히기
	var shader = Shader.new()
	shader.code = BLUR_SHADER_CODE
	var material_blur = ShaderMaterial.new()
	material_blur.shader = shader
	bg_player.material = material_blur
	
	# 트리상 전경 비디오 컨테이너(BgaRatioContainer)의 아래(뒤)에 배경 비디오 추가
	var ratio_parent = ratio_container.get_parent()
	if ratio_parent:
		var ratio_idx = ratio_container.get_index()
		ratio_parent.add_child(bg_player)
		# BgaRatioContainer의 바로 밑(뒤)에 오도록 인덱스 순서 지정
		ratio_parent.move_child(bg_player, ratio_idx)
		
	# B. 오디오 스펙트럼 애널라이저 장착
	# 현재 메인 오디오 버스(Master 또는 0번 버스)에 분석 효과 장착
	var effect_idx = -1
	for idx in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0, idx) is AudioEffectSpectrumAnalyzer:
			effect_idx = idx
			break
			
	if effect_idx == -1:
		# 존재하지 않는 경우 오디오 분석 효과를 런타임에 동적으로 삽입
		var analyzer_effect = AudioEffectSpectrumAnalyzer.new()
		analyzer_effect.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
		AudioServer.add_bus_effect(0, analyzer_effect)
		effect_idx = AudioServer.get_bus_effect_count(0) - 1
		
	spectrum_analyzer = AudioServer.get_bus_effect_instance(0, effect_idx)
	
	# C. 좌/우 비주얼라이저 UI 생성 및 정렬
	# 배경과 전경 비디오 사이(즉, 블러 처리된 여백 위)에 배치
	_create_visualizer_bars(ratio_parent)


func _create_visualizer_bars(parent: Node) -> void:
	if not parent:
		return
		
	# 실시간 높이 버퍼 배열 초기화
	bar_heights.resize(BAR_COUNT)
	bar_heights.fill(0.0)
	
	# 좌측 비주얼라이저 컨테이너 (화면 좌측 사이드 배치)
	var left_container = HBoxContainer.new()
	left_container.name = "LeftBgaVisualizer"
	left_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_container.layout_mode = 1
	left_container.anchors_preset = Control.PRESET_BOTTOM_LEFT
	left_container.anchor_left = 0.01   # 화면 좌측 살짝 여백
	left_container.anchor_right = 0.20  # 전체 화면의 19% 가로폭 사용
	left_container.anchor_top = 0.65    # 하단 35% 영역에 오도록 배치
	left_container.anchor_bottom = 0.95
	left_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	left_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	left_container.alignment = BoxContainer.ALIGNMENT_CENTER
	left_container.theme_override_constants.separation = 5 # 바들 사이 간격
	
	# 우측 비주얼라이저 컨테이너 (화면 우측 사이드 배치)
	var right_container = HBoxContainer.new()
	right_container.name = "RightBgaVisualizer"
	right_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_container.layout_mode = 1
	right_container.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	right_container.anchor_left = 0.80  # 전체 화면의 우측 20%
	right_container.anchor_right = 0.99
	right_container.anchor_top = 0.65
	right_container.anchor_bottom = 0.95
	right_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	right_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	right_container.alignment = BoxContainer.ALIGNMENT_CENTER
	right_container.theme_override_constants.separation = 5
	
	parent.add_child(left_container)
	parent.add_child(right_container)
	# 비주얼라이저 컨테이너들이 전경 비디오보다는 뒤, 배경 블러보다는 앞에 오도록 트리 순서 정렬
	if bg_player:
		var bg_idx = bg_player.get_index()
		parent.move_child(left_container, bg_idx + 1)
		parent.move_child(right_container, bg_idx + 2)
		
	# 컨테이너 내부에 반투명 네온 화이트 바(ColorRect)들을 동적 생성
	for i in range(BAR_COUNT):
		var left_bar = ColorRect.new()
		left_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_bar.size_flags_vertical = Control.SIZE_SHRINK_END # 하단에서부터 솟아나도록 설정
		left_bar.color = Color(1.0, 1.0, 1.0, 0.38) # 반투명한 은은한 화이트 컬러
		left_bar.custom_minimum_size = Vector2(4, 2)
		left_container.add_child(left_bar)
		left_bars.append(left_bar)
		
		var right_bar = ColorRect.new()
		right_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_bar.size_flags_vertical = Control.SIZE_SHRINK_END
		right_bar.color = Color(1.0, 1.0, 1.0, 0.38)
		right_bar.custom_minimum_size = Vector2(4, 2)
		right_container.add_child(right_bar)
		right_bars.append(right_bar)


func _process(delta: float) -> void:
	if not bga_loaded or stream == null:
		return

	# A. [실시간 비디오 실제 종횡비 추출 및 화면 맞춤 보정]
	if ratio_container and is_playing():
		var tex = get_video_texture()
		if tex:
			var tex_size = tex.get_size()
			if tex_size.y > 0:
				var current_ratio = tex_size.x / tex_size.y
				if abs(ratio_container.ratio - current_ratio) > 0.01:
					ratio_container.ratio = current_ratio
					print("[VideoStreamPlayer] 동적 종횡비 보정 완료: ", tex_size.x, "x", tex_size.y, " (비율: ", current_ratio, ")")
					
	# B. 듀얼 VideoStreamPlayer (배경 및 전경) 싱크로 매칭
	if bg_player and bga_loaded:
		if bg_player.stream != stream:
			bg_player.stream = stream
		if bg_player.paused != paused:
			bg_player.paused = paused
		if bg_player.is_playing() != is_playing():
			if is_playing():
				bg_player.play()
			else:
				bg_player.stop()
		# 싱크가 벌어지는 현상을 막기 위해 실시간 정밀 타임 피팅
		if is_playing() and abs(bg_player.get_stream_position() - get_stream_position()) > 0.15:
			bg_player.set_stream_position(get_stream_position())
			
	# C. 실시간 오디오 분석 및 비주얼라이저 연동
	if spectrum_analyzer and left_bars.size() > 0 and is_playing():
		_animate_audio_visualizer(delta)
		
	var audio = Global.audio_player
	if audio == null:
		return
		
	# D. 일시정지 상태 동기화
	if paused != audio.stream_paused:
		paused = audio.stream_paused
		
	# E. 재생 시작 타이밍 동기화 (Start-up Sync)
	if not bga_started:
		if audio.playing:
			var audio_pos = audio.get_playback_position()
			if audio_pos > 0.0:
				play()
				bga_started = true
				print("[VideoStreamPlayer] BGA 자동 시작!")
		return


func _animate_audio_visualizer(delta: float) -> void:
	# 오디오 분석을 위해 주파수 밴드 범위(20Hz ~ 12000Hz) 설정
	var min_freq = 20.0
	var max_freq = 12000.0
	
	# 주파수 축의 대수적 분할 계산용 로그 스케일링 상수
	var log_min = log(min_freq)
	var log_max = log(max_freq)
	
	for i in range(BAR_COUNT):
		# 주파수 범위를 바 개수에 맞춰 고르게 분할 (대수 스케일링으로 음악 대역 고루 분포)
		var t_low = float(i) / BAR_COUNT
		var t_high = float(i + 1) / BAR_COUNT
		
		var freq_low = exp(log_min + (log_max - log_min) * t_low)
		var freq_high = exp(log_min + (log_max - log_min) * t_high)
		
		# 해당 대역폭의 음량 Magnitude 추출
		var magnitude = spectrum_analyzer.get_magnitude_for_frequency_range(freq_low, freq_high).length()
		
		# 0.0 ~ 1.0 범위로 에너지 정규화 및 감도 가속 보정 (어쿠스틱 감쇠 계수 적용)
		var energy = clamp(magnitude * 45.0, 0.0, 1.0)
		
		# 실시간 타겟 진폭 계산
		var target_height = energy * MAX_BAR_HEIGHT
		
		# 바들의 높이가 급격히 내려앉아 눈이 피로하지 않도록 부드러운 하강 보간(lerp) 적용
		if target_height > bar_heights[i]:
			bar_heights[i] = lerp(bar_heights[i], target_height, 25.0 * delta)
		else:
			bar_heights[i] = lerp(bar_heights[i], target_height, 12.0 * delta)
			
		# 계산된 주파수 진폭을 좌우 비주얼라이저 바들의 높이에 실시간 대입
		var final_h = max(2.0, bar_heights[i])
		left_bars[i].custom_minimum_size.y = final_h
		right_bars[i].custom_minimum_size.y = final_h
