extends Node

signal score_changed(new_score: int)
signal combo_changed(new_combo: int)
signal camera_shake_requested(intensity: float, duration: float)
signal judgment_added(judgment_type: String)


var score = 0
var combo = 0
var max_combo = 0
var time: float = 0.0
var music_titles : Array
var selected_music: String = ""
var music_sort_order: String = "title"
var music_offset: float = 0.0
var exhibition_fast_turnover: bool = true
var result_auto_return_enabled: bool = true
var result_auto_return_seconds: float = 8.0
var result_skip_roulette: bool = true
var editor_test_start_time: float = 0.0
var is_editor_test_mode: bool = false
var is_region_play_mode: bool = false
var region_play_start_time: float = -1.0
var region_play_end_time: float = -1.0
var region_play_segments: Array = []
var max_note_speed: float = 4000.0
var note_limit_seconds_interval: float = 0.8 # ?몃옒 湲몄씠瑜??섎닃 珥??⑥쐞 媛?(?명듃 ?쒗븳 湲곗? 媛꾧꺽)
var min_note_interval: float = 0.07 # 理쒖냼 ?명듃 ?쒓컙 媛꾧꺽 (TOO_CLOSE ?먯젙 湲곗?)
var max_note_distance: float = 800.0 # ?댁쟾 ?명듃???理쒕? ?덉슜 嫄곕━ (px)
var limit_placement_distance: bool = false # ?댁쟾 ?명듃 湲곗? 諛곗튂 ?곸뿭 媛뺤젣 ?쒗븳 ?щ?

# 1,000,000???ㅼ??쇰쭅???꾪븳 ?먯닔 怨꾩궛 蹂??
var judgment_perfect_margin: float = 0.45
var note_hit_radius: float = 1.0
var editor_min_placement_radius: float = 120.0
var editor_note_block_radius: float = 108.0
var editor_timeline_note_preview_steps: float = 3.0
var editor_placement_guide_grow_delay_steps: float = 2.0
var editor_placement_guide_fade_duration: float = 0.3

var max_base_score: int = 100
var current_base_score: int = 0

# ?먯젙 ?듦퀎 媛쒖닔 移댁슫??
var perfect_count: int = 0
var great_count: int = 0
var good_count: int = 0
var near_count: int = 0
var miss_count: int = 0

var audio_player: AudioStreamPlayer = null

# 寃뚯엫 ?뚮젅???곗텧 ?ㅼ젙 蹂?섎뱾 (濡쒖뺄 ????곕룞)
var enable_camera_shake: bool = true
var camera_shake_intensity: float = 1.0 # 0.0 ~ 2.0
var enable_sfx: bool = true
var enable_scene_transition_sfx: bool = true
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
	# 李곗쭊 鍮꾪봽/?대옪 ?寃⑷컧 ?④낵??WAV ?ㅼ떆媛??앹꽦
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

		# 珥덈컲 10ms??媛뺣젹???몃옖吏?명듃 ?ㅻ깄 ?몄씠利?異붽??섏뿬 ?寃⑷컧 洹밸???
		if t < 0.01:
			var noise = randf_range(-1.0, 1.0) * 0.45 * (1.0 - t/0.01)
			sample_val = clamp(sample_val + noise, -1.0, 1.0)

		var int_val = int(sample_val * 32767.0)
		data.encode_s16(i * 2, int_val)

	hit_sfx_stream.data = data

	# ?④낵??以묒꺽 ?ъ깮???꾪븳 ?대━?щ땲 ?ㅻ뵒??? 援ъ꽦 (SFX 踰꾩뒪媛 ?놁쓣 寃쎌슦 Master濡??덉쟾???대갚)
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

	# ??먯꽌 ?ш퀬 ?덈뒗 ?ㅻ뵒???뚮젅?댁뼱瑜?李얠븘 ?ъ깮
	for asp in sfx_players:
		if not asp.playing:
			asp.volume_db = linear_to_db(sfx_volume)
			asp.play()
			return

	# ?꾨? 諛붿걯?ㅻ㈃ 泥?踰덉㎏ ?뚮젅?댁뼱瑜?媛뺤젣 ?ъ떆??(?쒗솚 ?留?
	var first_asp = sfx_players[0]
	first_asp.volume_db = linear_to_db(sfx_volume)
	first_asp.play()



func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("settings", "enable_camera_shake", enable_camera_shake)
	config.set_value("settings", "camera_shake_intensity", camera_shake_intensity)
	config.set_value("settings", "enable_sfx", enable_sfx)
	config.set_value("settings", "enable_scene_transition_sfx", enable_scene_transition_sfx)
	config.set_value("settings", "sfx_volume", sfx_volume)
	config.set_value("settings", "note_effect_level", note_effect_level)
	config.set_value("settings", "judgment_text_pos", judgment_text_pos)
	config.set_value("settings", "judgment_line_width", judgment_line_width)
	config.set_value("settings", "particle_intensity", particle_intensity)
	config.set_value("settings", "effect_offset", effect_offset)
	config.set_value("settings", "music_sort_order", music_sort_order)
	config.set_value("settings", "exhibition_fast_turnover", exhibition_fast_turnover)
	config.set_value("settings", "result_auto_return_enabled", result_auto_return_enabled)
	config.set_value("settings", "result_auto_return_seconds", result_auto_return_seconds)
	config.set_value("settings", "result_skip_roulette", result_skip_roulette)
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
		enable_scene_transition_sfx = config.get_value("settings", "enable_scene_transition_sfx", true)
		sfx_volume = config.get_value("settings", "sfx_volume", 0.5)
		note_effect_level = config.get_value("settings", "note_effect_level", 1)
		judgment_text_pos = config.get_value("settings", "judgment_text_pos", "note")
		judgment_line_width = config.get_value("settings", "judgment_line_width", 4.0)
		particle_intensity = config.get_value("settings", "particle_intensity", 1.0)
		effect_offset = config.get_value("settings", "effect_offset", Vector2(-220.0, -90.0))
		music_sort_order = config.get_value("settings", "music_sort_order", "title")
		if music_sort_order not in ["title", "duration"]:
			music_sort_order = "title"
		exhibition_fast_turnover = config.get_value("settings", "exhibition_fast_turnover", true)
		result_auto_return_enabled = config.get_value("settings", "result_auto_return_enabled", true)
		result_auto_return_seconds = max(float(config.get_value("settings", "result_auto_return_seconds", 8.0)), 0.0)
		result_skip_roulette = config.get_value("settings", "result_skip_roulette", true)
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
		if path == MUSIC_BASE_PATH:
			folder_array = _sort_music_folders(folder_array)
	else:
		print("?뚯씪 寃쎈줈 李얘린 ?ㅽ뙣", path)
	return folder_array


func _sort_music_folders(folders: Array) -> Array:
	var rows: Array = []
	for folder in folders:
		var song_name = str(folder)
		rows.append({
			"name": song_name,
			"title": _get_music_sort_title(song_name),
			"duration": _get_music_sort_play_duration(song_name)
		})

	rows.sort_custom(func(a, b):
		if music_sort_order == "duration":
			var duration_a = float(a.get("duration", 0.0))
			var duration_b = float(b.get("duration", 0.0))
			if not is_equal_approx(duration_a, duration_b):
				return duration_a < duration_b
		var title_a = str(a.get("title", a.get("name", ""))).to_lower()
		var title_b = str(b.get("title", b.get("name", ""))).to_lower()
		if title_a != title_b:
			return title_a < title_b
		return str(a.get("name", "")) < str(b.get("name", ""))
	)

	var sorted_folders: Array = []
	for row in rows:
		sorted_folders.append(row.get("name", ""))
	return sorted_folders


func _get_music_sort_title(song_name: String) -> String:
	var res_path = get_music_res_path(song_name)
	if FileAccess.file_exists(res_path):
		var music_res = load(res_path)
		if music_res and music_res.get("title") != null and str(music_res.get("title")).strip_edges() != "":
			return str(music_res.get("title"))
	return song_name


func _get_music_sort_play_duration(song_name: String) -> float:
	var region = load_region_play_settings(song_name)
	var segments = region.get("segments", [])
	if segments is Array and not segments.is_empty():
		var total_region_duration = 0.0
		for segment in segments:
			if not segment is Dictionary:
				continue
			var start_time = float(segment.get("start", -1.0))
			var end_time = float(segment.get("end", -1.0))
			if start_time >= 0.0 and end_time > start_time:
				total_region_duration += end_time - start_time
		if total_region_duration > 0.0:
			return total_region_duration

	var res_path = get_music_res_path(song_name)
	if FileAccess.file_exists(res_path):
		var music_res = load(res_path)
		if music_res and music_res.get("audio_stream"):
			return float(music_res.get("audio_stream").get_length())
	return 0.0


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
	near_count = 0
	miss_count = 0
	score_changed.emit(score)
	combo_changed.emit(combo)


func add_score(amount: int) -> void:
	current_base_score += amount
	if current_base_score < 0:
		current_base_score = 0
	# 100留뚯젏 留뚯젏?쇰줈 ?ㅼ떆媛?蹂댁젙 怨꾩궛
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


# ?먯젙 移댁슫???섏쭛 ?⑥닔
func add_judgment(judgment_type: String) -> void:
	match judgment_type.to_lower():
		"perfect":
			perfect_count += 1
		"great":
			great_count += 1
		"good":
			good_count += 1
		"near":
			near_count += 1
		"miss":
			miss_count += 1
	judgment_added.emit(judgment_type)


# 1,000,000???ㅼ??쇰쭅 怨꾩궛??
func calculate_scaled_score() -> int:
	if max_base_score <= 0:
		return 0
	var ratio = float(current_base_score) / float(max_base_score)
	# 0~100留????ъ씠濡?蹂댁젙
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

func load_region_play_settings(song_name: String) -> Dictionary:
	var result = {
		"enabled": false,
		"start": -1.0,
		"end": -1.0,
		"segments": []
	}
	if song_name == "":
		return result
	var chart_path = get_music_chart_path(song_name)
	if not FileAccess.file_exists(chart_path):
		return result
	var file = FileAccess.open(chart_path, FileAccess.READ)
	if file == null:
		return result
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return result
	var editor_data = parsed.get("editor", {})
	if not editor_data is Dictionary:
		return result

	var segments: Array = []
	var regions_data = editor_data.get("regions", [])
	if regions_data is Array:
		for region in regions_data:
			if not region is Dictionary or not bool(region.get("enabled", true)):
				continue
			var start_time = float(region.get("start", -1.0))
			var end_time = float(region.get("end", -1.0))
			if start_time >= 0.0 and end_time > start_time:
				segments.append({"start": start_time, "end": end_time})

	if segments.is_empty():
		var region_data = editor_data.get("region", {})
		if region_data is Dictionary:
			var start_time = float(region_data.get("start", -1.0))
			var end_time = float(region_data.get("end", -1.0))
			if start_time >= 0.0 and end_time > start_time:
				segments.append({"start": start_time, "end": end_time})

	segments = merge_region_segments(segments)
	if segments.size() > 0:
		result["enabled"] = true
		result["start"] = float(segments[0]["start"])
		result["end"] = float(segments[segments.size() - 1]["end"])
		result["segments"] = segments
	return result

func merge_region_segments(segments: Array) -> Array:
	if segments.size() <= 1:
		return segments
	segments.sort_custom(func(a, b): return float(a.get("start", 0.0)) < float(b.get("start", 0.0)))
	var merged: Array = []
	for segment in segments:
		if not segment is Dictionary:
			continue
		var start_time = float(segment.get("start", -1.0))
		var end_time = float(segment.get("end", -1.0))
		if start_time < 0.0 or end_time <= start_time:
			continue
		if merged.is_empty():
			merged.append({"start": start_time, "end": end_time})
			continue
		var last_segment = merged[merged.size() - 1]
		var last_end = float(last_segment.get("end", -1.0))
		if start_time <= last_end + 0.001:
			last_segment["end"] = max(last_end, end_time)
		else:
			merged.append({"start": start_time, "end": end_time})
	return merged

func apply_region_play_settings(song_name: String) -> void:
	var region = load_region_play_settings(song_name)
	is_region_play_mode = bool(region.get("enabled", false))
	region_play_start_time = float(region.get("start", -1.0))
	region_play_end_time = float(region.get("end", -1.0))
	region_play_segments = region.get("segments", [])
