class_name EventCalendarTriggerEvaluator
extends RefCounted


var anchor_date: String


func _init(p_anchor_date: String = "1985-01-26") -> void:
	anchor_date = p_anchor_date


func get_occurrence(event: Dictionary, date_text: String) -> Dictionary:
	var trigger_value = event.get("trigger", {})
	if typeof(trigger_value) != TYPE_DICTIONARY:
		return _no_match()
	var trigger: Dictionary = trigger_value
	if String(trigger.get("type", "")) != "calendar":
		return _no_match()
	var date := GameCalendar.parse_iso_date(date_text)
	if not bool(date.get("valid", false)):
		return _no_match()
	if trigger.has("cadence"):
		return _cadence_occurrence(trigger["cadence"], date_text)
	if trigger.has("exact_date"):
		return _exact_date_occurrence(trigger["exact_date"], date_text)
	if trigger.has("date_window"):
		return _window_occurrence(trigger["date_window"], date_text)
	return _no_match()


func _cadence_occurrence(value, date_text: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _no_match()
	var cadence: Dictionary = value
	var unit := String(cadence.get("unit", ""))
	var interval := int(cadence.get("interval", 0))
	if interval <= 0:
		return _no_match()
	var anchor := GameCalendar.parse_iso_date(anchor_date)
	var current := GameCalendar.parse_iso_date(date_text)
	if not bool(anchor.get("valid", false)) or not bool(current.get("valid", false)):
		return _no_match()
	match unit:
		"day", "week":
			var distance := GameCalendar.date_to_ordinal(date_text) - GameCalendar.date_to_ordinal(anchor_date)
			var step := interval if unit == "day" else interval * 7
			if distance < 0 or distance % step != 0:
				return _no_match()
			return _match("cadence:%s:%d" % [unit, floori(float(distance) / float(step))])
		"month":
			var distance := GameCalendar.month_distance(anchor_date, date_text)
			if distance < 0 or distance % interval != 0:
				return _no_match()
			var due_date := GameCalendar.add_months(anchor_date, distance)
			if due_date != date_text:
				return _no_match()
			return _match("cadence:month:%d" % floori(float(distance) / float(interval)))
		"year":
			var distance := int(current["year"]) - int(anchor["year"])
			if distance < 0 or distance % interval != 0:
				return _no_match()
			var due_date := GameCalendar.add_years(anchor_date, distance)
			if due_date != date_text:
				return _no_match()
			return _match("cadence:year:%d" % floori(float(distance) / float(interval)))
	return _no_match()


func _exact_date_occurrence(value, date_text: String) -> Dictionary:
	var current := GameCalendar.parse_iso_date(date_text)
	if not bool(current.get("valid", false)):
		return _no_match()
	var resolved := GameCalendar.resolve_date_point(value, int(current["year"]))
	if resolved != date_text:
		return _no_match()
	var key := "exact:%s" % resolved
	if typeof(value) == TYPE_DICTIONARY and not value.has("year"):
		key = "annual:%04d" % int(current["year"])
	return _match(key)


func _window_occurrence(value, date_text: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _no_match()
	var window: Dictionary = value
	var current := GameCalendar.parse_iso_date(date_text)
	if not bool(current.get("valid", false)):
		return _no_match()
	var year := int(current["year"])
	var start_value = window.get("start", null)
	var end_value = window.get("end", null)
	var annual: bool = (
		typeof(start_value) == TYPE_DICTIONARY and not start_value.has("year")
		and typeof(end_value) == TYPE_DICTIONARY and not end_value.has("year")
	)
	if not annual:
		var start := GameCalendar.resolve_date_point(start_value, year)
		var end := GameCalendar.resolve_date_point(end_value, year)
		if start.is_empty() or end.is_empty() or GameCalendar.compare(date_text, start) < 0 or GameCalendar.compare(date_text, end) > 0:
			return _no_match()
		return _match("window:%s:%s" % [start, end])

	var start_this_year := GameCalendar.resolve_date_point(start_value, year)
	var end_this_year := GameCalendar.resolve_date_point(end_value, year)
	if start_this_year.is_empty() or end_this_year.is_empty():
		return _no_match()
	if GameCalendar.compare(start_this_year, end_this_year) <= 0:
		if GameCalendar.compare(date_text, start_this_year) < 0 or GameCalendar.compare(date_text, end_this_year) > 0:
			return _no_match()
		return _match("annual_window:%04d" % year)
	if GameCalendar.compare(date_text, start_this_year) >= 0:
		return _match("annual_window:%04d" % year)
	if GameCalendar.compare(date_text, end_this_year) <= 0:
		return _match("annual_window:%04d" % (year - 1))
	return _no_match()


func _match(key: String) -> Dictionary:
	return {"matches": true, "occurrence_key": key}


func _no_match() -> Dictionary:
	return {"matches": false, "occurrence_key": ""}
