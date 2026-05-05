extends Node

var score := 0
var combo := 0
var time: float = 0.0
var music_titles : Array
var selected_music = ""

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


func add_score(amount: int) -> void:
	score += amount


func add_combo() -> void:
	combo += 1


func reset_combo() -> void:
	combo = 0
