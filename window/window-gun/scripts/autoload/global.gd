extends Node

signal score_changed(new_score: int)
signal combo_changed(new_combo: int)

var score := 0
var combo := 0
var time: float = 0.0
var music_titles : Array
var selected_music: String = ""
var music_offset: float = 0.0

var audio_player: AudioStreamPlayer = null

func _ready() -> void:
	reset_run()
	music_titles = get_folder_list("res://assets/musics/")

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
	time = 0.0
	score_changed.emit(score)
	combo_changed.emit(combo)


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func add_combo() -> void:
	combo += 1
	combo_changed.emit(combo)


func reset_combo() -> void:
	combo = 0
	combo_changed.emit(combo)
