extends Label


func _ready() -> void:
	Global.combo_changed.connect(_on_combo_changed)
	_on_combo_changed(Global.combo)


func _on_combo_changed(new_combo: int) -> void:
	text = str(new_combo)
