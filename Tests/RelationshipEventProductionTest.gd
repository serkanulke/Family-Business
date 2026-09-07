extends Node


var passed := 0
var failed := 0
var registry: EventDataRegistry


const FIRST_OPPORTUNITY_EVENTS := [
	"relationship_01_meet_18_20",
	"relationship_01_meet_21_23",
	"relationship_01_meet_24_26",
	"relationship_01_meet_27_29",
	"relationship_01_meet_guaranteed_30"
]

const PROBABILISTIC_FIRST_EVENTS := [
	"relationship_01_meet_18_20",
	"relationship_01_meet_21_23",
	"relationship_01_meet_24_26",
	"relationship_01_meet_27_29"
]

const FIRST_OPPORTUNITY_POOLS := {
	"relationship_meet_18_20_pool": 0.005,
	"relationship_meet_21_23_pool": 0.0075,
	"relationship_meet_24_26_pool": 0.01,
	"relationship_meet_27_29_pool": 0.0125
}

const FIRST_OPPORTUNITY_AGES := {
	"relationship_01_meet_18_20": [18, 20],
	"relationship_01_meet_21_23": [21, 23],
	"relationship_01_meet_24_26": [24, 26],
	"relationship_01_meet_27_29": [27, 29]
}


func _ready() -> void:
	print("")
	print("========================================")
	print("Relationship production tests starting")
	print("========================================")

	registry = EventDataRegistry.new()
	_assert(
		registry.load_all(),
		"Production Event registry validates",
		registry.get_diagnostic_text()
	)

	if registry.get_event("relationship_01_meet_18_20").is_empty():
		_finish()
		return

	_test_logical_event_structure()
	_test_first_opportunity_pools()
	_test_first_opportunity_age_bands()
	_test_guaranteed_first_opportunity_at_30()
	_test_first_opportunity_is_single_per_character()
	_test_candidate_materialization_contract()
	_test_followup_participant_continuity()
	_test_scheduled_flow_targets_and_context()
	_test_queue_flow_targets()
	_test_dating_start()
	_test_pre_dating_rejections_have_no_happiness_loss()
	_test_dating_end_happiness_penalties()
	_test_no_invented_breakup_effects_or_statuses()
	_test_event_20_delayed_loop()
	_test_event_21_delayed_loop()
	_test_proposal_to_wedding_flow()
	_test_wedding_choices()
	_test_choice_title_limit()
	_test_reference_choice_title_exact_limit()

	_finish()


func _test_logical_event_structure() -> void:
	var events: Array = registry.get_events_for_category("relationship", true)
	var logical_numbers: Dictionary = {}

	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var metadata_value = event.get("metadata", {})
		if typeof(metadata_value) != TYPE_DICTIONARY:
			continue
		var metadata: Dictionary = metadata_value
		var number := int(metadata.get("logical_event_number", 0))
		if number > 0:
			logical_numbers[number] = true

	var all_logical_events_present := true
	for number in range(1, 24):
		if not logical_numbers.has(number):
			all_logical_events_present = false
			break

	_assert(
		events.size() == 27
		and logical_numbers.size() == 23
		and all_logical_events_present,
		"Relationship JSON represents 23 logical Events with 27 technical definitions",
		"definitions=%d logical=%s" % [events.size(), str(logical_numbers.keys())]
	)

	_assert(
		registry.get_event("relationship_01_meet_30_plus").is_empty(),
		"No unapproved recurring 30+ Meet Someone definition exists"
	)

	_assert(
		registry.get_pool("relationship_meet_30_plus_pool").is_empty(),
		"No unapproved recurring 30+ Meet Someone pool exists"
	)


func _test_first_opportunity_pools() -> void:
	for pool_id in FIRST_OPPORTUNITY_POOLS:
		var record := registry.get_pool(String(pool_id))
		var pool: Dictionary = record.get("definition", {})
		var expected_chance := float(FIRST_OPPORTUNITY_POOLS[pool_id])

		_assert(
			not pool.is_empty()
			and String(pool.get("selection_mode", "")) == "weighted_one"
			and String(pool.get("selection_scope", "")) == "save"
			and int(pool.get("max_events", 0)) == 1
			and is_equal_approx(float(pool.get("activation_chance", -1.0)), expected_chance),
			"%s uses approved monthly activation chance" % String(pool_id),
			str(pool)
		)


func _test_first_opportunity_age_bands() -> void:
	for event_id in FIRST_OPPORTUNITY_AGES:
		var event := registry.get_event(String(event_id))
		var bounds: Array = FIRST_OPPORTUNITY_AGES[event_id]
		var expected_min := int(bounds[0])
		var expected_max := int(bounds[1])

		_assert(
			_has_requirement(event, "age", "primary", ">=", expected_min)
			and _has_requirement(event, "age", "primary", "<=", expected_max),
			"%s uses approved age band %d-%d" % [String(event_id), expected_min, expected_max]
		)

		_assert(
			String(event.get("trigger", {}).get("type", "")) == "calendar"
			and String(event.get("trigger", {}).get("cadence", {}).get("unit", "")) == "month"
			and int(event.get("trigger", {}).get("cadence", {}).get("interval", 0)) == 1,
			"%s is checked monthly" % String(event_id)
		)


func _test_guaranteed_first_opportunity_at_30() -> void:
	var event := registry.get_event("relationship_01_meet_guaranteed_30")

	_assert(
		not event.is_empty()
		and event.get("pool_id", null) == null
		and _has_requirement(event, "age", "primary", ">=", 30)
		and _has_requirement(event, "age", "primary", "<=", 54)
		and bool(event.get("metadata", {}).get("guaranteed_first_opportunity", false))
		and int(event.get("metadata", {}).get("guarantee_age", 0)) == 30,
		"Meet Someone is guaranteed from age 30 when no first opportunity was seen",
		str(event)
	)

	var excluded_ids := _event_seen_none_ids(event)
	var excludes_all_probabilistic_first_events := true
	for event_id in PROBABILISTIC_FIRST_EVENTS:
		if String(event_id) not in excluded_ids:
			excludes_all_probabilistic_first_events = false
			break

	_assert(
		excludes_all_probabilistic_first_events
		and excluded_ids.size() == 4,
		"Guaranteed age-30 Event is blocked after any earlier first opportunity",
		str(excluded_ids)
	)


func _test_first_opportunity_is_single_per_character() -> void:
	for event_id_value in FIRST_OPPORTUNITY_EVENTS:
		var event_id := String(event_id_value)
		var event := registry.get_event(event_id)

		_assert(
			String(event.get("repeat", {}).get("mode", "")) == "once_per_character",
			"%s is first-opportunity scoped once per Character" % event_id
		)

		var excluded_ids := _event_seen_none_ids(event)
		var expected_other_ids: Array = []
		for other_id_value in FIRST_OPPORTUNITY_EVENTS:
			var other_id := String(other_id_value)
			if other_id != event_id:
				expected_other_ids.append(other_id)

		# Guaranteed-at-30 only needs to exclude the four probabilistic versions.
		if event_id == "relationship_01_meet_guaranteed_30":
			expected_other_ids = PROBABILISTIC_FIRST_EVENTS.duplicate()

		var exclusive := true
		for expected_id_value in expected_other_ids:
			if String(expected_id_value) not in excluded_ids:
				exclusive = false
				break

		_assert(
			exclusive,
			"%s cannot become a second first opportunity" % event_id,
			"excluded=%s" % str(excluded_ids)
		)


func _test_candidate_materialization_contract() -> void:
	for event_id_value in FIRST_OPPORTUNITY_EVENTS:
		var event_id := String(event_id_value)
		var event := registry.get_event(event_id)
		var participants: Dictionary = event.get("participants", {})
		var primary: Dictionary = participants.get("primary", {})
		var candidate: Dictionary = participants.get("candidate", {})

		_assert(
			String(primary.get("type", "")) == "character"
			and String(primary.get("source", "")) == "trigger"
			and String(candidate.get("type", "")) == "relationship_npc"
			and String(candidate.get("source", "")) == "new_relationship_npc"
			and String(candidate.get("from", "")) == "primary",
			"%s creates the candidate only from the selected primary Character" % event_id,
			str(participants)
		)


func _test_followup_participant_continuity() -> void:
	var ok := true
	var detail := ""

	for event_value in registry.get_events_for_category("relationship", true):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var event_id := String(event.get("event_id", ""))
		if event_id in FIRST_OPPORTUNITY_EVENTS:
			continue

		var participants: Dictionary = event.get("participants", {})
		var primary: Dictionary = participants.get("primary", {})
		var candidate: Dictionary = participants.get("candidate", {})

		if (
			String(primary.get("type", "")) != "character"
			or String(primary.get("source", "")) != "context"
			or String(candidate.get("type", "")) != "relationship_npc"
			or String(candidate.get("source", "")) != "context"
		):
			ok = false
			detail = "%s participants=%s" % [event_id, str(participants)]
			break

	_assert(
		ok,
		"Every follow-up Event reuses the exact bound primary and candidate",
		detail
	)


func _test_scheduled_flow_targets_and_context() -> void:
	var ok := true
	var detail := ""
	var count := 0

	for event_value in registry.get_events_for_category("relationship", true):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		for effect_value in _event_effects(event):
			if typeof(effect_value) != TYPE_DICTIONARY:
				continue
			var effect: Dictionary = effect_value
			if String(effect.get("type", "")) != "schedule_event":
				continue

			count += 1
			var target_id := String(effect.get("event_id", ""))
			var target_event := registry.get_event(target_id)
			if (
				not bool(effect.get("inherit_context", false))
				or target_event.is_empty()
				or String(target_event.get("trigger", {}).get("type", "")) != "scheduled"
				or int(effect.get("delay", {}).get("value", 0)) <= 0
			):
				ok = false
				detail = "source=%s effect=%s target=%s" % [
					String(event.get("event_id", "")),
					str(effect),
					str(target_event.get("trigger", {}))
				]
				break
		if not ok:
			break

	_assert(
		ok and count > 0,
		"All Relationship schedule_event flows preserve participants/context and target scheduled Events",
		"count=%d %s" % [count, detail]
	)


func _test_queue_flow_targets() -> void:
	var ok := true
	var detail := ""
	var count := 0

	for event_value in registry.get_events_for_category("relationship", true):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		for effect_value in _event_effects(event):
			if typeof(effect_value) != TYPE_DICTIONARY:
				continue
			var effect: Dictionary = effect_value
			if String(effect.get("type", "")) != "queue_event":
				continue

			count += 1
			var target_id := String(effect.get("event_id", ""))
			var target_event := registry.get_event(target_id)
			if (
				target_event.is_empty()
				or String(target_event.get("trigger", {}).get("type", "")) != "chain"
			):
				ok = false
				detail = "source=%s effect=%s" % [
					String(event.get("event_id", "")),
					str(effect)
				]
				break
		if not ok:
			break

	_assert(
		ok and count == 1,
		"Relationship immediate queue flow is only the proposal Answer chain",
		"queue_event_count=%d %s" % [count, detail]
	)


func _test_dating_start() -> void:
	var event_7_effects := _choice_effects(
		"relationship_07_more_than_friends",
		"give_this_a_chance"
	)
	var event_8_effects := _choice_effects(
		"relationship_08_some_time_later",
		"ready_now"
	)

	_assert(
		_has_exact_effect(
			event_7_effects,
			{
				"type": "relationship_status_set",
				"target": "candidate",
				"value": "dating"
			}
		)
		and _has_schedule(event_7_effects, "relationship_09_first_few_months", "month", 3),
		"Event 7 starts dating and schedules Event 9 three months later",
		str(event_7_effects)
	)

	_assert(
		_has_exact_effect(
			event_8_effects,
			{
				"type": "relationship_status_set",
				"target": "candidate",
				"value": "dating"
			}
		)
		and _has_schedule(event_8_effects, "relationship_09_first_few_months", "month", 3),
		"Event 8 READY NOW starts dating and schedules Event 9 three months later",
		str(event_8_effects)
	)

	var status_set_count := 0
	var invalid_status := ""
	for event_value in registry.get_events_for_category("relationship", true):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		for effect_value in _event_effects(event):
			if typeof(effect_value) != TYPE_DICTIONARY:
				continue
			var effect: Dictionary = effect_value
			if String(effect.get("type", "")) != "relationship_status_set":
				continue
			status_set_count += 1
			if String(effect.get("value", "")) != "dating":
				invalid_status = String(effect.get("value", ""))

	_assert(
		status_set_count == 2 and invalid_status.is_empty(),
		"Dating is the only Event-authored Relationship status in this chain",
		"count=%d invalid=%s" % [status_set_count, invalid_status]
	)


func _test_pre_dating_rejections_have_no_happiness_loss() -> void:
	var cases := [
		["relationship_01_meet_18_20", "not_interested"],
		["relationship_01_meet_21_23", "not_interested"],
		["relationship_01_meet_24_26", "not_interested"],
		["relationship_01_meet_27_29", "not_interested"],
		["relationship_01_meet_guaranteed_30", "not_interested"],
		["relationship_02_message_later", "politely_decline"],
		["relationship_06_keeping_it_casual", "just_be_friends"],
		["relationship_07_more_than_friends", "dont_feel_same"],
		["relationship_08_some_time_later", "still_need_time"],
		["relationship_08_some_time_later", "end_this"]
	]

	var ok := true
	var detail := ""

	for case_value in cases:
		var case: Array = case_value
		var effects := _choice_effects(String(case[0]), String(case[1]))
		if _happiness_delta(effects, "primary") != 0:
			ok = false
			detail = "%s/%s effects=%s" % [String(case[0]), String(case[1]), str(effects)]
			break

	_assert(
		ok,
		"All pre-dating rejection/end choices have no Happiness penalty",
		detail
	)


func _test_dating_end_happiness_penalties() -> void:
	var expected := [
		["relationship_12_something_feels_off", "end_relationship", -3],
		["relationship_16_honest_conversation", "end_relationship", -6],
		["relationship_18_more_time_together", "end_relationship", -6],
		["relationship_19_difficult_choice", "end_things_here", -10]
	]

	var ok := true
	var detail := ""

	for case_value in expected:
		var case: Array = case_value
		var effects := _choice_effects(String(case[0]), String(case[1]))
		var actual := _happiness_delta(effects, "primary")
		if actual != int(case[2]):
			ok = false
			detail = "%s/%s expected=%d actual=%d effects=%s" % [
				String(case[0]),
				String(case[1]),
				int(case[2]),
				actual,
				str(effects)
			]
			break

	_assert(
		ok,
		"Dating-end choices use approved -3 / -6 / -10 Happiness stages",
		detail
	)


func _test_no_invented_breakup_effects_or_statuses() -> void:
	var forbidden_types := [
		"relationship_end_dating",
		"relationship_end",
		"relationship_breakup",
		"relationship_status_change"
	]
	var forbidden_found := ""
	var forbidden_status := ""

	for event_value in registry.get_events_for_category("relationship", true):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		for effect_value in _event_effects(event):
			if typeof(effect_value) != TYPE_DICTIONARY:
				continue
			var effect: Dictionary = effect_value
			var effect_type := String(effect.get("type", ""))
			if effect_type in forbidden_types:
				forbidden_found = effect_type
				break
			if (
				effect_type == "relationship_status_set"
				and String(effect.get("value", "")) != "dating"
			):
				forbidden_status = String(effect.get("value", ""))
				break
		if not forbidden_found.is_empty() or not forbidden_status.is_empty():
			break

	_assert(
		forbidden_found.is_empty() and forbidden_status.is_empty(),
		"No breakup/ex-partner/divorced parallel Event state is invented",
		"effect=%s status=%s" % [forbidden_found, forbidden_status]
	)


func _test_event_20_delayed_loop() -> void:
	var event := registry.get_event("relationship_20_next_step")
	var effects := _choice_effects("relationship_20_next_step", "not_yet")

	_assert(
		String(event.get("repeat", {}).get("mode", "")) == "repeatable"
		and _has_schedule(effects, "relationship_20_next_step", "month", 6),
		"Event 20 NOT YET schedules Event 20 again after 6 months",
		str(effects)
	)

	var ready_effects := _choice_effects("relationship_20_next_step", "ready")
	_assert(
		_has_schedule(
			ready_effects,
			"relationship_21_question_to_ask",
			"day",
			1
		),
		"Event 20 I'M READY advances to Event 21",
		str(ready_effects)
	)


func _test_event_21_delayed_loop() -> void:
	var event := registry.get_event("relationship_21_question_to_ask")
	var wait_effects := _choice_effects(
		"relationship_21_question_to_ask",
		"wait_better_time"
	)

	_assert(
		String(event.get("repeat", {}).get("mode", "")) == "repeatable"
		and _has_schedule(
			wait_effects,
			"relationship_21_question_to_ask",
			"month",
			3
		),
		"Event 21 WAIT FOR A BETTER TIME schedules Event 21 again after 3 months",
		str(wait_effects)
	)


func _test_proposal_to_wedding_flow() -> void:
	var ask_effects := _choice_effects(
		"relationship_21_question_to_ask",
		"ask_to_marry"
	)
	var answer := registry.get_event("relationship_22_the_answer")
	var answer_effects := _choice_effects(
		"relationship_22_the_answer",
		"plan_wedding"
	)

	_assert(
		_has_queue(ask_effects, "relationship_22_the_answer")
		and String(answer.get("trigger", {}).get("type", "")) == "chain",
		"Proposal immediately queues Event 22 THE ANSWER",
		"ask=%s trigger=%s" % [str(ask_effects), str(answer.get("trigger", {}))]
	)

	var answer_has_marriage := false
	for effect_value in answer_effects:
		if (
			typeof(effect_value) == TYPE_DICTIONARY
			and String(effect_value.get("type", "")) == "relationship_marry"
		):
			answer_has_marriage = true

	_assert(
		not answer_has_marriage
		and _has_schedule(
			answer_effects,
			"relationship_23_the_wedding",
			"month",
			1
		),
		"Event 22 accepts the proposal but marriage happens only at Event 23",
		str(answer_effects)
	)


func _test_wedding_choices() -> void:
	var simple := _choice(
		"relationship_23_the_wedding",
		"keep_it_simple"
	)
	var special := _choice(
		"relationship_23_the_wedding",
		"make_it_special"
	)
	var all_out := _choice(
		"relationship_23_the_wedding",
		"go_all_out"
	)

	_assert(
		_cost_is(simple, "money", 500)
		and _happiness_delta(_choice_effects("relationship_23_the_wedding", "keep_it_simple"), "primary") == 1
		and _happiness_delta(_choice_effects("relationship_23_the_wedding", "keep_it_simple"), "candidate") == 1
		and _has_marriage(_choice_effects("relationship_23_the_wedding", "keep_it_simple")),
		"KEEP IT SIMPLE costs 500, gives +1 Happiness each, then marries"
	)

	_assert(
		_cost_is(special, "money", 10000)
		and _happiness_delta(_choice_effects("relationship_23_the_wedding", "make_it_special"), "primary") == 4
		and _happiness_delta(_choice_effects("relationship_23_the_wedding", "make_it_special"), "candidate") == 4
		and _has_marriage(_choice_effects("relationship_23_the_wedding", "make_it_special")),
		"MAKE IT SPECIAL costs 10,000, gives +4 Happiness each, then marries"
	)

	var all_out_effects := _choice_effects(
		"relationship_23_the_wedding",
		"go_all_out"
	)
	_assert(
		_cost_is(all_out, "money", 30000)
		and _happiness_delta(all_out_effects, "primary") == 8
		and _happiness_delta(all_out_effects, "candidate") == 8
		and _contains_stat_change(all_out_effects, "social", 2)
		and _has_marriage(all_out_effects),
		"GO ALL OUT costs 30,000, gives +8 Happiness each, +2 Social, then marries",
		str(all_out_effects)
	)

	for choice_value in [simple, special, all_out]:
		var choice: Dictionary = choice_value
		var marriage_count := 0
		for effect_value in choice.get("resolution", {}).get("effects", []):
			if (
				typeof(effect_value) == TYPE_DICTIONARY
				and String(effect_value.get("type", "")) == "relationship_marry"
			):
				marriage_count += 1
		_assert(
			marriage_count == 1,
			"%s invokes canonical marriage exactly once" % String(choice.get("title", "")),
			"marriage_count=%d" % marriage_count
		)


func _test_choice_title_limit() -> void:
	var ok := true
	var detail := ""

	for event_value in registry.get_events_for_category("relationship", true):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		for choice_value in event.get("choices", []):
			if typeof(choice_value) != TYPE_DICTIONARY:
				continue
			var choice: Dictionary = choice_value
			var title := String(choice.get("title", ""))
			if title.length() > 28:
				ok = false
				detail = "%s/%s = %d chars" % [
					String(event.get("event_id", "")),
					title,
					title.length()
				]
				break
		if not ok:
			break

	_assert(
		ok,
		"All Relationship choice titles are at most 28 characters including spaces",
		detail
	)


func _test_reference_choice_title_exact_limit() -> void:
	var choice := _choice(
		"relationship_09_first_few_months",
		"develop_naturally"
	)
	var title := String(choice.get("title", ""))

	_assert(
		title == "LET THINGS DEVELOP NATURALLY"
		and title.length() == 28,
		"LET THINGS DEVELOP NATURALLY is preserved exactly at the 28-character limit",
		"%s (%d)" % [title, title.length()]
	)


func _choice(event_id: String, choice_id: String) -> Dictionary:
	var event := registry.get_event(event_id)
	for choice_value in event.get("choices", []):
		if (
			typeof(choice_value) == TYPE_DICTIONARY
			and String(choice_value.get("choice_id", "")) == choice_id
		):
			return choice_value
	return {}


func _choice_effects(event_id: String, choice_id: String) -> Array:
	var choice := _choice(event_id, choice_id)
	var effects_value = choice.get("resolution", {}).get("effects", [])
	return effects_value if typeof(effects_value) == TYPE_ARRAY else []


func _event_effects(event: Dictionary) -> Array:
	var result: Array = []

	if typeof(event.get("default_resolution", null)) == TYPE_DICTIONARY:
		_append_resolution_effects(event["default_resolution"], result)

	for choice_value in event.get("choices", []):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var resolution_value = choice_value.get("resolution", null)
		if typeof(resolution_value) == TYPE_DICTIONARY:
			_append_resolution_effects(resolution_value, result)

	return result


func _append_resolution_effects(resolution: Dictionary, output: Array) -> void:
	var mode := String(resolution.get("mode", ""))

	if mode == "deterministic":
		var effects_value = resolution.get("effects", [])
		if typeof(effects_value) == TYPE_ARRAY:
			output.append_array(effects_value)
		return

	if mode == "weighted":
		for outcome_value in resolution.get("outcomes", []):
			if typeof(outcome_value) != TYPE_DICTIONARY:
				continue
			var effects_value = outcome_value.get("effects", [])
			if typeof(effects_value) == TYPE_ARRAY:
				output.append_array(effects_value)
		return

	if mode == "score_check":
		for key in ["success", "failure"]:
			var result_value = resolution.get(key, null)
			if typeof(result_value) != TYPE_DICTIONARY:
				continue
			var effects_value = result_value.get("effects", [])
			if typeof(effects_value) == TYPE_ARRAY:
				output.append_array(effects_value)


func _has_requirement(
	event: Dictionary,
	requirement_type: String,
	target: String,
	operator: String,
	expected
) -> bool:
	var requirements: Dictionary = event.get("requirements", {})
	for requirement_value in requirements.get("all", []):
		if typeof(requirement_value) != TYPE_DICTIONARY:
			continue
		var requirement: Dictionary = requirement_value
		if (
			String(requirement.get("type", "")) == requirement_type
			and String(requirement.get("target", "")) == target
			and String(requirement.get("operator", "")) == operator
			and requirement.get("value", null) == expected
		):
			return true
	return false


func _event_seen_none_ids(event: Dictionary) -> Array:
	var result: Array = []
	var requirements: Dictionary = event.get("requirements", {})

	for group_value in requirements.get("all", []):
		if typeof(group_value) != TYPE_DICTIONARY:
			continue
		var group: Dictionary = group_value
		var none_value = group.get("none", null)
		if typeof(none_value) != TYPE_ARRAY:
			continue

		for requirement_value in none_value:
			if typeof(requirement_value) != TYPE_DICTIONARY:
				continue
			var requirement: Dictionary = requirement_value
			if String(requirement.get("type", "")) == "event_seen":
				result.append(String(requirement.get("value", "")))

	return result


func _has_schedule(
	effects: Array,
	target_event_id: String,
	unit: String,
	value: int
) -> bool:
	for effect_value in effects:
		if typeof(effect_value) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_value
		if (
			String(effect.get("type", "")) == "schedule_event"
			and String(effect.get("event_id", "")) == target_event_id
			and String(effect.get("delay", {}).get("unit", "")) == unit
			and int(effect.get("delay", {}).get("value", 0)) == value
			and bool(effect.get("inherit_context", false))
		):
			return true
	return false


func _has_queue(effects: Array, target_event_id: String) -> bool:
	for effect_value in effects:
		if (
			typeof(effect_value) == TYPE_DICTIONARY
			and String(effect_value.get("type", "")) == "queue_event"
			and String(effect_value.get("event_id", "")) == target_event_id
		):
			return true
	return false


func _has_exact_effect(effects: Array, expected: Dictionary) -> bool:
	for effect_value in effects:
		if typeof(effect_value) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_value
		var matches := true
		for key in expected:
			if not effect.has(key) or effect[key] != expected[key]:
				matches = false
				break
		if matches:
			return true
	return false


func _happiness_delta(effects: Array, target: String) -> int:
	var total := 0
	for effect_value in effects:
		if typeof(effect_value) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_value
		if (
			String(effect.get("type", "")) == "stat_change"
			and String(effect.get("target", "")) == target
			and String(effect.get("stat", "")) == "happiness"
		):
			total += int(effect.get("amount", 0))
	return total


func _contains_stat_change(
	effects: Array,
	stat: String,
	amount: int
) -> bool:
	for effect_value in effects:
		if typeof(effect_value) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_value
		if (
			String(effect.get("type", "")) == "stat_change"
			and String(effect.get("stat", "")) == stat
			and int(effect.get("amount", 0)) == amount
		):
			return true
	return false


func _has_marriage(effects: Array) -> bool:
	for effect_value in effects:
		if (
			typeof(effect_value) == TYPE_DICTIONARY
			and String(effect_value.get("type", "")) == "relationship_marry"
			and String(effect_value.get("primary", "")) == "primary"
			and String(effect_value.get("target", "")) == "candidate"
		):
			return true
	return false


func _cost_is(choice: Dictionary, currency: String, amount: int) -> bool:
	var cost_value = choice.get("cost", null)
	return (
		typeof(cost_value) == TYPE_DICTIONARY
		and String(cost_value.get("currency", "")) == currency
		and int(cost_value.get("amount", -1)) == amount
	)


func _assert(condition: bool, test_name: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)
		if not detail.is_empty():
			print(detail)


func _finish() -> void:
	print("")
	print("========================================")
	print("Relationship production tests: ", passed, " passed / ", failed, " failed")
	print("========================================")

	if failed == 0:
		print("ALL RELATIONSHIP PRODUCTION TESTS PASSED.")
	else:
		push_error("Relationship production tests have %d failing test(s)." % failed)

	get_tree().quit(0 if failed == 0 else 1)
