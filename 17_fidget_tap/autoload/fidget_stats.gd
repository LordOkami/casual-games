extends Node
## FidgetStats: Tracks and persists tap statistics
## Saves to user:// for persistence between sessions

signal stats_updated

const SAVE_PATH: String = "user://fidget_stats.save"

## Statistics data
var total_lifetime_taps: int = 0
var session_taps: int = 0
var best_session_taps: int = 0
var fastest_tap_streak: int = 0  ## Taps per second record
var current_streak: int = 0

## Tracking for streak calculation
var _streak_start_time: float = 0.0
var _streak_taps: int = 0
const STREAK_WINDOW_SEC: float = 1.0  ## Window for measuring taps per second

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_stats()

## Record a tap event
func record_tap() -> void:
	total_lifetime_taps += 1
	session_taps += 1
	_update_streak()
	emit_signal("stats_updated")
	_auto_save()

## Update tap streak tracking
func _update_streak() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0

	if _streak_start_time == 0.0 or current_time - _streak_start_time > STREAK_WINDOW_SEC:
		# Start new streak window
		_streak_start_time = current_time
		_streak_taps = 1
	else:
		# Continue current streak
		_streak_taps += 1

		# Calculate taps per second within the window
		var elapsed = current_time - _streak_start_time
		if elapsed > 0.1:  # Minimum window to calculate
			var taps_per_second = int(float(_streak_taps) / elapsed)
			if taps_per_second > fastest_tap_streak:
				fastest_tap_streak = taps_per_second

	current_streak = _streak_taps

## Reset session stats (called when returning to menu)
func reset_session() -> void:
	if session_taps > best_session_taps:
		best_session_taps = session_taps
	session_taps = 0
	current_streak = 0
	_streak_start_time = 0.0
	_streak_taps = 0
	_save_stats()
	emit_signal("stats_updated")

## Get formatted statistics for display
func get_stats_text() -> String:
	return "Session: %d | Best: %d | Lifetime: %d" % [session_taps, best_session_taps, total_lifetime_taps]

## Get detailed statistics dictionary
func get_all_stats() -> Dictionary:
	return {
		"session_taps": session_taps,
		"best_session_taps": best_session_taps,
		"total_lifetime_taps": total_lifetime_taps,
		"fastest_tap_streak": fastest_tap_streak,
		"current_streak": current_streak
	}

var _save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 5.0

func _auto_save() -> void:
	# Save periodically rather than on every tap for performance
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _save_timer > AUTO_SAVE_INTERVAL:
		_save_timer = current_time
		_save_stats()

func _save_stats() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"total_lifetime_taps": total_lifetime_taps,
			"best_session_taps": best_session_taps,
			"fastest_tap_streak": fastest_tap_streak
		}
		file.store_var(data)

func _load_stats() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			if data is Dictionary:
				total_lifetime_taps = data.get("total_lifetime_taps", 0)
				best_session_taps = data.get("best_session_taps", 0)
				fastest_tap_streak = data.get("fastest_tap_streak", 0)

## Called when app is about to close
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		reset_session()
		_save_stats()
