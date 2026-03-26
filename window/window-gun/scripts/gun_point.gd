extends TextureButton

var speed = 100
@onready var gun_point: TextureButton = $"."


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	spawn_point()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func spawn_point():
	# 1. 랜덤 좌표 계산
	var ran_x = randi_range(200, 1400)
	var ran_y = randi_range(200, 700)
	
	gun_point.position = Vector2(ran_x,ran_y)
	
	
