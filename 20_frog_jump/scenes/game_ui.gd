extends CanvasLayer
## Game UI for Frog Jump

@onready var score_label: Label = $ScoreLabel
@onready var jump_label: Label = $JumpLabel
@onready var game_over_panel: Control = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/FinalScoreLabel
@onready var best_score_label: Label = $GameOverPanel/BestScoreLabel
@onready var restart_button: Button = $GameOverPanel/RestartButton
@onready var menu_button: Button = $GameOverPanel/MenuButton
@onready var hint_label: Label = $HintLabel

var hint_timer: float = 0.0
const HINT_DURATION = 5.0
const ROPE_SWING_UNLOCK = 10

var rope_swing_notified: bool = false
var unlock_label: Label

func _ready() -> void:
	game_over_panel.visible = false
	hint_label.visible = true
	hint_timer = 0.0
	rope_swing_notified = false

	GameManager.score_changed.connect(_on_score_changed)
	GameManager.game_ended.connect(_on_game_ended)

	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	# Create unlock notification label
	unlock_label = Label.new()
	unlock_label.text = "TONGUE SWING UNLOCKED!\nTAP while jumping!"
	unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	unlock_label.add_theme_font_size_override("font_size", 28)
	unlock_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.4))
	unlock_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	unlock_label.add_theme_constant_override("shadow_offset_x", 2)
	unlock_label.add_theme_constant_override("shadow_offset_y", 2)
	unlock_label.position = Vector2(110, 500)
	unlock_label.size = Vector2(500, 100)
	unlock_label.visible = false
	add_child(unlock_label)

	_update_score(0)

func _process(delta: float) -> void:
	# Fade out hint after a few seconds
	if hint_label.visible:
		hint_timer += delta
		if hint_timer > HINT_DURATION:
			var tween = create_tween()
			tween.tween_property(hint_label, "modulate:a", 0.0, 0.5)
			tween.tween_callback(func(): hint_label.visible = false)

func _on_score_changed(new_score: int) -> void:
	_update_score(new_score)

func _update_score(score: int) -> void:
	score_label.text = str(score)
	jump_label.text = "JUMPS"

	# Pulse animation on score change
	if score > 0:
		var tween = create_tween()
		tween.tween_property(score_label, "scale", Vector2(1.3, 1.3), 0.1)
		tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.1)

	# Show rope swing unlock notification
	if score == ROPE_SWING_UNLOCK and not rope_swing_notified:
		rope_swing_notified = true
		_show_unlock_notification()

func _show_unlock_notification() -> void:
	unlock_label.visible = true
	unlock_label.modulate.a = 0
	unlock_label.scale = Vector2(0.5, 0.5)

	var tween = create_tween()
	tween.tween_property(unlock_label, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(unlock_label, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(unlock_label, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(2.0)
	tween.tween_property(unlock_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): unlock_label.visible = false)

func _on_game_ended() -> void:
	show_game_over()

func show_game_over() -> void:
	var final_score = GameManager.score
	var best_score = GameManager.high_score

	final_score_label.text = "JUMPS: " + str(final_score)
	best_score_label.text = "BEST: " + str(best_score)

	game_over_panel.visible = true
	game_over_panel.modulate.a = 0
	game_over_panel.scale = Vector2(0.8, 0.8)

	var tween = create_tween()
	tween.tween_property(game_over_panel, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(game_over_panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK)

func hide_game_over() -> void:
	game_over_panel.visible = false
	hint_label.visible = true
	hint_label.modulate.a = 1.0
	hint_timer = 0.0
	rope_swing_notified = false
	unlock_label.visible = false

func _on_restart_pressed() -> void:
	AudioManager.play_sfx("tap")
	var game = get_parent()
	if game.has_method("restart"):
		game.restart()

func _on_menu_pressed() -> void:
	AudioManager.play_sfx("tap")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
