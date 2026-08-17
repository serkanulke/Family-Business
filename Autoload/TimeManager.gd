extends Node

const START_DAY := 26
const START_MONTH := 1
const START_YEAR := 1985

signal date_changed(date_text: String)
signal pause_state_changed(is_paused: bool)
signal speed_changed(speed_multiplier: float)

var current_day: int = START_DAY
var current_month: int = START_MONTH
var current_year: int = START_YEAR

# The application opens on the main menu. Simulation time must not run
# until gameplay explicitly starts/resumes it.
var is_paused: bool = true
var speed_multiplier: float = 1.0

const DAY_DURATION := 0.5
const DAYS_IN_MONTH: Array[int] = [
	31,
	28,
	31,
	30,
	31,
	30,
	31,
	31,
	30,
	31,
	30,
	31
]

var day_timer := 0.0


func _process(delta: float) -> void:
	if is_paused:
		return

	day_timer += delta * speed_multiplier

	while day_timer >= DAY_DURATION:
		day_timer -= DAY_DURATION
		advance_day()


func get_date_string() -> String:
	var months = [
		"Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
	]

	return "%02d %s %04d" % [
		current_day,
		months[current_month - 1],
		current_year
	]


func advance_day() -> void:
	current_day += 1

	if current_day > DAYS_IN_MONTH[current_month - 1]:
		current_day = 1
		current_month += 1

		if current_month > 12:
			current_month = 1
			current_year += 1

	date_changed.emit(
		get_date_string()
	)


func pause() -> void:
	if is_paused:
		return

	is_paused = true
	pause_state_changed.emit(
		is_paused
	)


func play() -> void:
	if not is_paused:
		return

	is_paused = false
	pause_state_changed.emit(
		is_paused
	)


func set_speed_multiplier(value: float) -> void:
	var normalized_speed: float = value

	if is_equal_approx(value, 2.0):
		normalized_speed = 2.0
	elif is_equal_approx(value, 3.0):
		normalized_speed = 3.0
	else:
		normalized_speed = 1.0

	if is_equal_approx(speed_multiplier, normalized_speed):
		return

	speed_multiplier = normalized_speed
	speed_changed.emit(
		speed_multiplier
	)


func get_speed_multiplier() -> float:
	return speed_multiplier


func get_iso_date_string() -> String:
	return "%04d-%02d-%02d" % [
		current_year,
		current_month,
		current_day
	]


func reset_time() -> void:
	current_day = START_DAY
	current_month = START_MONTH
	current_year = START_YEAR

	day_timer = 0.0
	is_paused = true
	speed_multiplier = 1.0

	date_changed.emit(
		get_date_string()
	)
	pause_state_changed.emit(
		is_paused
	)
	speed_changed.emit(
		speed_multiplier
	)

	print(
		"Time reset: ",
		get_iso_date_string()
	)
