extends Control
## Memory Match: Find matching card pairs

const GRID_COLS = 4
const GRID_ROWS = 5
const CARD_SIZE = 140
const CARD_MARGIN = 15

@onready var cards_container: Control = $CardsContainer
@onready var moves_label: Label = $MovesLabel

var cards: Array[Control] = []
var card_values: Array[int] = []
var flipped_cards: Array[Control] = []
var matched_pairs: int = 0
var moves: int = 0
var game_active: bool = true
var can_flip: bool = true
var total_pairs: int

var symbols: Array[String] = ["★", "♥", "♦", "♣", "♠", "●", "■", "▲", "◆", "✦"]
var colors: Array[Color] = [Color("#e63946"), Color("#f4a261"), Color("#2a9d8f"), Color("#264653"), Color("#9c27b0"), Color("#00bcd4"), Color("#4caf50"), Color("#ff5722"), Color("#673ab7"), Color("#009688")]

func _ready() -> void:
	GameManager.start_game("memory_match")
	total_pairs = (GRID_COLS * GRID_ROWS) / 2
	_create_cards()

func _create_cards() -> void:
	card_values.clear()
	for i in range(total_pairs):
		card_values.append(i)
		card_values.append(i)
	card_values.shuffle()

	var start_x = (get_viewport_rect().size.x - GRID_COLS * (CARD_SIZE + CARD_MARGIN)) / 2

	for i in range(card_values.size()):
		var card = _create_card(card_values[i])
		card.position = Vector2(start_x + (i % GRID_COLS) * (CARD_SIZE + CARD_MARGIN), 250 + (i / GRID_COLS) * (CARD_SIZE + CARD_MARGIN))
		card.set_meta("value", card_values[i])
		cards.append(card)
		cards_container.add_child(card)

func _create_card(value: int) -> Control:
	var card = Control.new()
	card.size = Vector2(CARD_SIZE, CARD_SIZE)

	var back = ColorRect.new()
	back.name = "Back"
	back.size = Vector2(CARD_SIZE, CARD_SIZE)
	back.color = Color("#34495e")
	var question = Label.new()
	question.text = "?"
	question.add_theme_font_size_override("font_size", 60)
	question.add_theme_color_override("font_color", Color("#2c3e50"))
	question.size = Vector2(CARD_SIZE, CARD_SIZE)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back.add_child(question)
	card.add_child(back)

	var front = ColorRect.new()
	front.name = "Front"
	front.size = Vector2(CARD_SIZE, CARD_SIZE)
	front.color = colors[value % colors.size()]
	front.visible = false
	var symbol = Label.new()
	symbol.text = symbols[value % symbols.size()]
	symbol.add_theme_font_size_override("font_size", 70)
	symbol.add_theme_color_override("font_color", Color.WHITE)
	symbol.size = Vector2(CARD_SIZE, CARD_SIZE)
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	front.add_child(symbol)
	card.add_child(front)

	var button = Button.new()
	button.flat = true
	button.size = Vector2(CARD_SIZE, CARD_SIZE)
	button.modulate.a = 0
	button.pressed.connect(_on_card_clicked.bind(card))
	card.add_child(button)

	return card

func _on_card_clicked(card: Control) -> void:
	if not game_active or not can_flip or card in flipped_cards or card.get_node("Front").visible:
		return

	_flip_card(card, true)
	flipped_cards.append(card)
	AudioManager.play_sfx("tap")

	if flipped_cards.size() == 2:
		moves += 1
		moves_label.text = "Moves: " + str(moves)
		can_flip = false
		_check_match()

func _flip_card(card: Control, show_front: bool) -> void:
	card.get_node("Back").visible = not show_front
	card.get_node("Front").visible = show_front

func _check_match() -> void:
	await get_tree().create_timer(0.8).timeout
	if flipped_cards[0].get_meta("value") == flipped_cards[1].get_meta("value"):
		matched_pairs += 1
		GameManager.add_score(100)
		if matched_pairs >= total_pairs:
			game_active = false
			GameManager.add_score(max(0, 1000 - moves * 10))
			GameManager.end_game()
	else:
		_flip_card(flipped_cards[0], false)
		_flip_card(flipped_cards[1], false)
	flipped_cards.clear()
	can_flip = true
