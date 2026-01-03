extends Control
## MainMenu: Main menu for Pull The Pin puzzle game
## Shows level selection and game progress

@export var game_name: String = "Pull The Pin"
@export var game_scene: String = "res://scenes/game.tscn"
@export var primary_color: Color = Color("#FF6B9D")

@onready var title_label: Label = $VBox/TitleLabel
@onready var high_score_label: Label = $VBox/HighScoreLabel
@onready var play_button: Button = $VBox/PlayButton
@onready var level_label: Label = $VBox/LevelLabel

func _ready() -> void:
	title_label.text = game_name
	high_score_label.text = "Best: " + str(GameManager.high_score) + " stars"
	level_label.text = "Levels Unlocked: " + str(GameManager.max_level_reached) + "/50"

	var style = StyleBoxFlat.new()
	style.bg_color = primary_color
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	play_button.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = primary_color.lightened(0.2)
	play_button.add_theme_stylebox_override("hover", hover)

func _on_play_pressed() -> void:
	AudioManager.play_sfx("tap")
	get_tree().change_scene_to_file(game_scene)
