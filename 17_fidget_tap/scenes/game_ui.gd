extends CanvasLayer
class_name FidgetGameUI
## FidgetGameUI: UI overlay for Fidget Tap
## Shows tap counter, stats, and provides pause functionality

@onready var tap_counter_label: Label = $TapContainer/TapCounterLabel
@onready var stats_label: Label = $TapContainer/StatsLabel
@onready var streak_label: Label = $TapContainer/StreakLabel
@onready var pause_panel: Panel = $PausePanel
@onready var back_button: Button = $BackButton

func _ready() -> void:
	FidgetStats.stats_updated.connect(_on_stats_updated)
	pause_panel.hide()
	_update_display()

func _on_stats_updated() -> void:
	_update_display()

func _update_display() -> void:
	var stats = FidgetStats.get_all_stats()
	tap_counter_label.text = str(stats.session_taps)
	stats_label.text = "Lifetime: %s" % _format_number(stats.total_lifetime_taps)

	if stats.current_streak > 1:
		streak_label.text = "%dx combo!" % stats.current_streak
		streak_label.show()
	else:
		streak_label.hide()

func _format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

func animate_tap() -> void:
	var tween = create_tween()
	tween.tween_property(tap_counter_label, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(tap_counter_label, "scale", Vector2(1.0, 1.0), 0.1)

func _on_back_pressed() -> void:
	AudioManager.play_sfx("tap")
	get_tree().paused = true
	pause_panel.show()

func _on_resume_pressed() -> void:
	AudioManager.play_sfx("tap")
	get_tree().paused = false
	pause_panel.hide()

func _on_menu_pressed() -> void:
	AudioManager.play_sfx("tap")
	FidgetStats.reset_session()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
