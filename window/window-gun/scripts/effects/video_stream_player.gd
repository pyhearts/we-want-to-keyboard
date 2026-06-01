extends VideoStreamPlayer

const MUSIC_BASE_PATH = "res://assets/musics/"

var bga_loaded: bool = false
var bga_started: bool = false
var ratio_container: AspectRatioContainer = null

# --- 배경 연출 및 비주얼라이저 관련 변수 ---
var bg_player: VideoStreamPlayer = null

# 동적 오토 게인 감도 조절용 볼륨 피크 감지 변수 (꽉 참 및 안 움직임 원천 예방)

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
	ratio_container.layout_mode = 1
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
		


func _process(_delta: float) -> void:
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
