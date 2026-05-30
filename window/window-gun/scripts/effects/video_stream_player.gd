extends VideoStreamPlayer

const MUSIC_BASE_PATH = "res://assets/musics/"

var bga_loaded: bool = false
var bga_started: bool = false

func _ready() -> void:
	# 1. 저사양 옵션 필터링 (Object.get() 인자 개수 오류 완벽 해결)
	var is_bga_enabled = true
	if "enable_bga" in Global:
		is_bga_enabled = Global.enable_bga
		
	if not is_bga_enabled:
		visible = false
		return
		
	visible = true
	volume_db = -80.0  # 자체 사운드 음소거 (성능 향상 필수)
	audio_track = -1
	
	if Global.selected_music == "":
		return
		
	# 2. 선택된 곡의 폴더 내 bga.mp4 동적 파일 로드
	# 예: res://assets/musics/Flower Rocket/bga.mp4
	var bga_path = MUSIC_BASE_PATH + Global.selected_music + "/bga.mp4"
	
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

func _process(delta: float) -> void:
	if not bga_loaded or stream == null:
		return
		
	var audio = Global.audio_player
	if audio == null:
		return
		
	# A. 일시정지 상태 실시간 동기화
	if paused != audio.stream_paused:
		paused = audio.stream_paused
		
	# B. 정밀 시작 동기화 (Start-up Sync)
	# 오디오가 미세하게라도 소리를 뿜고 0초를 넘긴 타이밍에 완벽 동시 출발
	if not bga_started:
		if audio.playing:
			var audio_pos = audio.get_playback_position()
			if audio_pos > 0.0:
				play()
				bga_started = true
				print("[VideoStreamPlayer] BGA 연동 시작!")
		return
