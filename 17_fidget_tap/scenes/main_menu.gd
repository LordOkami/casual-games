extends Control
## MainMenu: Main menu for Fidget Tap
## Shows lifetime stats and provides access to the game

@export var game_name: String = "Fidget Tap"
@export var game_scene: String = "res://scenes/game.tscn"
@export var primary_color: Color = Color("#62c5d3")

@onready var title_label: Label = $VBox/TitleLabel
@onready var stats_label: Label = $VBox/StatsLabel
@onready var play_button: Button = $VBox/PlayButton
@onready var zen_button: Button = $VBox/ZenButton

func _ready() -> void:
	title_label.text = game_name
	_update_stats()

	# Style play button
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

	# Style zen button with a darker/calmer variant
	var zen_style = StyleBoxFlat.new()
	zen_style.bg_color = primary_color.darkened(0.3)
	zen_style.corner_radius_top_left = 15
	zen_style.corner_radius_top_right = 15
	zen_style.corner_radius_bottom_left = 15
	zen_style.corner_radius_bottom_right = 15
	zen_button.add_theme_stylebox_override("normal", zen_style)

	var zen_hover = zen_style.duplicate()
	zen_hover.bg_color = primary_color.darkened(0.1)
	zen_button.add_theme_stylebox_override("hover", zen_hover)

	# Reset session stats when returning to menu
	FidgetStats.reset_session()

func _update_stats() -> void:
	var stats = FidgetStats.get_all_stats()
	stats_label.text = "Lifetime Taps: %s\nBest Session: %s\nFastest Streak: %s taps/sec" % [
		_format_number(stats.total_lifetime_taps),
		_format_number(stats.best_session_taps),
		stats.fastest_tap_streak
	]

func _format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

func _on_play_pressed() -> void:
	AudioManager.play_sfx("tap")
	HapticFeedback.light_impact()
	get_tree().change_scene_to_file(game_scene)

func _on_zen_pressed() -> void:
	AudioManager.play_sfx("tap")
	HapticFeedback.soft_impact()
	# Pass zen mode flag via a temp file or use scene parameter
	var file = FileAccess.open("user://zen_mode.tmp", FileAccess.WRITE)
	if file:
		file.store_8(1)
	get_tree().change_scene_to_file(game_scene)
