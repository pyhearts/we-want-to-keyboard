extends TextureRect

@export var max_tilt_angle := 2.0
@export var lerp_speed := 5.0


func _process(delta: float) -> void:
	var screen_center := get_viewport_rect().size / 2.0
	var mouse_offset := (get_global_mouse_position() - screen_center) / screen_center
	var target_rotation := mouse_offset.x * max_tilt_angle
	rotation_degrees = lerp(rotation_degrees, target_rotation, lerp_speed * delta)
