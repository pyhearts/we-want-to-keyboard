extends VideoStreamPlayer

const MUSIC_BASE_PATH = "res://assets/musics/"

var bga_loaded: bool = false
var bga_started: bool = false
var ratio_container: AspectRatioContainer = null

func _ready() -> void:
	# 1. BGA 활성화 여부 세팅
	var is_bga_enabled = true
	if "enable_bga" in Global:
		is_bga_enabled = Global.enable_bga
		
	if not is_bga_enabled:
		visible = false
		return
		
	# 2. AspectRatioContainer 마스킹 랩핑 자동 생성 (비율 왜곡 방지 및 화면 맞춤)
	_setup_aspect_ratio_wrapper()
	
	visible = true
	volume_db = -80.0  # 자체 사운드 음소거 (성능 극대화)
	audio_track = -1
	expand = true      # 전체 영역으로 늘어나도록 설정 (컨테이너 내에서 비율을 유지하며 맞춤)
	
	if Global.selected_music == "":
		return
		
	# 3. OGV 동적 로딩
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
	# 이미 랩핑되어 있다면 중복 실행 차단
	if get_parent() is AspectRatioContainer and get_parent().name == "BgaRatioContainer":
		ratio_container = get_parent()
		return
		
	# 1. AspectRatioContainer 생성
	ratio_container = AspectRatioContainer.new()
	ratio_container.name = "BgaRatioContainer"
	ratio_container.stretch_mode = AspectRatioContainer.STRETCH_FIT
	ratio_container.ratio = 16.0 / 9.0 # 기본 16:9 비율
	ratio_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 2. 현재 VideoStreamPlayer의 레이아웃 설정을 AspectRatioContainer로 이전
	# 2. BGA를 화면 전체 크기(Full Screen Rect) 및 중앙 정렬로 강제 설정
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
	
	# 3. 씬 트리 재배치
	var orig_parent = get_parent()
	if orig_parent:
		var orig_index = get_index()
		orig_parent.add_child(ratio_container)
		orig_parent.move_child(ratio_container, orig_index)
		
		# 우리(VideoStreamPlayer)를 컨테이너 안으로 이동
		orig_parent.remove_child(self)
		ratio_container.add_child(self)
		
		# 우리 레이아웃은 컨테이너 안에서 꽉 차도록 설정
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


func _process(delta: float) -> void:
	if not bga_loaded or stream == null:
		return

	# A. [실시간 비디오 실제 종횡비 추출 및 화면 맞춤 보정]
	# 동기화 지연이나 시작 지연에 영향받지 않도록 최상단에서 상시 종횡비 보정
	if ratio_container and is_playing():
		var tex = get_video_texture()
		if tex:
			var tex_size = tex.get_size()
			if tex_size.y > 0:
				var current_ratio = tex_size.x / tex_size.y
				# 기존 비율과 차이가 나면 정확한 원본 비율로 갱신 (4:3, 16:9 등 늘어남 방지)
				if abs(ratio_container.ratio - current_ratio) > 0.01:
					ratio_container.ratio = current_ratio
					print("[VideoStreamPlayer] 동적 종횡비 보정 완료: ", tex_size.x, "x", tex_size.y, " (비율: ", current_ratio, ")")
					
	var audio = Global.audio_player
	if audio == null:
		return
		
	# B. 일시정지 상태 동기화
	if paused != audio.stream_paused:
		paused = audio.stream_paused
		
	# C. 재생 시작 타이밍 동기화 (Start-up Sync)
	if not bga_started:
		if audio.playing:
			var audio_pos = audio.get_playback_position()
			if audio_pos > 0.0:
				play()
				bga_started = true
				print("[VideoStreamPlayer] BGA 자동 시작!")
		return
