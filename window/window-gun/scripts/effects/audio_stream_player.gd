extends AudioStreamPlayer

const MUSIC_BASE_PATH := "res://assets/musics/"
const GLOBAL_TIMING_OFFSET := 0.7

var music_offset: float = 0.0


func _ready() -> void:
	if _is_headless_run():
		return
	if Global.selected_music == "":
		return

	var res_path := MUSIC_BASE_PATH + Global.selected_music + "/Res.tres"
	var music_res = load(res_path)
	Global.music_offset = music_res.offset
	if music_res and "offset" in music_res:
		music_offset =  GLOBAL_TIMING_OFFSET - music_res.offset
		print("Music offset: ", music_offset)
	else:
		music_offset = 0.0
		print("Music resource or offset not found. Using 0 seconds.")

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
