extends TextureButton

@export var next_scene: PackedScene = preload("res://scenes/game/game.tscn")
@onready var label: Label = $Label


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if next_scene:
		SceneTransition.transition_to_scene(next_scene.resource_path)
