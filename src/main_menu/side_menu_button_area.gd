extends Control

var _tween
@onready var menu := get_node("../Menu")


func _on_mouse_entered():
	if _tween:
		_tween.kill()

	_tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_tween.set_parallel()
	_tween.tween_property(self, "size:x", 50, 0.3)
	$MenuButton/MenuButtonBg.visible = true
	await _tween.finished
	$MenuButton/MenuButtonBg/MenuButtonIcon.visible = true


func _on_mouse_exited():
	if _tween:
		_tween.kill()

	$MenuButton/MenuButtonBg/MenuButtonIcon.visible = false
	_tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_tween.set_parallel()
	_tween.tween_property(self, "size:x", 20, 0.1)
	await _tween.finished
	$MenuButton/MenuButtonBg.visible = false


func _on_menu_button_pressed():
	if menu.visible:
		await menu.hide_menu()
	else:
		await menu.show_menu()
