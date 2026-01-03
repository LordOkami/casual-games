extends CanvasLayer
class_name GameUI
## GameUI: Reusable game UI component
## Provides score display, pause menu, and game over screen

@onready var score_label: Label = $ScoreContainer/ScoreLabel
@onready var combo_label: Label = $ScoreContainer/ComboLabel
@onready var pause_panel: Panel = $PausePanel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/VBox/FinalScoreLabel
@onready var high_score_label: Label = $GameOverPanel/VBox/HighScoreLabel
@onready var new_high_label: Label = $GameOverPanel/VBox/NewHighLabel

# Combo colors for visual feedback
const COMBO_COLORS = [
	Color(1, 1, 1, 1),        # 1x - White (default)
	Color(0.5, 1, 0.5, 1),    # 2x - Light green
	Color(1, 1, 0, 1),        # 3x - Yellow
	Color(1, 0.5, 0, 1),      # 4x - Orange
	Color(1, 0.2, 0.2, 1),    # 5x - Red
]

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.high_score_changed.connect(_on_new_high_score)
	pause_panel.hide()
	game_over_panel.hide()
	new_high_label.hide()
	combo_label.hide()

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

func update_combo(multiplier: int) -> void:
	if multiplier <= 1:
		# No active combo or combo is 1x (no bonus)
		combo_label.hide()
		return

	# Show and update combo label
	combo_label.show()
	combo_label.text = str(multiplier) + "x COMBO!"

	# Apply color based on combo level (index 0 is for 1x, so use multiplier - 1)
	var color_index = mini(multiplier - 1, COMBO_COLORS.size() - 1)
	combo_label.modulate = COMBO_COLORS[color_index]

	# Animate the combo label for visual feedback
	var tween = create_tween()
	tween.tween_property(combo_label, "scale", Vector2(1.3, 1.3), 0.08)
	tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.12)
