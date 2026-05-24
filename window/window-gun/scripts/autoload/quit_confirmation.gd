extends Node

var _dialog: ConfirmationDialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_dialog = ConfirmationDialog.new()
	_dialog.title = "게임 종료"
	_dialog.dialog_text = "게임을 종료할까요?"
	_dialog.exclusive = true
	_dialog.unresizable = true
	_dialog.confirmed.connect(_on_confirmed)
	_dialog.canceled.connect(_hide_dialog)
	_dialog.close_requested.connect(_hide_dialog)
	add_child(_dialog)

	_dialog.get_ok_button().text = "예"
	_dialog.get_cancel_button().text = "아니오"


func request_quit() -> void:
	if is_open():
		_hide_dialog()
		return

	_dialog.popup_centered(Vector2i(420, 160))


func is_open() -> bool:
	return _dialog != null and _dialog.visible


func _input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_hide_dialog()


func _on_confirmed() -> void:
	get_tree().quit()


func _hide_dialog() -> void:
	if _dialog:
		_dialog.hide()
