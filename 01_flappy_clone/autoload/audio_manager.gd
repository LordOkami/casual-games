extends Node
## AudioManager: Handles all game audio
## Generates procedural sounds for lightweight deployment

var sfx_enabled: bool = true
var music_enabled: bool = true

func play_sfx(sound_name: String) -> void:
	if not sfx_enabled:
		return

	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = _generate_sound(sound_name)
	player.play()
	player.finished.connect(player.queue_free)

func _generate_sound(sound_type: String) -> AudioStream:
	var sample = AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_8_BITS
	sample.mix_rate = 22050
	sample.stereo = false

	var data: PackedByteArray = []
	var length: int = 2000
	var frequency: float = 440.0

	match sound_type:
		"score":
			frequency = 880.0
			length = 1500
		"game_over":
			frequency = 220.0
			length = 4000
		"new_high":
			frequency = 660.0
			length = 3000
		"tap":
			frequency = 550.0
			length = 1000
		"hit":
			frequency = 330.0
			length = 2000

	for i in range(length):
		var t = float(i) / sample.mix_rate
		var value = sin(t * frequency * TAU) * 127.0
		var envelope = 1.0 - (float(i) / length)
		value *= envelope
		data.append(int(value) + 128)

	sample.data = data
	return sample

func toggle_sfx() -> void:
	sfx_enabled = not sfx_enabled

func toggle_music() -> void:
	music_enabled = not music_enabled
