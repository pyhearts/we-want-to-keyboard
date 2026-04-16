extends Label

func _ready() -> void:
	Global.score = 0

# delta를 사용하지 않으므로 앞에 언더바(_)를 붙여 경고를 없앱니다.
func _process(_delta: float) -> void:
	# 자기 자신의 text 속성이므로 곧바로 값을 넣으면 됩니다.
	text = " " + str(Global.score)
