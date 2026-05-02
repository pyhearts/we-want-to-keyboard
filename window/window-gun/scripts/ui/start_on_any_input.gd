extends TextureRect

@export var next_scene: PackedScene


func _input(event: InputEvent) -> void:
	if _is_start_event(event):
		_change_scene()


func _is_start_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	return false


func _change_scene() -> void:
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
