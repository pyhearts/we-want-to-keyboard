extends Node

@export var next_scene : PackedScene = preload("res://scenes/in_game/game.tscn")

func _ready():
	# 1. 부모 노드가 TextureButton인지 확인하며 가져오기
	var parent_button = get_parent() as TextureButton
	
	if parent_button:
		# 2. 부모의 'pressed' 시그널을 이 스크립트의 함수에 연결
		parent_button.pressed.connect(_on_parent_pressed)

# 3. 버튼이 눌렸을 때 실행될 함수
func _on_parent_pressed():
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
