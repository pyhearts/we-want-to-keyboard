extends AudioStreamPlayer

const MUSIC_BASE_PATH := "res://assets/musics/"
const GLOBAL_TIMING_OFFSET := 0.6

var music_offset: float = 0.0


func _ready() -> void:
	# 전역 참조 등록
	Global.audio_player = self
	
	if _is_headless_run():
		return
	if Global.selected_music == "":
		return

	var res_path := MUSIC_BASE_PATH + Global.selected_music + "/Res.tres"
	var music_res = load(res_path)
	
	# 안전한 리소스 체크 및 오프셋 계산
	if music_res and "offset" in music_res:
		Global.music_offset = music_res.offset
		music_offset = GLOBAL_TIMING_OFFSET - music_res.offset
		print("Music offset calculated: ", music_offset, " (Global: ", Global.music_offset, ")")
	else:
		Global.music_offset = 0.0
		music_offset = GLOBAL_TIMING_OFFSET
		print("Music resource or offset not found. Using default timing.")

	if music_offset > 0.0:
		await get_tree().create_timer(music_offset).timeout

	play_selected_music(Global.selected_music)


func play_selected_music(music_name: String) -> void:
	var audio_path := MUSIC_BASE_PATH + music_name + "/" + music_name + ".mp3"
	var song = load(audio_path)
	if song:
		stream = song
		play()
		print("Music started: ", audio_path)
	else:
		push_error("Music file not found: " + audio_path)


func stop_music() -> void:
	if playing:
		stop()


func _is_headless_run() -> bool:
	return OS.has_feature("headless") or "--headless" in OS.get_cmdline_args() or "--headless-test" in OS.get_cmdline_user_args() or OS.get_environment("GODOT_HEADLESS_TEST") == "1"
