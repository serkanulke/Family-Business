class_name GameCalendar
extends RefCounted


static func is_leap_year(year: int) -> bool:
	return year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)


static func days_in_month(year: int, month: int) -> int:
	if month < 1 or month > 12:
		return 0
	var lengths := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if month == 2 and is_leap_year(year):
		return 29
	return lengths[month - 1]


static func parse_iso_date(date_text: String) -> Dictionary:
	var parts := date_text.split("-")
	if parts.size() != 3:
		return {"valid": false}
	if not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return {"valid": false}
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	if year < 1 or month < 1 or month > 12 or day < 1 or day > days_in_month(year, month):
		return {"valid": false}
	return {"valid": true, "year": year, "month": month, "day": day}


static func format_iso_date(year: int, month: int, day: int) -> String:
	if year < 1 or month < 1 or month > 12:
		return ""
	var clamped_day := clampi(day, 1, days_in_month(year, month))
	return "%04d-%02d-%02d" % [year, month, clamped_day]


static func date_to_ordinal(date_text: String) -> int:
	var parsed := parse_iso_date(date_text)
	if not bool(parsed.get("valid", false)):
		return -1
	var year := int(parsed["year"])
	var month := int(parsed["month"])
	var day := int(parsed["day"])
	var previous_year := year - 1
	var ordinal := 365 * previous_year
	ordinal += floori(float(previous_year) / 4.0)
	ordinal -= floori(float(previous_year) / 100.0)
	ordinal += floori(float(previous_year) / 400.0)
	for current_month in range(1, month):
		ordinal += days_in_month(year, current_month)
	return ordinal + day


static func ordinal_to_date(ordinal: int) -> String:
	if ordinal < 1:
		return ""
	var year := maxi(1, floori(float(ordinal - 1) / 365.2425) + 1)
	while date_to_ordinal("%04d-01-01" % year) > ordinal:
		year -= 1
	while date_to_ordinal("%04d-12-31" % year) < ordinal:
		year += 1
	var remaining := ordinal - date_to_ordinal("%04d-01-01" % year) + 1
	var month := 1
	while remaining > days_in_month(year, month):
		remaining -= days_in_month(year, month)
		month += 1
	return format_iso_date(year, month, remaining)


static func compare(left: String, right: String) -> int:
	var left_ordinal := date_to_ordinal(left)
	var right_ordinal := date_to_ordinal(right)
	if left_ordinal < 0 or right_ordinal < 0:
		return 0
	return -1 if left_ordinal < right_ordinal else (1 if left_ordinal > right_ordinal else 0)


static func add_days(date_text: String, amount: int) -> String:
	var ordinal := date_to_ordinal(date_text)
	return "" if ordinal < 1 or ordinal + amount < 1 else ordinal_to_date(ordinal + amount)


static func add_months(date_text: String, amount: int) -> String:
	var parsed := parse_iso_date(date_text)
	if not bool(parsed.get("valid", false)):
		return ""
	var total_month := int(parsed["year"]) * 12 + int(parsed["month"]) - 1 + amount
	if total_month < 12:
		return ""
	var year := floori(float(total_month) / 12.0)
	var month := total_month - year * 12 + 1
	return format_iso_date(year, month, mini(int(parsed["day"]), days_in_month(year, month)))


static func add_years(date_text: String, amount: int) -> String:
	var parsed := parse_iso_date(date_text)
	if not bool(parsed.get("valid", false)):
		return ""
	var year := int(parsed["year"]) + amount
	if year < 1:
		return ""
	var month := int(parsed["month"])
	return format_iso_date(year, month, mini(int(parsed["day"]), days_in_month(year, month)))


static func add_interval(date_text: String, unit: String, amount: int) -> String:
	match unit:
		"day": return add_days(date_text, amount)
		"week": return add_days(date_text, amount * 7)
		"month": return add_months(date_text, amount)
		"year": return add_years(date_text, amount)
	return ""


static func month_distance(from_date: String, to_date: String) -> int:
	var from := parse_iso_date(from_date)
	var to := parse_iso_date(to_date)
	if not bool(from.get("valid", false)) or not bool(to.get("valid", false)):
		return -1
	return (int(to["year"]) - int(from["year"])) * 12 + int(to["month"]) - int(from["month"])


static func resolve_date_point(value, year: int) -> String:
	if typeof(value) == TYPE_STRING:
		return String(value) if bool(parse_iso_date(String(value)).get("valid", false)) else ""
	if typeof(value) != TYPE_DICTIONARY:
		return ""
	var point: Dictionary = value
	var target_year := int(point.get("year", year))
	var month := int(point.get("month", 0))
	var day := int(point.get("day", 0))
	if day > days_in_month(target_year, month):
		return ""
	return format_iso_date(target_year, month, day)
