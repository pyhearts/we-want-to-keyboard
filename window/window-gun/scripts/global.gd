extends Node

var score = 0
var combo = 0
var time: float = 0.0

func _ready() -> void:
	time = 0.0

func _process(delta: float) -> void:
	time += delta
