extends TextureRect

@export var next_scene: PackedScene

const CHART_EDITOR_SCENE = "res://scenes/menu/chart_editor.tscn"
const SETTINGS_SCENE = "res://scenes/menu/settings.tscn"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F4:
			get_viewport().set_input_as_handled()
			get_tree().change_scene_to_file(CHART_EDITOR_SCENE)
			return
		elif event.keycode == KEY_F10:
			get_viewport().set_input_as_handled()
			get_tree().change_scene_to_file(SETTINGS_SCENE)
			return

	if _is_escape_event(event):
		get_tree().quit()
		return


	if _is_start_event(event):
		_change_scene()


func _is_escape_event(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE


func _is_start_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	return false


func _change_scene() -> void:
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
