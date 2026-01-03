extends Node
## GameManager: Global game state for Gravity Flip
## Handles score, high score, gems, and settings persistence

signal score_changed(new_score: int)
signal high_score_changed(new_high: int)
signal gems_changed(total: int)
signal game_over
signal game_started

var current_score: int = 0
var high_score: int = 0
var total_gems: int = 0
var session_gems: int = 0
var distance: float = 0.0
var sound_enabled: bool = true

const SAVE_PATH = "user://gravity_flip.save"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_data()

func start_game() -> void:
	current_score = 0
	session_gems = 0
	distance = 0.0
	emit_signal("score_changed", current_score)
	emit_signal("game_started")

func add_distance(dist: float) -> void:
	distance += dist
	current_score = int(distance / 10.0)
	emit_signal("score_changed", current_score)

func add_gem() -> void:
	session_gems += 1
	total_gems += 1
	current_score += 10
	emit_signal("score_changed", current_score)
	emit_signal("gems_changed", total_gems)
	AudioManager.play_sfx("gem")

func get_session_gems() -> int:
	return session_gems

func end_game() -> void:
	var is_new_high = false
	if current_score > high_score:
		high_score = current_score
		is_new_high = true
		emit_signal("high_score_changed", current_score)
		AudioManager.play_sfx("new_high")
	else:
		AudioManager.play_sfx("death")
	_save_data()
	emit_signal("game_over")
	return

func restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	AudioManager.sfx_enabled = sound_enabled
	_save_data()

func _save_data() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(high_score)
		file.store_var(total_gems)
		file.store_var(sound_enabled)

func _load_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			high_score = file.get_var()
			if not file.eof_reached():
				total_gems = file.get_var()
			if not file.eof_reached():
				sound_enabled = file.get_var()
	AudioManager.sfx_enabled = sound_enabled
