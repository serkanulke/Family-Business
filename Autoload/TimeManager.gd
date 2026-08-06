extends Node

const START_DAY := 26
const START_MONTH := 1
const START_YEAR := 1985

signal date_changed(date_text: String)

var current_day: int = START_DAY
var current_month: int = START_MONTH
var current_year: int = START_YEAR

var is_paused: bool = false


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


func _process(delta):
	if is_paused:
		return
	
	day_timer += delta

	if day_timer >= DAY_DURATION:
		day_timer = 0.0
		advance_day()

func get_date_string() -> String:
	var months = [
		"Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
	]

	return "%02d %s %04d" % [current_day, months[current_month - 1], current_year]

func advance_day():
	current_day += 1

	if current_day > DAYS_IN_MONTH[current_month - 1]:
		current_day = 1
		current_month += 1

		if current_month > 12:
			current_month = 1
			current_year += 1

	date_changed.emit(get_date_string())
	
func pause():
	is_paused = true

func play():
	is_paused = false

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

	date_changed.emit(
		get_date_string()
	)

	print(
		"Time reset: ",
		get_iso_date_string()
	)
