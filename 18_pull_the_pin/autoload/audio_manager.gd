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
		"pin_pull":
			# Satisfying metallic clink sound
			frequency = 1200.0
			length = 800
		"ball_collect":
			# Happy chime when ball reaches goal
			frequency = 1000.0
			length = 1200
		"explosion":
			# Low boom for hazard hit
			frequency = 80.0
			length = 3000
		"unlock":
			# Key unlocking sound
			frequency = 700.0
			length = 1500
		"splash":
			# Liquid/ball landing sound
			frequency = 400.0
			length = 1000
		"genius":
			# Fanfare for perfect solution
			frequency = 1100.0
			length = 2500

	for i in range(length):
		var t = float(i) / sample.mix_rate
		var value: float

		match sound_type:
			"pin_pull":
				# Sharp metallic sound with quick decay
				var env = pow(1.0 - (float(i) / length), 2.0)
				value = sin(t * frequency * TAU) * 127.0 * env
				value += sin(t * frequency * 2.5 * TAU) * 40.0 * env
			"explosion":
				# Noise-based explosion
				var env = pow(1.0 - (float(i) / length), 0.5)
				value = (randf() * 2.0 - 1.0) * 127.0 * env
				value += sin(t * frequency * TAU) * 60.0 * env
			"ball_collect":
				# Rising arpeggio
				var note_idx = int(float(i) / length * 3.0)
				var note_mult = [1.0, 1.25, 1.5][note_idx]
				var env = 1.0 - (float(i) / length)
				value = sin(t * frequency * note_mult * TAU) * 127.0 * env
			"genius":
				# Victory fanfare with harmonics
				var env = 1.0 - pow(float(i) / length, 0.7)
				value = sin(t * frequency * TAU) * 80.0 * env
				value += sin(t * frequency * 1.5 * TAU) * 40.0 * env
				value += sin(t * frequency * 2.0 * TAU) * 25.0 * env
			_:
				# Default sine wave with decay
				var envelope = 1.0 - (float(i) / length)
				value = sin(t * frequency * TAU) * 127.0 * envelope

		data.append(int(clamp(value, -127, 127)) + 128)

	sample.data = data
	return sample

func toggle_sfx() -> void:
	sfx_enabled = not sfx_enabled

func toggle_music() -> void:
	music_enabled = not music_enabled
