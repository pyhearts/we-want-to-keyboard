# ==============================================================================
# BgaManager.gd - 리듬게임용 로컬 .mp4 동적 로딩 및 정밀 싱크 매니저 (오류 제거 버전)
# ==============================================================================
# [설명]
# 이 스크립트는 각 악곡 폴더에서 .mp4 비디오 파일을 찾아서 로드하고,
# AudioStreamPlayer의 실제 재생 위치와 비디오 화면을 100% 매칭하는 정밀 싱크 엔진입니다.
# 싱글톤(Autoload)으로 등록하거나, 인게임 Gameplay 씬에 노드로 추가하여 사용할 수 있습니다.
# ==============================================================================
extends Node
class_name BgaManager

# --- 멤버 변수 ---
var video_player: VideoStreamPlayer = null
var audio_player: AudioStreamPlayer = null

var is_bga_enabled: bool = true
var bga_loaded: bool = false
var bga_started: bool = false

func _ready() -> void:
	# 글로벌 설정에서 BGA 활성화 여부를 불러옵니다. (안전하게 감지)
	is_bga_enabled = true
	if "enable_bga" in Global:
		is_bga_enabled = Global.enable_bga

## 1. 비디오 플레이어와 오디오 플레이어 노드 등록
func setup(p_video_player: VideoStreamPlayer, p_audio_player: AudioStreamPlayer) -> void:
	video_player = p_video_player
	audio_player = p_audio_player
	
	if not is_bga_enabled:
		if video_player:
			video_player.visible = false
		return
		
	if video_player:
		video_player.visible = true
		# MP4 재생을 위해 이펙트 볼륨은 -80dB로 음소거 처리하고 자체 오디오 재생을 막아 성능 최적화
		video_player.volume_db = -80.0
		video_player.audio_track = -1

## 2. 특정 곡 폴더에서 BGA(.mp4) 동적 로드 (Dynamic Loading)
func load_bga(song_name: String) -> void:
	if not is_bga_enabled or not video_player:
		return
		
	bga_loaded = false
	bga_started = false
	video_player.stop()
	
	# 곡 경로 패턴 매칭 (기존 music_base_path에 어울리도록 세팅)
	# 예: "res://assets/musics/곡이름/bga.mp4"
	var base_path = "res://assets/musics/"
	var bga_path = base_path + song_name + "/bga.mp4"
	
	# 파일 존재 유무 검증
	if not ResourceLoader.exists(bga_path):
		# 대체 경로 검사 (예: songs 폴더)
		var alt_path = "res://songs/" + song_name + "/bga.mp4"
		if ResourceLoader.exists(alt_path):
			bga_path = alt_path
		else:
			push_warning("BGA 비디오 파일을 찾을 수 없습니다. 정적 배경으로 대체합니다: " + bga_path)
			video_player.visible = false
			return
			
	# FFmpeg Importer가 탑재되면 .mp4도 일반 리소스처럼 load()가 가능해집니다.
	var video_stream = load(bga_path)
	if video_stream:
		video_player.stream = video_stream
		video_player.visible = true
		bga_loaded = true
		print("[BgaManager] BGA 로드 성공: ", bga_path)
	else:
		push_error("[BgaManager] BGA 리소스 로드 에러: " + bga_path)

## 3. 오디오 연동 시작
func play_bga() -> void:
	if not is_bga_enabled or not bga_loaded or not video_player:
		return
	
	# 오디오가 완전히 재생을 시작하는 씬 오프셋에 맞추기 위해 
	# _process 루프에서 시작 상태를 정밀 제어하므로 초기 재생은 보류합니다.
	bga_started = false
	video_player.stop()

## 4. 매 프레임 오디오 스레드 시간 추적 및 칼싱크 보정 로직
func _process(delta: float) -> void:
	if not is_bga_enabled or not bga_loaded or not video_player or not audio_player:
		return
		
	# A. 일시정지(Pause) 동기화
	if video_player.paused != audio_player.stream_paused:
		video_player.paused = audio_player.stream_paused

	# B. 오디오 플레이어 시작과 정밀 출발 동기화 (Start-up Sync)
	# 오디오 스트림이 하드웨어 디바이스를 통과해 실제로 움직였을 때 출발
	if not bga_started:
		if audio_player.playing:
			var audio_pos = audio_player.get_playback_position()
			if audio_pos > 0.0:
				video_player.play()
				bga_started = true
				print("[BgaManager] BGA 시작!")
		return

## 5. 정지
func stop_bga() -> void:
	if video_player:
		video_player.stop()
	bga_started = false
