extends Label

@onready var label_score: Label = $"."

func _ready() -> void:
	Global.score = 0

func _process(delta: float) -> void:
	label_score.text = str(Global.score)
