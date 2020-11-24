extends Spatial

# RNG
var RNG = RandomNumberGenerator.new()

# corpora
export(String, FILE, "*.txt") var book_corpus_file
export(String, FILE, "*.json") var first_names_corpus_file
export(String, FILE, "*.json") var surnames_corpus_file
export(String, FILE, "*.json") var honor_corpus_file
var paragraphs : Array
var first_names : Array
var surnames : Array
var honorifics : Array

# options
export(bool) var has_honorific
export(bool) var has_subtitle
export(int) var characters_per_line
export(String, DIR) var library_directory

# line containers
var solo_lines : Array		# lines like "My dear sister," or "July 7th, 17--."
var first_lines : Array
var body_lines : Array
var last_lines : Array

# tracker
var do_continue : bool = true
var which_choice : int

# the novel
var novel : Array = []

# nodes
var reader : Node


# signals
signal mouse_click
signal choice_processed

# configuration
var CONFIG : Dictionary = {
	"crawl_speed" : int(3),
	"word_limit" :  int(50000)
}


func _ready():
	$SpaceField.show()
	$Menus/StartMenu.popup_centered()
	
	reader = $TheBook/Reader
	
	RNG.randomize()
	paragraphs = load_corpus(book_corpus_file)
	first_names = load_corpus_json(first_names_corpus_file)
	surnames = load_corpus_json(surnames_corpus_file)
	honorifics = load_corpus_json(honor_corpus_file)
	
	var dir : Directory = Directory.new()
	if !(dir.dir_exists(library_directory)):
		dir.make_dir(library_directory)
	
	if !(library_directory.ends_with("/")):
		library_directory += "/"
	
	find_and_sort_lines(paragraphs)


func _process(delta):
	pass


func find_and_sort_lines(corpus : Array):
	var sentence_regex = RegEx.new()
	sentence_regex.compile(".*?[.!?](?=\\s+[A-Z]|$)|^[^.!?]+$")
	
	for para in corpus:
		var results : Array = []
		
		for m in sentence_regex.search_all(para):
			var this_line : String = m.get_string().strip_edges().replace("\"","")
			if (this_line.count(" ") <= 3) and (this_line.findn("chapter") == 0):
				solo_lines.append(this_line)
			else:
				results.push_back(this_line)
		
		if results.empty():
			pass
		elif results.size() == 1:
			if str(results[0]).count(" ") <= 5:
				solo_lines.append(str(results[0]))
			body_lines.append(str(results[0]))
		else:
			first_lines.append(str(results[0]))
			last_lines.append(str(results[-1]))
			for s in results.slice(1,-2):
				body_lines.append(str(s))


func generate_novel(word_count : int, current_chapter : int, para_since_last_chapter : int, book_file_name : String):
	var T : Node = $Timer
	var word_limit : int = CONFIG.word_limit
	
	# start music
	$Music/Ambient.play()
	
	if current_chapter <= 1:
		# can't have two works-in-progress
		var delete_the_wip_file : Directory = Directory.new()
		delete_the_wip_file.remove(library_directory + "wip.txt")
		
		current_chapter = 1
		word_count = 0
		
		var title : String = generate_title(has_subtitle) \
			.replace("/.", "") \
			.capitalize()
		var author : String = generate_author(has_honorific)
		
		book_file_name = convert_to_valid_filename(title.to_upper() + " by " + author)
		
		# creating the array
		novel.append(str(OS.get_date()) + "\n\n")
		novel.append("TITLE: " + str(title) + "\n")
		novel.append("AUTHOR: " + str(author) + "\n")
		
		# send the info to the reader
		var c_loc : int = title.find(":")
		
		reader.show_title_page(title.left(c_loc), title.right(c_loc + 2), author)
		# wait for player
		yield(self, "mouse_click")
		
		var chapter_title : String = generate_chapter_title()
		novel.append("\n" + "CHAPTER " + str(current_chapter) + ": " + \
			chapter_title + "\n\n")

		reader.show_chapter_page(str(current_chapter), chapter_title)
		# hang on a sec
		T.set_wait_time(1.0)
		T.start()
		yield(T, "timeout")
		# wait for player
		yield(self, "mouse_click")
		
		current_chapter += 1
		para_since_last_chapter = 0
	
	# generate paragraphs
	while do_continue and word_count <= word_limit:
		var next_paragraph : String = pick_paragraph()
		
		word_count += next_paragraph.split(" ", false).size()
		novel.append(next_paragraph + "\n")
		reader.run_text_display(next_paragraph, CONFIG.crawl_speed, str(word_count))
		# wait to finish
		yield(reader, "text_typed")
		# wait for player
		yield(self, "mouse_click")
		# hang on a sec
		T.set_wait_time(0.1)
		T.start()
		yield(T, "timeout")
		
		para_since_last_chapter += 1
		
		if (para_since_last_chapter % RNG.randi_range(2, 4) == 0):
			var options : Array = [
				pick_paragraph(),
				pick_paragraph()
				]
			
			reader.show_choices(options[0], options[1])
			yield(self, "choice_processed")
			
			if do_continue:
				var chosen_paragraph = options[which_choice]
				
				word_count += chosen_paragraph.split(" ", false).size()
				novel.append(chosen_paragraph + "\n")
				reader.run_text_display(chosen_paragraph, CONFIG.crawl_speed, str(word_count))
				
				# wait to finish
				yield(reader, "text_typed")
				# wait for player
				yield(self, "mouse_click")
		
		if (RNG.randi_range(0, (100 / para_since_last_chapter)) == 1) and do_continue and word_count <= word_limit:
			var chapter_title : String = generate_chapter_title()
			
			novel.append("\n" + "CHAPTER " + str(current_chapter) + ": " + \
				chapter_title + "\n\n")
			
			reader.show_chapter_page(str(current_chapter), chapter_title)
			
			# hang on a sec
			T.set_wait_time(1.0)
			T.start()
			yield(T, "timeout")
			# wait for player
			yield(self, "mouse_click")
			
			current_chapter += 1
			para_since_last_chapter = 0
		
		save_generated_text(novel, "wip.txt")
	
	if word_count > word_limit:
		print("saving finished book...")

		save_generated_text(novel, book_file_name)
		# don't need wip.txt anymore
		var delete_the_wip_file : Directory = Directory.new()
		delete_the_wip_file.remove(library_directory + "wip.txt")
		reader.show_congratulations()
		yield(self, "mouse_click")
		get_tree().quit()
	else:
		novel.append(str(word_count) + "," \
			+ str(current_chapter) + "," \
			+ str(para_since_last_chapter) + "," \
			+ str(book_file_name))
		save_generated_text(novel, "wip.txt")
		reader.show_goodbye()
		yield(self, "mouse_click")
		get_tree().quit()


func pick_paragraph() -> String:
	var paragraph_temp : String
	
	match (RNG.randi_range(0, 2)):
		0:
			paragraph_temp = generate_para_no_dialog()
		1:
			paragraph_temp = generate_para_with_inline_dialog()
		2:
			paragraph_temp = generate_para_with_only_dialog()
	
	var formatted_paragraph : String = str(paragraph_temp.strip_edges())
	
	return formatted_paragraph


func generate_para_no_dialog():
	var working_paragraph : String
	
	# first line
	working_paragraph = line_construct(first_lines)
	
	# body
	for ln in range(1, RNG.randi_range(3,6)):
		working_paragraph += line_construct(body_lines)
		
	# final line
	working_paragraph += line_construct(last_lines)
	
	return working_paragraph


func generate_para_with_inline_dialog():
	var working_paragraph : String
	
	# first line
	working_paragraph = line_construct(first_lines)
	
	# body
	for ln in range(1, RNG.randi_range(3,6)):
		if (RNG.randi_range(0,2) == 1):
			working_paragraph += "\"" + line_construct(body_lines).strip_edges().trim_suffix(".") \
				+ ",\" they said, "
		else:
			working_paragraph += line_construct(body_lines)
	# final line
	working_paragraph += line_construct(last_lines)
	
	return working_paragraph


func generate_para_with_only_dialog():
	var working_paragraph : String
	
	# first line
	match (RNG.randi_range(0, 2)):
		0:
			working_paragraph = "\"" + str(line_construct(first_lines)).strip_edges().trim_suffix(".") \
				+ ",\" they said, \""
		1:
			working_paragraph = "\"" + str(line_construct(first_lines)).strip_edges().trim_suffix(".") \
				+ ",\" I said, \""
		2:
			working_paragraph = "\"" + str(line_construct(first_lines)).strip_edges().trim_suffix(".") \
				+ ",\" someone claimed, \""
	
	# body
	for ln in range(1, RNG.randi_range(2,5)):
		working_paragraph += line_construct(body_lines)
	# final line
	working_paragraph += str(line_construct(last_lines)).strip_edges(0,1) + "\""
	
	return working_paragraph


func generate_title(subtitle_switch : bool) -> String:
	var book_title : String
	var choose_main_title : int = RNG.randi_range(0, solo_lines.size() - 1)
	var choose_subtitle : int = RNG.randi_range(0, solo_lines.size() - 1)
	
	if choose_main_title == choose_subtitle:
		choose_subtitle = RNG.randi_range(0, solo_lines.size() - 1)
	
	book_title = str(solo_lines[choose_main_title]).replace(".","") \
		.replace("?","").replace("!","").replace(":","")
	if subtitle_switch:
		book_title += ": " + str(solo_lines[choose_subtitle]).replace(".","")
	
	return book_title


func generate_chapter_title() -> String:
	var chap_title : String
	var choose_chapter_title : int = RNG.randi_range(0, first_lines.size() - 1)
	
	chap_title = str(first_lines[choose_chapter_title])
	
	if (chap_title.length() >= characters_per_line / 2):
		var length_ : int = chap_title.rfind(" ", (characters_per_line / 2))
		chap_title = chap_title.substr(0, length_) + "!"
	
	return chap_title


func generate_author(honor_switch : bool) -> String:
	var author_name : String
	var choose_first_name : int = RNG.randi_range(0, first_names.size() - 1)
	var choose_surname : int = RNG.randi_range(0, surnames.size() - 1)
	var choose_honor : int = RNG.randi_range(0, honorifics.size() - 1)
	var choose_initial : int = RNG.randi_range(0, first_names.size() - 1)
	
	if honor_switch:
		author_name = honorifics[choose_honor] + " "
	author_name += first_names[choose_first_name] + " " + \
		str(first_names[choose_initial]).substr(0,1) + ". " + \
		surnames[choose_surname]
	
	return author_name


func load_corpus_json(file_path) -> Array:
	# Parses a JSON file and returns it as a dictionary
	var file = File.new()
	assert(file.file_exists(file_path))

	file.open(file_path, file.READ)
	var stuff_dictionary = parse_json(file.get_as_text())
	var stuff = stuff_dictionary.values()
	assert(stuff.size() > 0)
	print("load_dialog complete, supposedly")
	file.close()
	return stuff


func line_construct(line_corpus : Array) -> String:
	var constructed_line : String
	
	for i in 3:
		var working_line = str(line_corpus[RNG.randi_range(0,(line_corpus.size()-1))])

		var division : int = round(working_line.length() / 3)
		
		var from
#			if i == 0:
#				from = 0
#			else: 
		from = max(0, working_line.rfind(" ", (division * i) ))
		
		var le
		if i == 2:
			le = -1
		else:
			le = (working_line.rfind(" ", (division * (i + 1)) )) - from
		
		constructed_line += working_line.substr(from, le)
	
	return constructed_line.strip_edges().insert(constructed_line.length(), " ")


func _input(event):
	# ===========================================
	# Quit Game
	if Input.is_action_just_pressed("ui_cancel"):
		return
	# ===========================================
	# ===========================================
	# Use a mouse click for various things
	if Input.is_action_just_pressed("ui_accept"):
		emit_signal("mouse_click")
	# ===========================================


func load_corpus(file_path : String) -> Array:
	# Parses a JSON file and returns it as a dictionary
	var file = File.new()
	assert(file.file_exists(file_path))
	
	file.open(file_path, file.READ)
	
	# these replace lines are a "temporary" fix for stuff that has a period
	var corpus_temp = file.get_as_text() \
		.replace("Mr.", "Mr") \
		.replace("Mrs.", "Mrs") \
		.replace("Ms.", "Ms") \
		.split("\n\n")
	assert(corpus_temp.size() > 0)
	print("load_corpus complete, supposedly")
	file.close()
	
	var corpus : Array
	for i in corpus_temp.size():
		if ( corpus_temp[i] != "" ):
			corpus.append(str(corpus_temp[i]).strip_edges().replace("\n"," "))
	return corpus


func save_generated_text(book : Array, book_file_name : String):
	var generated_novel : File = File.new()
	var book_full_path : String = library_directory + book_file_name
	print(book_file_name)
	generated_novel.open(book_full_path, File.WRITE)
	
	for l in book:
		generated_novel.store_line(str(l))
	
	generated_novel.close()


func convert_to_valid_filename(text : String) -> String:
	var file_regex = RegEx.new()
	file_regex.compile("[^a-zA-Z0-9 ]")
	var new_text : String = str(str(file_regex.sub(text, "", true)) + ".txt") \
		.replace(" ", "_")
	
	return new_text

func _on_StartMenu_call_options():
	$Menus/OptionsMenu.popup_centered()


func _on_OptionsMenu_call_start():
	$Menus/StartMenu.popup_centered()


func _on_OptionsMenu_start_game():
	reader.popup_centered()
	$Music/StartMenuBG.stop()
	
	generate_novel(0, 1, 0, "")


func _on_Reader_choice_made(choice):
	if choice != 99:
		which_choice = choice
	else:
		do_continue = false
		
	emit_signal("choice_processed")


func _on_StartMenu_continue_wip():
	var wip_file : File = File.new()
	var wip_full_path : String = library_directory + "wip.txt"
	wip_file.open(wip_full_path, File.READ)
	
	# reload the file into the novel array
	novel = wip_file.get_as_text().split("\n")
	# get info stored in last line, then get rid of that line from novel
	var wip_info : Array = str(novel[-2]).split(",")
	novel.resize(novel.size() - 2)
	
	wip_file.close()
	
	reader.popup_centered()
	$Music/StartMenuBG.stop()
	
	generate_novel(int(wip_info[0]), int(wip_info[1]), int(wip_info[2]), str(wip_info[3]))
