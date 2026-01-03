extends CanvasLayer
class_name GameUI
## GameUI: Reusable game UI component for Pull The Pin
## Provides level display, star rating, pause menu, and level complete screen

@onready var level_label: Label = $TopBar/LevelLabel
@onready var star_container: HBoxContainer = $TopBar/StarContainer
@onready var hint_button: Button = $TopBar/HintButton
@onready var pause_panel: Panel = $PausePanel
@onready var level_complete_panel: Panel = $LevelCompletePanel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var final_stars_label: Label = $LevelCompletePanel/VBox/StarsLabel
@onready var genius_label: Label = $LevelCompletePanel/VBox/GeniusLabel
@onready var balls_saved_label: Label = $LevelCompletePanel/VBox/BallsSavedLabel
@onready var popup_label: Label = $PopupLabel

var stars: Array[ColorRect] = []

signal hint_requested
signal next_level_requested
signal retry_requested

func _ready() -> void:
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.game_over.connect(_on_game_over)
	pause_panel.hide()
	level_complete_panel.hide()
	game_over_panel.hide()
	genius_label.hide()
	popup_label.hide()
	_update_level_display()
	_create_star_display()

func _create_star_display() -> void:
	for child in star_container.get_children():
		child.queue_free()
	stars.clear()

	for i in range(3):
		var star = ColorRect.new()
		star.custom_minimum_size = Vector2(40, 40)
		star.color = Color(0.3, 0.3, 0.3, 1.0)
		star_container.add_child(star)
		stars.append(star)

func update_stars(filled: int) -> void:
	for i in range(stars.size()):
		if i < filled:
			stars[i].color = Color(1.0, 0.84, 0.0, 1.0)  # Gold
		else:
			stars[i].color = Color(0.3, 0.3, 0.3, 1.0)  # Gray

func _update_level_display() -> void:
	level_label.text = "Level " + str(GameManager.current_level)

func _on_level_changed(_level: int) -> void:
	_update_level_display()

func _on_level_completed(star_count: int) -> void:
	level_complete_panel.show()
	final_stars_label.text = str(star_count) + " / 3 Stars"

	if star_count == 3:
		genius_label.show()
		AudioManager.play_sfx("genius")
		var tween = create_tween().set_loops()
		tween.tween_property(genius_label, "scale", Vector2(1.1, 1.1), 0.2)
		tween.tween_property(genius_label, "scale", Vector2(1.0, 1.0), 0.2)
	else:
		genius_label.hide()

	get_tree().paused = true

func _on_game_over() -> void:
	game_over_panel.show()
	get_tree().paused = true

func show_popup(text: String, color: Color = Color.WHITE) -> void:
	popup_label.text = text
	popup_label.modulate = color
	popup_label.show()
	popup_label.scale = Vector2(0.5, 0.5)

	var tween = create_tween()
	tween.tween_property(popup_label, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(popup_label, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(0.8)
	tween.tween_property(popup_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(popup_label.hide)

func set_balls_saved(saved: int, total: int) -> void:
	balls_saved_label.text = "Balls Saved: " + str(saved) + " / " + str(total)

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

func _on_next_level_pressed() -> void:
	get_tree().paused = false
	level_complete_panel.hide()
	next_level_requested.emit()

func _on_retry_pressed() -> void:
	get_tree().paused = false
	game_over_panel.hide()
	retry_requested.emit()

func _on_hint_pressed() -> void:
	hint_requested.emit()
