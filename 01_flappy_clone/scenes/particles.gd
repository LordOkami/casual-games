extends CPUParticles2D
## Celebration particle effect for passing through pipes
## Emits bright yellow/orange particles matching the bird theme

func _ready() -> void:
	# Configure particle properties for a quick celebration burst
	emitting = false
	one_shot = true
	explosiveness = 1.0

	# Keep particles small and short-lived (0.3 seconds as specified)
	lifetime = 0.3
	amount = 12

	# Spread particles in a circular pattern
	spread = 180.0
	direction = Vector2.UP

	# Particle movement
	initial_velocity_min = 100.0
	initial_velocity_max = 200.0
	gravity = Vector2(0, 300)

	# Scale particles - keep them small and fade out
	scale_amount_min = 0.3
	scale_amount_max = 0.6

	# Yellow to orange color matching bird/beak theme
	color_initial_ramp = _create_color_gradient()

	# Ensure particles clean up after emission
	finished.connect(_on_finished)


func _create_color_gradient() -> Gradient:
	var gradient = Gradient.new()
	# Start with bright yellow, end with orange (matching bird colors)
	gradient.set_color(0, Color(1.0, 0.9, 0.2, 1.0))  # Bright yellow
	gradient.set_color(1, Color(1.0, 0.5, 0.0, 0.0))  # Orange, fading out
	return gradient


func emit_celebration(pos: Vector2) -> void:
	## Emit particles at the specified position
	global_position = pos
	restart()


func _on_finished() -> void:
	# Reset for next use (since we're reusing this node)
	emitting = false
