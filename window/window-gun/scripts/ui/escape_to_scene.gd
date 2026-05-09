extends Control

@export_file("*.tscn") var next_scene_path := ""


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if next_scene_path != "":
			get_tree().change_scene_to_file(next_scene_path)
