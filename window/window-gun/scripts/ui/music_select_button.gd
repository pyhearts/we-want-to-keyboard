extends TextureButton

@export var next_scene: PackedScene = preload("res://scenes/game/game.tscn")
@onready var label: Label = $Label


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
