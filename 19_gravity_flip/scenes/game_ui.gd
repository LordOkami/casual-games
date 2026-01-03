extends CanvasLayer
## GameUI: In-game UI for Gravity Flip
## Score display, pause menu, game over panel

@onready var score_label: Label = $ScoreLabel
@onready var gems_label: Label = $GemsLabel
@onready var pause_button: Button = $PauseButton
@onready var pause_panel: Panel = $PausePanel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/VBox/FinalScoreLabel
@onready var high_score_label: Label = $GameOverPanel/VBox/HighScoreLabel
@onready var new_high_label: Label = $GameOverPanel/VBox/NewHighLabel

var game_node: Node2D
var is_paused: bool = false

func _ready() -> void:
	pause_panel.visible = false
	game_over_panel.visible = false
	new_high_label.visible = false
	_setup_buttons()

	# Connect to GameManager
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.gems_changed.connect(_on_gems_changed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.high_score_changed.connect(_on_new_high_score)

	# Find game node
	await get_tree().process_frame
	game_node = get_parent()

func _setup_buttons() -> void:
	# Style all buttons
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color("#9b59b6")
	button_style.corner_radius_top_left = 12
	button_style.corner_radius_top_right = 12
	button_style.corner_radius_bottom_left = 12
	button_style.corner_radius_bottom_right = 12

	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color("#9b59b6").lightened(0.2)

	var pressed_style = button_style.duplicate()
	pressed_style.bg_color = Color("#9b59b6").darkened(0.2)

	# Apply to pause button
	pause_button.add_theme_stylebox_override("normal", button_style.duplicate())
	pause_button.add_theme_stylebox_override("hover", hover_style.duplicate())
	pause_button.add_theme_stylebox_override("pressed", pressed_style.duplicate())

func _on_score_changed(new_score: int) -> void:
	score_label.text = str(new_score)

func _on_gems_changed(total: int) -> void:
	gems_label.text = "💎 " + str(GameManager.get_session_gems())

func _on_game_over() -> void:
	game_over_panel.visible = true
	final_score_label.text = "SCORE: " + str(GameManager.current_score)
	high_score_label.text = "BEST: " + str(GameManager.high_score)

func _on_new_high_score(_score: int) -> void:
	new_high_label.visible = true

func hide_game_over() -> void:
	game_over_panel.visible = false
	new_high_label.visible = false
	gems_label.text = "💎 0"

func _on_pause_pressed() -> void:
	AudioManager.play_sfx("tap")
	is_paused = true
	pause_panel.visible = true
	get_tree().paused = true

func _on_resume_pressed() -> void:
	AudioManager.play_sfx("tap")
	is_paused = false
	pause_panel.visible = false
	get_tree().paused = false

func _on_restart_pressed() -> void:
	AudioManager.play_sfx("tap")
	get_tree().paused = false
	GameManager.restart_game()

func _on_menu_pressed() -> void:
	AudioManager.play_sfx("tap")
	get_tree().paused = false
	GameManager.go_to_menu()

func _on_retry_pressed() -> void:
	AudioManager.play_sfx("tap")
	if game_node and game_node.has_method("restart"):
		game_node.restart()
	else:
		GameManager.restart_game()

func _on_sound_toggle_pressed() -> void:
	AudioManager.play_sfx("tap")
	GameManager.toggle_sound()
	_update_sound_button()

func _update_sound_button() -> void:
	var sound_btn = $PausePanel/VBox/SoundButton
	if GameManager.sound_enabled:
		sound_btn.text = "🔊 SOUND ON"
	else:
		sound_btn.text = "🔇 SOUND OFF"
