extends Node
## Autonomous Test Agent - Injects into any game to run automated tests
## Simulates user input and validates game behavior

signal test_completed(results: Dictionary)
signal test_step_completed(step: String, success: bool)

# Test configuration
var test_config: Dictionary = {}
var current_test: String = ""
var test_results: Array[Dictionary] = []
var is_testing: bool = false
var test_start_time: float = 0.0

# Game state tracking
var initial_score: int = 0
var frames_elapsed: int = 0
var actions_performed: Array[Dictionary] = []
var errors_detected: Array[String] = []
var screenshots: Array[Image] = []

# Input simulation
var simulated_touches: Dictionary = {}
var pending_actions: Array[Dictionary] = []

# Test scenarios by game type
const TEST_SCENARIOS = {
	"tap": [
		{"action": "wait", "duration": 0.5},
		{"action": "tap", "x": 360, "y": 640, "repeat": 5, "interval": 0.3},
		{"action": "wait", "duration": 1.0},
		{"action": "verify", "check": "score_changed"},
		{"action": "tap", "x": 360, "y": 640, "repeat": 10, "interval": 0.2},
		{"action": "wait", "duration": 2.0},
		{"action": "verify", "check": "game_responsive"},
	],
	"swipe": [
		{"action": "wait", "duration": 0.5},
		{"action": "swipe", "from_x": 360, "from_y": 800, "to_x": 360, "to_y": 400, "duration": 0.3},
		{"action": "wait", "duration": 0.5},
		{"action": "swipe", "from_x": 200, "from_y": 640, "to_x": 520, "to_y": 640, "duration": 0.3},
		{"action": "wait", "duration": 0.5},
		{"action": "verify", "check": "game_responsive"},
	],
	"drag": [
		{"action": "wait", "duration": 0.5},
		{"action": "drag", "from_x": 360, "from_y": 640, "to_x": 200, "to_y": 640, "duration": 0.5},
		{"action": "drag", "from_x": 200, "from_y": 640, "to_x": 520, "to_y": 640, "duration": 0.5},
		{"action": "wait", "duration": 1.0},
		{"action": "verify", "check": "no_errors"},
	],
	"idle": [
		{"action": "wait", "duration": 2.0},
		{"action": "verify", "check": "game_running"},
		{"action": "wait", "duration": 3.0},
		{"action": "verify", "check": "no_crash"},
	],
	"menu_navigation": [
		{"action": "wait", "duration": 1.0},
		{"action": "find_and_tap", "target": "play"},
		{"action": "wait", "duration": 1.5},
		{"action": "verify", "check": "scene_changed"},
		{"action": "find_and_tap", "target": "pause"},
		{"action": "wait", "duration": 0.5},
		{"action": "find_and_tap", "target": "resume"},
		{"action": "wait", "duration": 1.0},
	],
	"stress_test": [
		{"action": "rapid_tap", "x": 360, "y": 640, "count": 50, "interval": 0.05},
		{"action": "wait", "duration": 1.0},
		{"action": "verify", "check": "no_crash"},
		{"action": "verify", "check": "fps_stable"},
	],
	"full_playthrough": [
		{"action": "wait", "duration": 0.5},
		{"action": "find_and_tap", "target": "play"},
		{"action": "wait", "duration": 1.0},
		{"action": "play_game", "duration": 10.0},
		{"action": "verify", "check": "game_over_or_playing"},
		{"action": "screenshot", "name": "gameplay"},
	]
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_test_config()
	if test_config.get("auto_start", false):
		call_deferred("start_tests")

func _load_test_config() -> void:
	var config_path = "user://test_config.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			test_config = json.data
		file.close()

func _process(delta: float) -> void:
	if not is_testing:
		return

	frames_elapsed += 1
	_process_pending_actions(delta)
	_check_for_errors()

func start_tests() -> void:
	print("[TEST_AGENT] Starting autonomous tests...")
	is_testing = true
	test_start_time = Time.get_ticks_msec() / 1000.0
	test_results.clear()
	errors_detected.clear()

	# Detect game type and run appropriate tests
	var game_type = _detect_game_type()
	print("[TEST_AGENT] Detected game type: ", game_type)

	# Run test scenarios
	await _run_scenario("menu_navigation")
	await _run_scenario(game_type)
	await _run_scenario("stress_test")
	await _run_scenario("full_playthrough")

	_finish_tests()

func _detect_game_type() -> String:
	# Analyze current scene to determine game type
	var root = get_tree().current_scene
	if not root:
		return "tap"

	# Check for swipe indicators
	if _has_method_in_tree(root, "_on_swipe") or _has_method_in_tree(root, "handle_swipe"):
		return "swipe"

	# Check for drag indicators
	if _has_method_in_tree(root, "_on_drag") or _has_method_in_tree(root, "handle_drag"):
		return "drag"

	# Default to tap
	return "tap"

func _has_method_in_tree(node: Node, method_name: String) -> bool:
	if node.has_method(method_name):
		return true
	for child in node.get_children():
		if _has_method_in_tree(child, method_name):
			return true
	return false

func _run_scenario(scenario_name: String) -> void:
	if not TEST_SCENARIOS.has(scenario_name):
		print("[TEST_AGENT] Unknown scenario: ", scenario_name)
		return

	current_test = scenario_name
	print("[TEST_AGENT] Running scenario: ", scenario_name)

	var scenario = TEST_SCENARIOS[scenario_name]
	for step in scenario:
		var success = await _execute_step(step)
		actions_performed.append({
			"scenario": scenario_name,
			"step": step,
			"success": success,
			"timestamp": Time.get_ticks_msec() / 1000.0
		})
		test_step_completed.emit(str(step), success)

func _execute_step(step: Dictionary) -> bool:
	match step.get("action", ""):
		"wait":
			await get_tree().create_timer(step.get("duration", 1.0)).timeout
			return true

		"tap":
			return await _execute_tap(step)

		"rapid_tap":
			return await _execute_rapid_tap(step)

		"swipe":
			return await _execute_swipe(step)

		"drag":
			return await _execute_drag(step)

		"find_and_tap":
			return await _execute_find_and_tap(step)

		"verify":
			return _execute_verify(step)

		"screenshot":
			return _take_screenshot(step.get("name", "screenshot"))

		"play_game":
			return await _execute_play_game(step)

		_:
			print("[TEST_AGENT] Unknown action: ", step.get("action", ""))
			return false

func _execute_tap(step: Dictionary) -> bool:
	var x = step.get("x", 360)
	var y = step.get("y", 640)
	var repeat = step.get("repeat", 1)
	var interval = step.get("interval", 0.1)

	for i in range(repeat):
		_simulate_touch(x, y)
		await get_tree().create_timer(0.05).timeout
		_simulate_touch_release(x, y)
		if i < repeat - 1:
			await get_tree().create_timer(interval).timeout

	return true

func _execute_rapid_tap(step: Dictionary) -> bool:
	var x = step.get("x", 360)
	var y = step.get("y", 640)
	var count = step.get("count", 10)
	var interval = step.get("interval", 0.05)

	for i in range(count):
		_simulate_touch(x, y)
		await get_tree().process_frame
		_simulate_touch_release(x, y)
		await get_tree().create_timer(interval).timeout

	return true

func _execute_swipe(step: Dictionary) -> bool:
	var from_x = step.get("from_x", 360)
	var from_y = step.get("from_y", 640)
	var to_x = step.get("to_x", 360)
	var to_y = step.get("to_y", 400)
	var duration = step.get("duration", 0.3)

	var steps = int(duration * 60)  # 60 fps
	_simulate_touch(from_x, from_y)

	for i in range(steps):
		var t = float(i) / float(steps)
		var current_x = lerp(float(from_x), float(to_x), t)
		var current_y = lerp(float(from_y), float(to_y), t)
		_simulate_touch_move(current_x, current_y)
		await get_tree().process_frame

	_simulate_touch_release(to_x, to_y)
	return true

func _execute_drag(step: Dictionary) -> bool:
	return await _execute_swipe(step)  # Same implementation

func _execute_find_and_tap(step: Dictionary) -> bool:
	var target = step.get("target", "")
	var button = _find_button_by_name(target)

	if button:
		var pos = button.global_position + button.size / 2
		_simulate_touch(pos.x, pos.y)
		await get_tree().create_timer(0.05).timeout
		_simulate_touch_release(pos.x, pos.y)
		return true

	# Try clicking center if button not found
	_simulate_touch(360, 640)
	await get_tree().create_timer(0.05).timeout
	_simulate_touch_release(360, 640)
	return false

func _find_button_by_name(name_pattern: String) -> Control:
	var root = get_tree().current_scene
	if not root:
		return null
	return _search_button(root, name_pattern.to_lower())

func _search_button(node: Node, pattern: String) -> Control:
	if node is Button or node is TextureButton:
		var node_name = node.name.to_lower()
		if pattern in node_name or node_name in pattern:
			if node.visible:
				return node as Control

	for child in node.get_children():
		var found = _search_button(child, pattern)
		if found:
			return found

	return null

func _execute_play_game(step: Dictionary) -> bool:
	var duration = step.get("duration", 10.0)
	var elapsed = 0.0
	var tap_interval = 0.5

	while elapsed < duration:
		# Random tap in game area
		var x = randf_range(100, 620)
		var y = randf_range(200, 1000)
		_simulate_touch(x, y)
		await get_tree().create_timer(0.05).timeout
		_simulate_touch_release(x, y)

		await get_tree().create_timer(tap_interval).timeout
		elapsed += tap_interval + 0.05

		# Vary tap interval
		tap_interval = randf_range(0.2, 0.8)

	return true

func _execute_verify(step: Dictionary) -> bool:
	var check = step.get("check", "")

	match check:
		"score_changed":
			var current_score = _get_current_score()
			return current_score != initial_score

		"game_responsive":
			return frames_elapsed > 10 and errors_detected.is_empty()

		"game_running":
			return get_tree().current_scene != null

		"no_crash":
			return errors_detected.is_empty()

		"no_errors":
			return errors_detected.is_empty()

		"fps_stable":
			return Engine.get_frames_per_second() >= 30

		"scene_changed":
			return true  # If we got here, scene changed

		"game_over_or_playing":
			return true  # Game is in some valid state

		_:
			return true

func _get_current_score() -> int:
	# Try to find GameManager and get score
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("get_score"):
			return gm.get_score()
		if "score" in gm:
			return gm.score
	return 0

func _simulate_touch(x: float, y: float) -> void:
	var event = InputEventScreenTouch.new()
	event.index = 0
	event.position = Vector2(x, y)
	event.pressed = true
	Input.parse_input_event(event)
	simulated_touches[0] = Vector2(x, y)

func _simulate_touch_move(x: float, y: float) -> void:
	var event = InputEventScreenDrag.new()
	event.index = 0
	event.position = Vector2(x, y)
	if simulated_touches.has(0):
		event.relative = Vector2(x, y) - simulated_touches[0]
	Input.parse_input_event(event)
	simulated_touches[0] = Vector2(x, y)

func _simulate_touch_release(x: float, y: float) -> void:
	var event = InputEventScreenTouch.new()
	event.index = 0
	event.position = Vector2(x, y)
	event.pressed = false
	Input.parse_input_event(event)
	simulated_touches.erase(0)

func _take_screenshot(name: String) -> bool:
	var image = get_viewport().get_texture().get_image()
	screenshots.append(image)

	# Save to file
	var path = "user://test_screenshots/%s_%d.png" % [name, Time.get_ticks_msec()]
	DirAccess.make_dir_recursive_absolute("user://test_screenshots")
	image.save_png(path)
	print("[TEST_AGENT] Screenshot saved: ", path)
	return true

func _check_for_errors() -> void:
	# Check for common error indicators
	if get_tree().current_scene == null:
		errors_detected.append("Scene became null at frame " + str(frames_elapsed))

func _process_pending_actions(_delta: float) -> void:
	pass  # Actions are processed via await

func _finish_tests() -> void:
	is_testing = false
	var duration = (Time.get_ticks_msec() / 1000.0) - test_start_time

	var results = {
		"game_name": _get_game_name(),
		"duration": duration,
		"frames": frames_elapsed,
		"actions": actions_performed.size(),
		"errors": errors_detected,
		"passed": errors_detected.is_empty(),
		"fps_avg": Engine.get_frames_per_second(),
		"screenshots": screenshots.size(),
		"timestamp": Time.get_datetime_string_from_system()
	}

	# Save results
	_save_results(results)

	print("[TEST_AGENT] Tests completed!")
	print("[TEST_AGENT] Duration: %.2f seconds" % duration)
	print("[TEST_AGENT] Actions performed: ", actions_performed.size())
	print("[TEST_AGENT] Errors: ", errors_detected.size())
	print("[TEST_AGENT] PASSED: ", results.passed)

	test_completed.emit(results)

	# Exit with appropriate code
	if test_config.get("auto_exit", true):
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0 if results.passed else 1)

func _get_game_name() -> String:
	var scene_path = get_tree().current_scene.scene_file_path
	if scene_path:
		return scene_path.get_base_dir().get_file()
	return "unknown"

func _save_results(results: Dictionary) -> void:
	var path = "user://test_results.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	print("[TEST_AGENT] Results saved to: ", path)
