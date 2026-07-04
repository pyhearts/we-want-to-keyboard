extends Node

signal score_changed(new_score: int)
signal combo_changed(new_combo: int)
signal camera_shake_requested(intensity: float, duration: float)


var score = 0
var combo = 0
var max_combo = 0
var time: float = 0.0
var music_titles : Array
var selected_music: String = ""
var music_offset: float = 0.0
var editor_test_start_time: float = 0.0
var is_editor_test_mode: bool = false
var max_note_speed: float = 4000.0
var note_limit_seconds_interval: float = 0.8 # 노래 길이를 나눌 초 단위 값 (노트 제한 기준 간격)
var min_note_interval: float = 0.07 # 최소 노트 시간 간격 (TOO_CLOSE 판정 기준)
var max_note_distance: float = 800.0 # 이전 노트와의 최대 허용 거리 (px)
var limit_placement_distance: bool = false # 이전 노트 기준 배치 영역 강제 제한 여부

# 1,000,000점 스케일링을 위한 점수 계산 변수
var judgment_perfect_margin: float = 0.45
var note_hit_radius: float = 1.0
var editor_min_placement_radius: float = 120.0
var editor_note_block_radius: float = 108.0
var editor_timeline_note_preview_steps: float = 3.0
var editor_placement_guide_grow_delay_steps: float = 2.0
var editor_placement_guide_fade_duration: float = 0.3

var max_base_score: int = 100
var current_base_score: int = 0

# 판정 통계 개수 카운트
var perfect_count: int = 0
var great_count: int = 0
var good_count: int = 0
var miss_count: int = 0

var audio_player: AudioStreamPlayer = null

# 게임 플레이 연출 설정 변수들 (로컬 저장 연동)
var enable_camera_shake: bool = true
var camera_shake_intensity: float = 1.0 # 0.0 ~ 2.0
var enable_sfx: bool = true
var sfx_volume: float = 0.5 # 0.0 ~ 1.0
var note_effect_level: int = 1 # 0: Normal, 1: Rich, 2: Extreme
var judgment_text_pos: String = "note" # "note" or "center"
var judgment_line_width: float = 4.0 # 0.0 ~ 12.0
var particle_intensity: float = 1.0 # 0.0 ~ 2.0
var effect_offset: Vector2 = Vector2(-220.0, -90.0)

var SAVE_PATH: String = "user://settings.cfg"

var hit_sfx_stream: AudioStreamWAV = null

var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS = 8


func _ready() -> void:
	if OS.has_feature("editor") or OS.is_debug_build():
		SAVE_PATH = "res://settings.cfg"
	else:
		SAVE_PATH = "user://settings.cfg"

	load_settings()
	_init_sfx()
	reset_run()
	music_titles = get_folder_list("res://assets/musics/")


func _init_sfx() -> void:
	# 찰진 비프/클랩 타격감 효과음 WAV 실시간 생성
	hit_sfx_stream = AudioStreamWAV.new()
	hit_sfx_stream.format = AudioStreamWAV.FORMAT_16_BITS
	hit_sfx_stream.mix_rate = 44100
	hit_sfx_stream.stereo = false
	
	var sample_rate = 44100.0
	var duration = 0.08 # 80ms
	var num_samples = int(duration * sample_rate)
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var freq = lerp(1200.0, 200.0, float(i) / num_samples)
		var amplitude = exp(-25.0 * t)
		var sample_val = sin(t * freq * 2.0 * PI) * amplitude
		
		# 초반 10ms에 강렬한 트랜지언트 스냅 노이즈 추가하여 타격감 극대화
		if t < 0.01:
			var noise = randf_range(-1.0, 1.0) * 0.45 * (1.0 - t/0.01)
			sample_val = clamp(sample_val + noise, -1.0, 1.0)
			
		var int_val = int(sample_val * 32767.0)
		data.encode_s16(i * 2, int_val)
		
	hit_sfx_stream.data = data
	
	# 효과음 중첩 재생을 위한 폴리포니 오디오 풀 구성 (SFX 버스가 없을 경우 Master로 안전한 폴백)
	for i in range(MAX_SFX_PLAYERS):
		var asp = AudioStreamPlayer.new()
		asp.stream = hit_sfx_stream
		if AudioServer.get_bus_index("SFX") != -1:
			asp.bus = "SFX"
		else:
			asp.bus = "Master"
		add_child(asp)
		sfx_players.append(asp)


func play_hit_sound() -> void:
	if not enable_sfx:
		return
	
	# 풀에서 쉬고 있는 오디오 플레이어를 찾아 재생
	for asp in sfx_players:
		if not asp.playing:
			asp.volume_db = linear_to_db(sfx_volume)
			asp.play()
			return
	
	# 전부 바쁘다면 첫 번째 플레이어를 강제 재시작 (순환 풀링)
	var first_asp = sfx_players[0]
	first_asp.volume_db = linear_to_db(sfx_volume)
	first_asp.play()



func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("settings", "enable_camera_shake", enable_camera_shake)
	config.set_value("settings", "camera_shake_intensity", camera_shake_intensity)
	config.set_value("settings", "enable_sfx", enable_sfx)
	config.set_value("settings", "sfx_volume", sfx_volume)
	config.set_value("settings", "note_effect_level", note_effect_level)
	config.set_value("settings", "judgment_text_pos", judgment_text_pos)
	config.set_value("settings", "judgment_line_width", judgment_line_width)
	config.set_value("settings", "particle_intensity", particle_intensity)
	config.set_value("settings", "effect_offset", effect_offset)
	config.set_value("settings", "max_note_speed", max_note_speed)
	config.set_value("settings", "min_note_interval", min_note_interval)
	config.set_value("settings", "max_note_distance", max_note_distance)
	config.set_value("settings", "limit_placement_distance", limit_placement_distance)
	config.set_value("settings", "judgment_perfect_margin", judgment_perfect_margin)
	config.set_value("settings", "note_hit_radius", note_hit_radius)
	config.set_value("settings", "editor_min_placement_radius", editor_min_placement_radius)
	config.set_value("settings", "editor_note_block_radius", editor_note_block_radius)
	config.set_value("settings", "editor_timeline_note_preview_steps", editor_timeline_note_preview_steps)
	config.set_value("settings", "editor_placement_guide_grow_delay_steps", editor_placement_guide_grow_delay_steps)
	config.set_value("settings", "editor_placement_guide_fade_duration", editor_placement_guide_fade_duration)
	config.save(SAVE_PATH)
	print("Settings saved to: ", SAVE_PATH)


func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		enable_camera_shake = config.get_value("settings", "enable_camera_shake", true)
		camera_shake_intensity = config.get_value("settings", "camera_shake_intensity", 1.0)
		enable_sfx = config.get_value("settings", "enable_sfx", true)
		sfx_volume = config.get_value("settings", "sfx_volume", 0.5)
		note_effect_level = config.get_value("settings", "note_effect_level", 1)
		judgment_text_pos = config.get_value("settings", "judgment_text_pos", "note")
		judgment_line_width = config.get_value("settings", "judgment_line_width", 4.0)
		particle_intensity = config.get_value("settings", "particle_intensity", 1.0)
		effect_offset = config.get_value("settings", "effect_offset", Vector2(-220.0, -90.0))
		max_note_speed = config.get_value("settings", "max_note_speed", 4000.0)
		min_note_interval = config.get_value("settings", "min_note_interval", 0.07)
		max_note_distance = config.get_value("settings", "max_note_distance", 800.0)
		limit_placement_distance = config.get_value("settings", "limit_placement_distance", false)
		judgment_perfect_margin = config.get_value("settings", "judgment_perfect_margin", 0.45)
		note_hit_radius = clamp(float(config.get_value("settings", "note_hit_radius", 1.0)), 0.0, 1.0)
		editor_min_placement_radius = config.get_value("settings", "editor_min_placement_radius", 120.0)
		editor_note_block_radius = config.get_value("settings", "editor_note_block_radius", 108.0)
		editor_timeline_note_preview_steps = config.get_value("settings", "editor_timeline_note_preview_steps", 3.0)
		editor_placement_guide_grow_delay_steps = config.get_value("settings", "editor_placement_guide_grow_delay_steps", 2.0)
		editor_placement_guide_fade_duration = config.get_value("settings", "editor_placement_guide_fade_duration", 0.3)
		print("Settings loaded successfully.")
	else:
		print("No settings file found, using defaults.")


func get_folder_list(path: String) -> Array:
	var folder_array = []
	var dir = DirAccess.open(path)
	
	if dir:
		var folders = dir.get_directories()
		folder_array = Array(folders)
	else:
		print("파일 경로 찾기 실패", path)
	return folder_array


func _process(delta: float) -> void:
	time += delta


func reset_run() -> void:
	score = 0
	combo = 0
	max_combo = 0
	time = 0.0
	current_base_score = 0
	perfect_count = 0
	great_count = 0
	good_count = 0
	miss_count = 0
	score_changed.emit(score)
	combo_changed.emit(combo)


func add_score(amount: int) -> void:
	current_base_score += amount
	if current_base_score < 0:
		current_base_score = 0
	# 100만점 만점으로 실시간 보정 계산
	score = calculate_scaled_score()
	score_changed.emit(score)


func add_combo() -> void:
	combo += 1
	if combo > max_combo:
		max_combo = combo
	combo_changed.emit(combo)


func reset_combo() -> void:
	combo = 0
	combo_changed.emit(combo)


# 판정 카운트 수집 함수
func add_judgment(judgment_type: String) -> void:
	match judgment_type.to_lower():
		"perfect":
			perfect_count += 1
		"great":
			great_count += 1
		"good":
			good_count += 1
		"miss":
			miss_count += 1


# 1,000,000점 스케일링 계산식
func calculate_scaled_score() -> int:
	if max_base_score <= 0:
		return 0
	var ratio = float(current_base_score) / float(max_base_score)
	# 0~100만 점 사이로 보정
	return int(clamp(ratio * 1000000.0, 0.0, 1000000.0))

const MUSIC_BASE_PATH = "res://assets/musics/"

# Helper functions to build clean and centralized resource paths
func get_music_folder_path(song_name: String) -> String:
	return MUSIC_BASE_PATH + song_name + "/"

func get_music_audio_path(song_name: String) -> String:
	return get_music_folder_path(song_name) + song_name + ".mp3"

func get_music_jacket_path(song_name: String) -> String:
	return get_music_folder_path(song_name) + "img.png"

func get_music_chart_path(song_name: String) -> String:
	return get_music_folder_path(song_name) + "chart.json"

func get_music_res_path(song_name: String) -> String:
	return get_music_folder_path(song_name) + "Res.tres"
