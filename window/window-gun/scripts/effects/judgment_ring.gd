extends TextureRect

@export var default_duration := 0.8
@export var start_diameter := 2500.0

var active_tween: Tween


func _ready() -> void:
	call_deferred("start", default_duration)


func start(duration: float) -> void:
	pivot_offset = size / 2.0

	var base_width = max(size.x, 1.0)
	scale = Vector2.ONE * (start_diameter / base_width)

	if active_tween and active_tween.is_valid():
		active_tween.kill()

	active_tween = create_tween()
	active_tween.tween_property(self, "scale", Vector2.ONE, duration)
