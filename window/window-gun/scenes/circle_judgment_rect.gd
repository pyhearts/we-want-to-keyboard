extends TextureRect

@onready var circle_judgment: TextureRect = $"."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	circle_judgment.pivot_offset = circle_judgment.size / 2
	circle_judgment.size = Vector2(2000,2000)
	 


var a = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	a += delta
	
	print(delta)
	if circle_judgment.size[1] > 1080:
		circle_judgment.size = Vector2(circle_judgment.size[0]-10, circle_judgment.size[0]-10)
