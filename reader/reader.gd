extends Popup

# RNG
var RNG = RandomNumberGenerator.new()

# signals
signal text_typed
signal choice_made(which_choice)


func _ready():
	hide_everything()
	
	# want to make sure my choice buttons are showing
	$SelectionButtons/ChoiceA.show()
	$SelectionButtons/ChoiceB.show()
	$SelectionButtons/ChoiceExit.show()


func hide_everything():
	$Displays/TextDisplay.hide()
	$Displays/ChapterDisplay.hide()
	$Displays/ChapterTitleDisplay.hide()
	$Displays/BookStartDisplay.hide()
	$SelectionButtons.hide()
	$Displays/ContinueNotify.hide()
	$ExitScreens.hide()

func show_title_page(title : String, sub : String, author : String):
	find_node("BookTitle").set_text(title)
	find_node("BookSubtitle").set_text(sub)
	find_node("BookAuthor").set_text("Written by " + author)
	
	$Displays/BookStartDisplay.show()


func show_chapter_page(chapter_number : String, chapter_title : String):
	# set up a timer
	var tm = Timer.new()
	tm.set_wait_time(.7)
	tm.set_one_shot(true)
	self.add_child(tm)
	
	find_node("ChapterDisplay").set_text("chapter " + chapter_number + ":")
	find_node("ChapterTitleDisplay").set_text(chapter_title)
	
	$Audio/ChapterNum.play()
	hide_everything()
	$Displays/ChapterDisplay.show()

	tm.start()
	yield(tm, "timeout")
	
	$Audio/ChapterTitle.play()
	$Displays/ChapterTitleDisplay.show()
	
	# final throes
	tm.queue_free()


func run_text_display(text : String, crawl : int, word_count : String):
	$NumberOfWords.set_text(word_count)
	
	# set up a timer for slowing the crawl
	var cr = Timer.new()
	cr.set_wait_time(.07)
	cr.set_one_shot(true)
	self.add_child(cr)
	
	var text_display : Node = $Displays/TextDisplay
	hide_everything()
	text_display.set_text(text)
	text_display.set_visible_characters(0)
	
	text_display.show()
	
	while text_display.visible_characters <= text.length():
		text_display.visible_characters += crawl
		$Audio/Typing.play()
		cr.start()
		yield(cr, "timeout")
		$Audio/Typing.stop()
		
	
	# final throes
	cr.queue_free()
	$Displays/ContinueNotify.show()
	emit_signal("text_typed")


func show_choices(a : String, b : String):
	$Displays/ContinueNotify.hide()
	
	var a_txt : String = a.substr(0, 24) + "..."
	var b_txt : String = b.substr(0, 24) + "..."
	var exit_text : Array = [
		"I think we've written enough",
		"That's all we should write",
		"I'm tired; we should be done",
		"This is as much as we should write",
		"Time to be done for now",
		"Off to bed..."
	]
	
	$SelectionButtons/ChoiceA.set_text(a_txt)
	$SelectionButtons/ChoiceB.set_text(b_txt)
	
	$SelectionButtons/ChoiceExit.set_text(str(exit_text[RNG.randi_range(0, exit_text.size() - 1)]))
	
	$SelectionButtons.show()


func show_congratulations():
	hide_everything()
	$ExitScreens/Congratulations.popup_centered()


func show_goodbye():
	hide_everything()
	$ExitScreens/Leaving.popup_centered()


# ----------------------------------------


func _on_ChoiceA_pressed():
	emit_signal("choice_made", 0)


func _on_ChoiceB_pressed():
	emit_signal("choice_made", 1)


func _on_ChoiceExit_pressed():
	emit_signal("choice_made", 99)
