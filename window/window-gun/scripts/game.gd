extends Control

@onready var gun_point: Control = $GunPoint

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#$GunPoint.spawn_point()
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _input(event):
	# ui_accept 액션(Godot 기본 설정: 스페이스바 또는 엔터키)이 눌렸을 때 실행됩니다.
	if event.is_action_pressed("ui_accept"):
		
		# 자식 노드가 정상적으로 존재하고, rng_point 함수를 가지고 있는지 확인한 후 실행합니다.
		if gun_point and gun_point.has_method("rng_point"):
			gun_point.rng_point()
			print("자식 노드의 rng_point 함수가 실행되었습니다!")
