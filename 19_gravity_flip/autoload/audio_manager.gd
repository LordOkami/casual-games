extends Node
## AudioManager: Procedural audio for Gravity Flip
## Generates swoosh, chime, thud, and ambient sounds

var sfx_enabled: bool = true
var ambient_player: AudioStreamPlayer

func _ready() -> void:
	_setup_ambient()

func _setup_ambient() -> void:
	ambient_player = AudioStreamPlayer.new()
	ambient_player.volume_db = -20.0
	add_child(ambient_player)

func play_sfx(sound_name: String) -> void:
	if not sfx_enabled:
		return

	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = _generate_sound(sound_name)
	player.volume_db = _get_volume(sound_name)
	player.play()
	player.finished.connect(player.queue_free)

func _get_volume(sound_type: String) -> float:
	match sound_type:
		"flip":
			return -8.0
		"gem":
			return -6.0
		"death":
			return -4.0
		"new_high":
			return -5.0
		"tap":
			return -10.0
		_:
			return -8.0

func _generate_sound(sound_type: String) -> AudioStream:
	var sample = AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_8_BITS
	sample.mix_rate = 22050
	sample.stereo = false

	var data: PackedByteArray = []
	var length: int = 2000

	match sound_type:
		"flip":
			# Quick swoosh sound for gravity flip
			length = 2200
			for i in range(length):
				var t = float(i) / sample.mix_rate
				var env = 1.0 - pow(float(i) / length, 0.5)
				var freq = 800.0 - (float(i) / length) * 600.0
				var value = sin(t * freq * TAU) * 60.0 * env
				# Add some noise for swoosh effect
				value += (randf() * 2.0 - 1.0) * 30.0 * env
				data.append(int(clamp(value, -127, 127)) + 128)

		"gem":
			# Pleasant chime for collecting gems
			length = 3000
			for i in range(length):
				var t = float(i) / sample.mix_rate
				var env = pow(1.0 - (float(i) / length), 0.7)
				# Rising arpeggio effect
				var note_idx = int(float(i) / length * 4.0)
				var notes = [523.25, 659.25, 783.99, 1046.5]  # C5, E5, G5, C6
				var freq = notes[min(note_idx, 3)]
				var value = sin(t * freq * TAU) * 100.0 * env
				value += sin(t * freq * 2.0 * TAU) * 30.0 * env
				data.append(int(clamp(value, -127, 127)) + 128)

		"death":
			# Low thud for death
			length = 4500
			for i in range(length):
				var t = float(i) / sample.mix_rate
				var env = pow(1.0 - (float(i) / length), 0.3)
				var freq = 80.0 + sin(t * 3.0) * 20.0
				var value = sin(t * freq * TAU) * 100.0 * env
				# Add rumble
				value += (randf() * 2.0 - 1.0) * 50.0 * env * env
				data.append(int(clamp(value, -127, 127)) + 128)

		"new_high":
			# Victory fanfare
			length = 5000
			for i in range(length):
				var t = float(i) / sample.mix_rate
				var env = 1.0 - pow(float(i) / length, 0.8)
				# Ascending notes
				var note_idx = int(float(i) / length * 5.0)
				var notes = [392.0, 493.88, 587.33, 698.46, 783.99]  # G4, B4, D5, F5, G5
				var freq = notes[min(note_idx, 4)]
				var value = sin(t * freq * TAU) * 80.0 * env
				value += sin(t * freq * 1.5 * TAU) * 40.0 * env
				value += sin(t * freq * 2.0 * TAU) * 20.0 * env
				data.append(int(clamp(value, -127, 127)) + 128)

		"tap":
			# Simple tap/click
			length = 800
			for i in range(length):
				var t = float(i) / sample.mix_rate
				var env = pow(1.0 - (float(i) / length), 2.0)
				var value = sin(t * 600.0 * TAU) * 80.0 * env
				data.append(int(clamp(value, -127, 127)) + 128)

		"game_over":
			# Sad descending tone
			length = 4000
			for i in range(length):
				var t = float(i) / sample.mix_rate
				var env = 1.0 - (float(i) / length)
				var freq = 400.0 - (float(i) / length) * 200.0
				var value = sin(t * freq * TAU) * 90.0 * env
				data.append(int(clamp(value, -127, 127)) + 128)

		_:
			# Default beep
			for i in range(length):
				var t = float(i) / sample.mix_rate
				var env = 1.0 - (float(i) / length)
				var value = sin(t * 440.0 * TAU) * 100.0 * env
				data.append(int(clamp(value, -127, 127)) + 128)

	sample.data = data
	return sample

func toggle_sfx() -> void:
	sfx_enabled = not sfx_enabled
