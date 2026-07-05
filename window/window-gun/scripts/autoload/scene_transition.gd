extends CanvasLayer

@export var cover_duration := 0.35
@export var reveal_duration := 0.35

const TRANSITION_SOUND_PATHS := [
	"res://assets/sounds/scene_transition.mp3",
	"res://assets/sounds/scene_transition_dave.mp3",
	"res://assets/sounds/scene_transition_love_circulation_2.mp3",
	"res://assets/sounds/scene_transition_love_circulation.mp3",
]

var _cover: ColorRect
var _sound_player: AudioStreamPlayer
var _transition_sounds: Array[AudioStream] = []
var _is_transitioning := false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.visible = false
	add_child(_cover)
	_set_hidden_right()

	_sound_player = AudioStreamPlayer.new()
	_sound_player.bus = "Master"
	add_child(_sound_player)
	_load_transition_sounds()


func transition_to_scene(path: String) -> void:
	if _is_transitioning or path == "":
		return

	_is_transitioning = true
	_play_transition_sound()
	_cover.visible = true
	_set_hidden_right()

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(_set_cover_progress, 0.0, 1.0, cover_duration) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Failed to change scene: " + path)
		_cover.visible = false
		_is_transitioning = false
		return

	await get_tree().process_frame
	await get_tree().process_frame

	tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(_set_reveal_progress, 0.0, 1.0, reveal_duration) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	_cover.visible = false
	_set_hidden_right()
	_is_transitioning = false


func _set_cover_progress(progress: float) -> void:
	var width := get_viewport().get_visible_rect().size.x
	_cover.offset_left = lerpf(width, 0.0, progress)
	_cover.offset_right = 0.0
	_cover.offset_top = 0.0
	_cover.offset_bottom = 0.0


func _set_reveal_progress(progress: float) -> void:
	var width := get_viewport().get_visible_rect().size.x
	_cover.offset_left = lerpf(0.0, width, progress)
	_cover.offset_right = 0.0
	_cover.offset_top = 0.0
	_cover.offset_bottom = 0.0


func _set_hidden_right() -> void:
	_set_cover_progress(0.0)


func _load_transition_sounds() -> void:
	_transition_sounds.clear()
	for sound_path in TRANSITION_SOUND_PATHS:
		var stream := load(sound_path) as AudioStream
		if stream:
			_transition_sounds.append(stream)


func _play_transition_sound() -> void:
	if _sound_player == null or not Global.enable_scene_transition_sfx or _transition_sounds.is_empty():
		return

	_sound_player.stop()
	_sound_player.stream = _transition_sounds.pick_random()
	_sound_player.play()
