extends Node
## Game Manager for Frog Jump
## Handles score, state, and persistence

signal score_changed(new_score: int)
signal game_started
signal game_ended
signal new_high_score(score: int)

const SAVE_PATH = "user://frog_jump_save.json"

var score: int = 0
var high_score: int = 0
var total_jumps: int = 0
var games_played: int = 0
var is_playing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()

func start_game() -> void:
	score = 0
	is_playing = true
	games_played += 1
	emit_signal("score_changed", score)
	emit_signal("game_started")

func end_game() -> void:
	is_playing = false
	total_jumps += score

	if score > high_score:
		high_score = score
		emit_signal("new_high_score", score)

	save_data()
	emit_signal("game_ended")

func add_score(amount: int = 1) -> void:
	score += amount
	emit_signal("score_changed", score)

func get_score() -> int:
	return score

func save_data() -> void:
	var data = {
		"high_score": high_score,
		"total_jumps": total_jumps,
		"games_played": games_played
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		file.close()

		if error == OK:
			var data = json.data
			high_score = data.get("high_score", 0)
			total_jumps = data.get("total_jumps", 0)
			games_played = data.get("games_played", 0)
