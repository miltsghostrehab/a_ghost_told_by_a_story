extends Popup

# signals
signal call_options
signal continue_wip


func _ready():
	var  wip_file : File = File.new()
	if wip_file.file_exists("user://library/wip.txt"):
		$Buttons/VBoxContainer/ContinueButton.set_disabled(false)
	
	wip_file.close()


func _on_QuitButton_pressed():
	var t_label = $Buttons/VBoxContainer/QuitButton
	t_label.set_text("goodbye.")
	
	var t = Timer.new()
	t.set_wait_time(.7)
	t.set_one_shot(true)
	self.add_child(t)
	t.start()
	yield(t, "timeout")
	
	# final throes
	t.queue_free()
	get_tree().quit()


func _on_NewGameButton_pressed():
	hide()
	
	emit_signal("call_options")


func _on_ContinueButton_pressed():
	# creepy reload message
	var T : Node = Timer.new()
	add_child(T)
	$Title/Label.set_text("Welcome back, friend.")
	# hang on a sec
	T.set_wait_time(2.3)
	T.start()
	yield(T, "timeout")
	T.queue_free()
	
	hide()
	
	emit_signal("continue_wip")
