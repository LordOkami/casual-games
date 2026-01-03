extends Control
## MainMenu: Gravity Flip main menu
## Animated title, play button, high score display, settings

@onready var title_label: Label = $VBox/TitleLabel
@onready var subtitle_label: Label = $VBox/SubtitleLabel
@onready var high_score_label: Label = $VBox/HighScoreLabel
@onready var gems_label: Label = $VBox/GemsLabel
@onready var play_button: Button = $VBox/PlayButton
@onready var settings_button: Button = $VBox/SettingsButton
@onready var sound_icon: Label = $VBox/SettingsButton/SoundIcon
@onready var stars_container: Node2D = $StarsContainer

var title_tween: Tween
var stars: Array[Dictionary] = []
const NUM_STARS = 50

func _ready() -> void:
	_setup_ui()
	_create_stars()
	_animate_title()

func _setup_ui() -> void:
	high_score_label.text = "HIGH SCORE: " + str(GameManager.high_score)
	gems_label.text = "💎 " + str(GameManager.total_gems)
	_update_sound_icon()

	# Style play button
	var play_style = StyleBoxFlat.new()
	play_style.bg_color = Color("#9b59b6")
	play_style.corner_radius_top_left = 20
	play_style.corner_radius_top_right = 20
	play_style.corner_radius_bottom_left = 20
	play_style.corner_radius_bottom_right = 20
	play_button.add_theme_stylebox_override("normal", play_style)

	var play_hover = play_style.duplicate()
	play_hover.bg_color = Color("#9b59b6").lightened(0.2)
	play_button.add_theme_stylebox_override("hover", play_hover)

	var play_pressed = play_style.duplicate()
	play_pressed.bg_color = Color("#9b59b6").darkened(0.2)
	play_button.add_theme_stylebox_override("pressed", play_pressed)

	# Style settings button
	var settings_style = StyleBoxFlat.new()
	settings_style.bg_color = Color("#333333")
	settings_style.corner_radius_top_left = 15
	settings_style.corner_radius_top_right = 15
	settings_style.corner_radius_bottom_left = 15
	settings_style.corner_radius_bottom_right = 15
	settings_button.add_theme_stylebox_override("normal", settings_style)

	var settings_hover = settings_style.duplicate()
	settings_hover.bg_color = Color("#444444")
	settings_button.add_theme_stylebox_override("hover", settings_hover)

func _create_stars() -> void:
	for i in range(NUM_STARS):
		var star = {
			"x": randf() * 720.0,
			"y": randf() * 1280.0,
			"size": randf_range(1.0, 3.0),
			"speed": randf_range(10.0, 30.0),
			"alpha": randf_range(0.3, 0.8)
		}
		stars.append(star)

func _animate_title() -> void:
	if title_tween:
		title_tween.kill()
	title_tween = create_tween().set_loops()
	title_tween.tween_property(title_label, "modulate:a", 0.7, 1.0)
	title_tween.tween_property(title_label, "modulate:a", 1.0, 1.0)

func _process(delta: float) -> void:
	# Animate stars
	for star in stars:
		star.y += star.speed * delta
		if star.y > 1280.0:
			star.y = 0.0
			star.x = randf() * 720.0
	stars_container.queue_redraw()

func _update_sound_icon() -> void:
	if GameManager.sound_enabled:
		sound_icon.text = "🔊"
	else:
		sound_icon.text = "🔇"

func _on_play_pressed() -> void:
	AudioManager.play_sfx("tap")
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_settings_pressed() -> void:
	AudioManager.play_sfx("tap")
	GameManager.toggle_sound()
	_update_sound_icon()
