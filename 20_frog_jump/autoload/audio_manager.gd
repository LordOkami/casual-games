extends Node
## Audio Manager for Frog Jump
## Procedural sound generation for jump, land, and UI sounds

var audio_players: Dictionary = {}
var sample_rate: int = 44100

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_generate_sounds()

func _generate_sounds() -> void:
	# Jump sound - rising whoosh
	_create_sound("jump", _generate_jump_sound())

	# Land sound - soft thump with splash
	_create_sound("land", _generate_land_sound())

	# Charge sound - building tension
	_create_sound("charge", _generate_charge_sound())

	# Death sound - sad splash
	_create_sound("death", _generate_death_sound())

	# Tap sound - UI click
	_create_sound("tap", _generate_tap_sound())

func _create_sound(name: String, data: PackedVector2Array) -> void:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = true

	var byte_data = PackedByteArray()
	for sample in data:
		# Left channel
		var left = int(clamp(sample.x, -1.0, 1.0) * 32767)
		byte_data.append(left & 0xFF)
		byte_data.append((left >> 8) & 0xFF)
		# Right channel
		var right = int(clamp(sample.y, -1.0, 1.0) * 32767)
		byte_data.append(right & 0xFF)
		byte_data.append((right >> 8) & 0xFF)

	stream.data = byte_data

	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -6
	add_child(player)
	audio_players[name] = player

func _generate_jump_sound() -> PackedVector2Array:
	var duration = 0.2
	var samples = int(sample_rate * duration)
	var data = PackedVector2Array()

	for i in range(samples):
		var t = float(i) / sample_rate
		var progress = t / duration

		# Rising frequency
		var freq = lerp(200.0, 600.0, progress)
		var value = sin(t * freq * TAU)

		# Add some harmonics
		value += sin(t * freq * 2 * TAU) * 0.3
		value += sin(t * freq * 3 * TAU) * 0.1

		# Envelope - quick attack, sustain, decay
		var envelope = 1.0
		if progress < 0.1:
			envelope = progress / 0.1
		elif progress > 0.5:
			envelope = 1.0 - (progress - 0.5) / 0.5

		value *= envelope * 0.4
		data.append(Vector2(value, value))

	return data

func _generate_land_sound() -> PackedVector2Array:
	var duration = 0.25
	var samples = int(sample_rate * duration)
	var data = PackedVector2Array()

	for i in range(samples):
		var t = float(i) / sample_rate
		var progress = t / duration

		# Low thump
		var thump = sin(t * 80 * TAU) * exp(-t * 15)

		# Splash noise
		var splash = (randf() * 2 - 1) * exp(-t * 8) * 0.3

		# Water ripple
		var ripple = sin(t * 300 * TAU) * exp(-t * 12) * 0.2

		var value = (thump + splash + ripple) * 0.5
		data.append(Vector2(value, value))

	return data

func _generate_charge_sound() -> PackedVector2Array:
	var duration = 0.15
	var samples = int(sample_rate * duration)
	var data = PackedVector2Array()

	for i in range(samples):
		var t = float(i) / sample_rate
		var progress = t / duration

		# Low rumble building up
		var freq = lerp(60.0, 120.0, progress)
		var value = sin(t * freq * TAU) * 0.3

		# Add tension harmonics
		value += sin(t * freq * 2 * TAU) * 0.15 * progress

		# Envelope
		var envelope = min(progress * 3, 1.0)
		value *= envelope * 0.4

		data.append(Vector2(value, value))

	return data

func _generate_death_sound() -> PackedVector2Array:
	var duration = 0.5
	var samples = int(sample_rate * duration)
	var data = PackedVector2Array()

	for i in range(samples):
		var t = float(i) / sample_rate
		var progress = t / duration

		# Falling pitch
		var freq = lerp(400.0, 80.0, progress)
		var value = sin(t * freq * TAU)

		# Big splash
		var splash = (randf() * 2 - 1) * exp(-t * 3)

		# Sad wobble
		var wobble = sin(t * 6 * TAU) * 0.3

		var combined = (value * 0.3 + splash * 0.4) * (1 + wobble)

		# Envelope
		var envelope = 1.0 - progress
		combined *= envelope * 0.5

		data.append(Vector2(combined, combined))

	return data

func _generate_tap_sound() -> PackedVector2Array:
	var duration = 0.05
	var samples = int(sample_rate * duration)
	var data = PackedVector2Array()

	for i in range(samples):
		var t = float(i) / sample_rate
		var progress = t / duration

		var value = sin(t * 800 * TAU) * exp(-t * 50)
		value += sin(t * 1200 * TAU) * exp(-t * 60) * 0.5

		value *= 0.3
		data.append(Vector2(value, value))

	return data

func play_sfx(name: String) -> void:
	if audio_players.has(name):
		var player = audio_players[name] as AudioStreamPlayer
		if player.playing:
			player.stop()
		player.play()

func stop_sfx(name: String) -> void:
	if audio_players.has(name):
		audio_players[name].stop()
