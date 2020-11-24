extends Popup

signal call_start
signal start_game


func _on_Back_pressed():
	hide()
	emit_signal("call_start")


func _on_StartButton_pressed():
	hide()
	emit_signal("start_game")
