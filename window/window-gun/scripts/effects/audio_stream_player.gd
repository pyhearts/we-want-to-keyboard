extends AudioStreamPlayer

const MUSIC_BASE_PATH = "res://assets/musics/"
const GLOBAL_TIMING_OFFSET = 0.7

var music_offset: float = 0.0


func _ready() -> void:
	# 전역 참조 등록
	Global.audio_player = self
	
	if _is_headless_run():
		return
	if Global.selected_music == "":
		return

	var res_path = MUSIC_BASE_PATH + Global.selected_music + "/Res.tres"
	var music_res = load(res_path)
	
	# 이전에 리소스 체크 및 오프셋 계산
	if music_res and "offset" in music_res:
		Global.music_offset = music_res.offset
		music_offset = GLOBAL_TIMING_OFFSET - music_res.offset
		print("Music offset calculated: ", music_offset, " (Global: ", Global.music_offset, ")")
	else:
		Global.music_offset = 0.0
		music_offset = GLOBAL_TIMING_OFFSET
		print("Music resource or offset not found. Using default timing.")

	Global.apply_region_play_settings(Global.selected_music)

	if Global.is_editor_test_mode and Global.editor_test_start_time > 0.01:
		var actual_start = max(0.0, Global.editor_test_start_time - 1.0)
		var audio_start_pos = actual_start - music_offset
		if audio_start_pos >= 0.0:
			play_selected_music(Global.selected_music, audio_start_pos)
		else:
			# 오디오 시작 시점이 미래인 경우, 남은 시간만큼 대기 후 재생 시작
			await get_tree().create_timer(-audio_start_pos).timeout
			play_selected_music(Global.selected_music, 0.0)
	elif Global.is_region_play_mode:
		var region_audio_start_pos = Global.region_play_start_time - music_offset
		if region_audio_start_pos >= 0.0:
			play_selected_music(Global.selected_music, region_audio_start_pos)
		else:
			await get_tree().create_timer(-region_audio_start_pos).timeout
			play_selected_music(Global.selected_music, 0.0)
	else:
		if music_offset > 0.0:
			await get_tree().create_timer(music_offset).timeout
			play_selected_music(Global.selected_music)
		else:
			# 오프셋 대기 시간이 없거나 마이너스인 경우 음원을 마이너스 오프셋만큼 건너뛰어 즉시 재생
			play_selected_music(Global.selected_music, -music_offset)


func play_selected_music(music_name: String, start_pos: float = 0.0) -> void:
	var audio_path = MUSIC_BASE_PATH + music_name + "/" + music_name + ".mp3"
	var song = load(audio_path)
	if song:
		stream = song
		play(start_pos)
		print("Music started: ", audio_path)
	else:
		push_error("Music file not found: " + audio_path)


func stop_music() -> void:
	if playing:
		stop()


func _is_headless_run() -> bool:
	return OS.has_feature("headless") or "--headless" in OS.get_cmdline_args() or "--headless-test" in OS.get_cmdline_user_args() or OS.get_environment("GODOT_HEADLESS_TEST") == "1"
