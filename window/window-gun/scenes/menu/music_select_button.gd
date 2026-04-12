extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var original = $MusicSelectButton
	var copy = original.duplicate()
	var music_num = Global.music_data
	print(music_num[])
	for i in range(5):
		copy = original.duplicate()
		copy.position += Vector2(0, 170) 
		add_child(copy)
		original = copy
		
		



func duplicate_control_node():
	var original = $MusicSelectButton
	var copy = original.duplicate()
	copy.position += Vector2(0, 170) 
	add_child(copy)
