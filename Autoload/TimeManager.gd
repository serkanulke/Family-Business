extends Node

signal date_changed(date_text: String)

var current_day: int = 26
var current_month: int = 1
var current_year: int = 1985

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
