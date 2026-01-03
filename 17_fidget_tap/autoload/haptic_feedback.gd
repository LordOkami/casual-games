extends Node
## HapticFeedback: Manages haptic feedback for different tap patterns
## Provides light, medium, heavy impacts and success notifications
## Uses Input.vibrate_handheld() for cross-platform vibration

enum HapticType {
	LIGHT,    ## Single tap - light impact
	MEDIUM,   ## Double tap - medium impact
	HEAVY,    ## Long press - heavy impact with rumble
	SUCCESS,  ## Rapid taps - success notification
	SOFT,     ## Very gentle feedback
	RIGID     ## Sharp, defined feedback
}

## Duration in milliseconds for each haptic type
const HAPTIC_DURATIONS: Dictionary = {
	HapticType.LIGHT: 10,
	HapticType.MEDIUM: 25,
	HapticType.HEAVY: 50,
	HapticType.SUCCESS: 30,
	HapticType.SOFT: 5,
	HapticType.RIGID: 15
}

var haptics_enabled: bool = true
var _last_vibration_time: int = 0
const MIN_VIBRATION_INTERVAL_MS: int = 30  ## Minimum time between vibrations

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Trigger haptic feedback of specified type
func trigger(type: HapticType) -> void:
	if not haptics_enabled:
		return

	var current_time = Time.get_ticks_msec()
	if current_time - _last_vibration_time < MIN_VIBRATION_INTERVAL_MS:
		return

	_last_vibration_time = current_time
	var duration = HAPTIC_DURATIONS.get(type, 20)
	Input.vibrate_handheld(duration)

## Light impact - for single taps
func light_impact() -> void:
	trigger(HapticType.LIGHT)

## Medium impact - for double taps
func medium_impact() -> void:
	trigger(HapticType.MEDIUM)

## Heavy impact - for long press
func heavy_impact() -> void:
	trigger(HapticType.HEAVY)

## Success notification - for rapid taps
func success_notification() -> void:
	trigger(HapticType.SUCCESS)

## Soft impact - for ambient/zen mode
func soft_impact() -> void:
	trigger(HapticType.SOFT)

## Rigid impact - for sharp feedback
func rigid_impact() -> void:
	trigger(HapticType.RIGID)

## Perform a rumble pattern (multiple vibrations)
func rumble_pattern(count: int = 3, interval_ms: int = 80) -> void:
	if not haptics_enabled:
		return
	_perform_rumble(count, interval_ms)

func _perform_rumble(count: int, interval_ms: int) -> void:
	for i in range(count):
		Input.vibrate_handheld(30)
		if i < count - 1:
			await get_tree().create_timer(float(interval_ms) / 1000.0).timeout

## Toggle haptic feedback on/off
func toggle_haptics() -> void:
	haptics_enabled = not haptics_enabled

## Set haptic feedback enabled state
func set_enabled(enabled: bool) -> void:
	haptics_enabled = enabled
