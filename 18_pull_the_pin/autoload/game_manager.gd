extends Node
## GameManager: Global game state management
## Handles score tracking, high scores, level progression, and game flow

signal score_changed(new_score: int)
signal high_score_changed(new_high: int)
signal game_over
signal game_started
signal level_changed(level: int)
signal level_completed(stars: int)

var current_score: int = 0
var high_score: int = 0
var game_name: String = ""
var current_level: int = 1
var max_level_reached: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_high_score()

func start_game(name: String = "") -> void:
	game_name = name
	current_score = 0
	emit_signal("score_changed", current_score)
	emit_signal("game_started")

func add_score(points: int = 1) -> void:
	current_score += points
	emit_signal("score_changed", current_score)
	AudioManager.play_sfx("score")

func end_game() -> void:
	if current_score > high_score:
		high_score = current_score
		_save_high_score()
		emit_signal("high_score_changed", current_score)
		AudioManager.play_sfx("new_high")
	else:
		AudioManager.play_sfx("game_over")
	emit_signal("game_over")

func complete_level(stars: int) -> void:
	emit_signal("level_completed", stars)
	if current_level >= max_level_reached:
		max_level_reached = current_level + 1
		_save_high_score()

func next_level() -> void:
	current_level += 1
	emit_signal("level_changed", current_level)

func set_level(level: int) -> void:
	current_level = level
	emit_signal("level_changed", current_level)

func restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _save_high_score() -> void:
	var file = FileAccess.open("user://highscore.save", FileAccess.WRITE)
	if file:
		file.store_var(high_score)
		file.store_var(max_level_reached)

func _load_high_score() -> void:
	if FileAccess.file_exists("user://highscore.save"):
		var file = FileAccess.open("user://highscore.save", FileAccess.READ)
		if file:
			high_score = file.get_var()
			if not file.eof_reached():
				max_level_reached = file.get_var()
