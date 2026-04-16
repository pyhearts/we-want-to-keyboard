extends TextureRect


@export var next_scene : PackedScene



func _input(event):
	if event.is_pressed():
		if next_scene:
			get_tree().change_scene_to_packed(next_scene)
	
