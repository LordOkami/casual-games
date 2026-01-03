extends CanvasLayer
class_name GameUI
## GameUI: Reusable game UI component
## Provides score display, pause menu, and game over screen

@onready var score_label: Label = $ScoreContainer/ScoreLabel
@onready var pause_panel: Panel = $PausePanel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/VBox/FinalScoreLabel
@onready var high_score_label: Label = $GameOverPanel/VBox/HighScoreLabel
@onready var new_high_label: Label = $GameOverPanel/VBox/NewHighLabel

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.high_score_changed.connect(_on_new_high_score)
	pause_panel.hide()
	game_over_panel.hide()
	new_high_label.hide()

func _on_score_changed(new_score: int) -> void:
	score_label.text = str(new_score)
	var tween = create_tween()
	tween.tween_property(score_label, "scale", Vector2(1.2, 1.2), 0.05)
	tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.1)

func _on_game_over() -> void:
	game_over_panel.show()
	final_score_label.text = "Score: " + str(GameManager.current_score)
	high_score_label.text = "Best: " + str(GameManager.high_score)
	get_tree().paused = true

func _on_new_high_score(_new_high: int) -> void:
	new_high_label.show()
	var tween = create_tween().set_loops()
	tween.tween_property(new_high_label, "modulate:a", 0.5, 0.3)
	tween.tween_property(new_high_label, "modulate:a", 1.0, 0.3)

func _on_pause_pressed() -> void:
	get_tree().paused = true
	pause_panel.show()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	pause_panel.hide()

func _on_restart_pressed() -> void:
	GameManager.restart_game()

func _on_menu_pressed() -> void:
	GameManager.go_to_menu()
