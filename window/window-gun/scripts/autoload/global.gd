extends Node

var score := 0
var combo := 0
var time: float = 0.0
var music_titles := ["R", "HEELO", "MEGALOVANIA"]
var selected_music = ""

func _ready() -> void:
	reset_run()


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
