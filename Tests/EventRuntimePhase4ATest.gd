extends Node


const ITEM_ID := "accessory_common_black_gold_browline_sunglasses_007"
const FLAG_ID := 1001

var passed := 0
var failed := 0
var original: Dictionary = {}


func _ready() -> void:
	_store_state()
	_setup()
	_test_deterministic_cost_effect_history_and_cooldown()
	_test_choice_revalidation_and_atomic_preflight()
	_test_resolution_transaction_rollback()
	_test_weighted_score_and_random_state()
	_test_item_determinism_and_ownership_guards()
	_test_domain_manager_delegation()
	_test_event_flow_effects()
	_test_runtime_export_import_and_reset()
	_restore_state()
	print("========================================")
	print("Event Phase 4A tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_deterministic_cost_effect_history_and_cooldown() -> void:
	_setup()
	var event := _event("phase4_deterministic", [
		{"type":"stat_change","target":"primary","stat":"health","amount":5},
		{"type":"add_flag","target":"primary","flag_id":FLAG_ID,"feedback":{"mode":"custom","text":"A private story state changed."}},
		{"type":"money_change","amount":10},
		{"type":"diamond_change","amount":-1},
	])
	event.cost = {"currency":"money","amount":100}
	event.choices[0].cost = {"currency":"diamonds","amount":2}
	event.repeat = {"mode":"once_per_character"}
	event.cooldown = {"scope":"character","unit":"month","value":1}
	_configure([event])
	GameManager.family_money = 1000; GameManager.diamonds = 10
	CharacterManager.characters[0].health = 98
	_assert(EventManager.activate_chain(event.event_id, {"primary":1}).queued, "Deterministic fixture activates")
	var result := EventManager.resolve_active_event("continue")
	_assert(result.resolved and result.effect_results.size() == 4, "Deterministic choice resolves every effect", JSON.stringify(result))
	_assert(CharacterManager.characters[0].health == 100 and result.effect_results[0].applied_amount == 2, "Stat feedback reports clamp-aware applied amount")
	_assert(GameManager.family_money == 910 and GameManager.diamonds == 7, "Event and choice costs commit with economy effects")
	_assert(FLAG_ID in CharacterManager.characters[0].flag_ids and result.effect_results[1].display.text == "A private story state changed." and not JSON.stringify(result.effect_results[1]).contains(str(FLAG_ID)), "Custom flag feedback hides the internal flag ID", JSON.stringify({"flags":CharacterManager.characters[0].flag_ids,"result":result.effect_results[1]}))
	_assert(EventManager.story_history.records.size() == 1 and EventManager.story_history.has_choice(event.event_id, "continue", {"primary":1}, {}), "Story history records instance and choice")
	_assert(EventManager.story_history.has_completed(event.event_id, {"primary":1}, {}) and EventManager.state_provider.is_completed_non_repeatable(event, {"primary":1}, {}), "History and repeat state commit only on completion")
	_assert(EventManager.state_provider.is_on_cooldown(event, {"primary":1}, {}), "Cooldown begins at successful completion")
	var remove_flag := _event("remove_flag_explicitly", [{"type":"remove_flag","target":"primary","flag_id":FLAG_ID}])
	_configure([remove_flag])
	EventManager.activate_chain(remove_flag.event_id, {"primary":1})
	_assert(
		EventManager.resolve_active_event("continue").resolved
		and FLAG_ID not in CharacterManager.characters[0].flag_ids,
		"Flag removal is an explicit Event effect rather than an EventManager timer"
	)


func _test_choice_revalidation_and_atomic_preflight() -> void:
	_setup()
	var locked := _event("choice_locked", [{"type":"money_change","amount":50}])
	locked.choices[0].requirements = {"all":[{"type":"money","operator":">=","value":500}]}
	locked.choices[0].cost = {"currency":"money","amount":25}
	_configure([locked])
	GameManager.family_money = 600
	EventManager.activate_chain(locked.event_id, {"primary":1})
	GameManager.family_money = 100
	var locked_result := EventManager.resolve_active_event("continue")
	_assert(not locked_result.resolved and GameManager.family_money == 100 and EventManager.active_event != null, "Choice requirements are revalidated immediately before resolution")
	EventManager.cancel_active_event()

	var atomic := _event("atomic_failure", [
		{"type":"stat_change","target":"primary","stat":"health","amount":10},
		{"type":"remove_item","target":"primary","item_id":ITEM_ID},
	])
	atomic.cost = {"currency":"money","amount":100}
	_configure([atomic])
	GameManager.family_money = 1000; CharacterManager.characters[0].health = 50
	EventManager.activate_chain(atomic.event_id, {"primary":1})
	var atomic_result := EventManager.resolve_active_event("continue")
	_assert(not atomic_result.resolved and CharacterManager.characters[0].health == 50 and GameManager.family_money == 1000, "Effect preflight prevents partial mutation and cost commitment")
	_assert(atomic_result.effect_results.size() == 1 and atomic_result.effect_results[0].code == "item_instance_unavailable", "Failed Item effect returns a structured failure result")
	_assert(EventManager.story_history.records.is_empty() and EventManager.state_provider.completed_repeat_records.is_empty(), "Failed resolution writes no completed history or repeat state")
	EventManager.cancel_active_event()

	_setup()
	CharacterManager.characters[0].merge({"job_id":7001,"company_id":"external_company","salary":2000}, true)
	var conflicting := _event("conflicting_authoritative_effects", [
		{"type":"salary_increase","target":"primary","amount":100},
		{"type":"salary_increase","target":"primary","amount":200},
	])
	conflicting.cost = {"currency":"money","amount":100}
	_configure([conflicting])
	GameManager.family_money = 1000
	EventManager.activate_chain(conflicting.event_id, {"primary":1})
	var conflicting_result := EventManager.resolve_active_event("continue")
	_assert(not conflicting_result.resolved and CharacterManager.characters[0].salary == 2000 and GameManager.family_money == 1000, "Conflicting authoritative mutations fail before any cost or domain change")
	_assert(conflicting_result.effect_results.size() == 1 and conflicting_result.effect_results[0].code == "conflicting_effects", "Atomic conflict returns a structured failure result")
	EventManager.cancel_active_event()


func _test_resolution_transaction_rollback() -> void:
	_setup()
	var preflight_failure := _event("weighted_preflight_failure", [])
	preflight_failure.choices[0].resolution = {"mode":"weighted","outcomes":[{"outcome_id":"blocked","weight":1.0,"effects":[{"type":"remove_item","target":"primary","item_id":ITEM_ID}]}]}
	_configure([preflight_failure])
	EventManager.activate_chain(preflight_failure.event_id, {"primary":1})
	var preflight_rng_before := EventManager.resolution_resolver.export_state()
	var preflight_result := EventManager.resolve_active_event("continue")
	var preflight_rng_after := EventManager.resolution_resolver.export_state()
	_assert(
		not preflight_result.resolved
		and preflight_rng_after.seed == preflight_rng_before.seed
		and preflight_rng_after.state == preflight_rng_before.state,
		"Failed weighted preflight restores the resolution RNG stream"
	)
	_assert(EventManager.active_event != null and EventManager.active_event.event_id == preflight_failure.event_id, "Failed weighted preflight leaves the active Event available for retry")
	EventManager.cancel_active_event()

	_setup()
	var graduate: Dictionary = CharacterManager.characters[0]
	graduate.merge({"birth_date":"1960-01-01","life_stage":"adult","health":100,"happiness":100,"logic":100,"attractiveness":100,"social":100,"confidence":100,"discipline":100,"creativity":100,"school_id":4001,"major_id":5014,"education_status":"graduated","graduation_date":"1982-01-01","unemployment_start_date":"1982-01-01","job_offer_cooldown_until":null,"is_retired":false}, true)
	var offer_pool := CareerManager.get_unemployed_offer_pool(graduate)
	var offer: Dictionary = offer_pool[0] if not offer_pool.is_empty() else {}
	CareerManager.request_job_offer(graduate, offer)

	var transaction_event := _event("weighted_apply_failure", [])
	transaction_event.cost = {"currency":"money","amount":100}
	transaction_event.choices[0].resolution = {"mode":"weighted","outcomes":[{"outcome_id":"attempt","weight":1.0,"effects":[{"type":"money_change","amount":50},{"type":"accept_job_offer","target":"primary"}]}]}
	_configure([transaction_event])
	GameManager.family_money = 1000
	EventManager.activate_chain(transaction_event.event_id, {"primary":1})
	var source_instance_id := EventManager.active_event.instance_id
	var rng_before := EventManager.resolution_resolver.export_state()
	var offer_before := CareerManager.get_active_job_offer(1).duplicate(true)
	var invalidate_offer_on_money := func(new_amount: int) -> void:
		if new_amount == 950:
			CareerManager.active_job_offers.erase(1)
	GameManager.family_money_changed.connect(invalidate_offer_on_money)
	var result := EventManager.resolve_active_event("continue")
	GameManager.family_money_changed.disconnect(invalidate_offer_on_money)
	var rng_after := EventManager.resolution_resolver.export_state()

	_assert(not result.resolved and result.effect_results.size() == 2 and result.effect_results[0].success and not result.effect_results[1].success, "Apply-time failure is reported after an earlier effect actually ran")
	_assert(GameManager.family_money == 1000 and CareerManager.get_active_job_offer(1) == offer_before, "Apply-time rollback restores Event cost, economy mutation, and Career state")
	_assert(EventManager.active_event != null and EventManager.active_event.instance_id == source_instance_id and EventManager.story_history.records.is_empty() and EventManager.state_provider.completed_repeat_records.is_empty(), "Apply-time rollback restores the original active Event with no completion state")
	_assert(rng_after.seed == rng_before.seed and rng_after.state == rng_before.state, "Apply-time rollback restores the weighted resolution RNG stream")
	EventManager.cancel_active_event()


func _test_weighted_score_and_random_state() -> void:
	_setup()
	var provider := EventRuntimeQueryProvider.new()
	var weighted := {"mode":"weighted","outcomes":[
		{"outcome_id":"low","weight":1.0,"effects":[]},
		{"outcome_id":"boosted","weight":1.0,"weight_modifiers":[{"requirements":{"all":[{"type":"stat","target":"primary","stat":"logic","operator":">=","value":80}]},"add_weight":100.0}],"effects":[]},
	]}
	var first := EventResolutionResolver.new(provider, 42)
	var first_result := first.resolve(weighted, {"primary":1}, {})
	var saved_random := first.export_state()
	var next_result := first.resolve(weighted, {"primary":1}, {})
	var restored := EventResolutionResolver.new(provider, 99)
	restored.import_state(saved_random)
	_assert(first_result.valid and first_result.outcome_id == "boosted", "Weighted outcome applies requirement-based weight modifiers")
	_assert(restored.resolve(weighted, {"primary":1}, {}).outcome_id == next_result.outcome_id, "Weighted RNG state exports and imports deterministically")
	var score := {"mode":"score_check","sources":[{"source":"stat","target":"primary","stat":"logic","weight":1.0},{"source":"money","target":"primary","weight":0.01}],"threshold":90.0,"success":{"outcome_id":"success","effects":[]},"failure":{"outcome_id":"failure","effects":[]}}
	GameManager.family_money = 1000
	_assert(first.resolve(score, {"primary":1}, {}).outcome_id == "success", "Score check combines authoritative numeric sources deterministically")
	CharacterManager.characters[0].logic = 10; GameManager.family_money = 0
	_assert(first.resolve(score, {"primary":1}, {}).outcome_id == "failure", "Score check selects authored failure below threshold")


func _test_item_determinism_and_ownership_guards() -> void:
	_setup()
	var later := ItemManager.create_item_instance(ITEM_ID)
	var nearest := ItemManager.create_item_instance(ITEM_ID)
	var other_owned := ItemManager.create_item_instance(ITEM_ID)
	_set_item_dates(later.instance_id, "2000-01-01", "2002-01-01")
	_set_item_dates(nearest.instance_id, "2000-02-01", "2001-01-01")
	_set_item_dates(other_owned.instance_id, "1999-01-01", "2000-06-01")
	ItemManager.equip_item(2, other_owned.instance_id, "accessory")
	var remove_event := _event("remove_item_event", [{"type":"remove_item","target":"primary","item_id":ITEM_ID}])
	_configure([remove_event])
	EventManager.activate_chain(remove_event.event_id, {"primary":1})
	var removed := EventManager.resolve_active_event("continue")
	_assert(removed.resolved and ItemManager.get_inventory_item_instance(nearest.instance_id).is_empty(), "remove_item selects nearest expiration deterministically")
	_assert(not ItemManager.get_inventory_item_instance(other_owned.instance_id).is_empty() and ItemManager.get_item_equipped_owner(other_owned.instance_id) == 2, "Item effect never takes an instance equipped by another Character")

	var equip_event := _event("equip_item_event", [{"type":"equip_item","target":"primary","item_id":ITEM_ID}])
	_configure([equip_event])
	EventManager.activate_chain(equip_event.event_id, {"primary":1})
	var equipped := EventManager.resolve_active_event("continue")
	_assert(equipped.resolved and String(ItemManager.get_equipped_item(1, "accessory").get("instance_id", "")) == later.instance_id, "equip_item chooses an eligible family-owned matching instance")
	var unequip_event := _event("unequip_item_event", [{"type":"unequip_item","target":"primary","item_id":ITEM_ID}])
	_configure([unequip_event]); EventManager.activate_chain(unequip_event.event_id, {"primary":1})
	_assert(EventManager.resolve_active_event("continue").resolved and ItemManager.get_equipped_item(1, "accessory").is_empty(), "unequip_item affects only the target Character's matching Item")
	var add_event := _event("add_item_event", [{"type":"add_item","target":"primary","item_id":ITEM_ID}])
	_configure([add_event]); var count_before := ItemManager.family_inventory.size(); EventManager.activate_chain(add_event.event_id, {"primary":1})
	var add_result := EventManager.resolve_active_event("continue")
	_assert(add_result.resolved and ItemManager.family_inventory.size() == count_before + 1, "add_item creates a canonical ItemManager instance", JSON.stringify(add_result))


func _test_event_flow_effects() -> void:
	_setup()
	var follow := _event("flow_follow", [])
	var scheduled := _event("flow_scheduled", []); scheduled.trigger = {"type":"scheduled"}
	var source := _event("flow_source", [
		{"type":"queue_event","event_id":"flow_follow"},
		{"type":"schedule_event","event_id":"flow_scheduled","delay":{"unit":"day","value":2},"inherit_context":true},
	])
	_configure([source, follow, scheduled])
	EventManager.activate_chain(source.event_id, {"primary":1}, {"token":"kept"})
	var flow := EventManager.resolve_active_event("continue")
	_assert(flow.resolved and EventManager.active_event != null and EventManager.active_event.event_id == "flow_follow", "queue_event creates a bound follow-up behind the active Event")
	_assert(EventManager.scheduled_events.size() == 1 and EventManager.scheduled_events[0].context.token == "kept" and EventManager.scheduled_events[0].source_instance_id == flow.instance.instance_id, "schedule_event preserves inherited bindings and chain source")
	EventManager.cancel_active_event()
	var cancel := _event("flow_cancel", [{"type":"cancel_scheduled_event","event_id":"flow_scheduled"}])
	_configure([cancel, scheduled])
	EventManager.schedule_event("flow_scheduled", GameCalendar.add_days(TimeManager.get_iso_date_string(), 5))
	EventManager.activate_chain(cancel.event_id, {"primary":1})
	_assert(EventManager.resolve_active_event("continue").resolved and EventManager.scheduled_events[0].status == "cancelled", "cancel_scheduled_event cancels an exact pending target")


func _test_domain_manager_delegation() -> void:
	_setup()
	var graduate: Dictionary = CharacterManager.characters[0]
	graduate.merge({"birth_date":"1960-01-01","health":100,"happiness":100,"logic":100,"attractiveness":100,"social":100,"confidence":100,"discipline":100,"creativity":100,"school_id":4001,"major_id":5014,"education_status":"graduated","graduation_date":"1982-01-01","unemployment_start_date":"1982-01-01","job_offer_cooldown_until":null,"is_retired":false}, true)
	var offer_pool := CareerManager.get_unemployed_offer_pool(graduate)
	var offer: Dictionary = offer_pool[0] if not offer_pool.is_empty() else {}
	CareerManager.request_job_offer(graduate, offer)
	var accept := _event("career_accept", [{"type":"accept_job_offer","target":"primary"}])
	_configure([accept]); EventManager.activate_chain(accept.event_id, {"primary":1})
	var accepted := EventManager.resolve_active_event("continue")
	_assert(accepted.resolved and graduate.get("job_id", null) != null and CareerManager.get_active_job_offer(1).is_empty() and accepted.effect_results[0].job_name == CareerManager.get_job_by_id(int(graduate.job_id)).job_name and accepted.effect_results[0].company_name == CareerManager.get_company_by_id(String(graduate.company_id)).company_name, "accept_job_offer delegates to CareerManager and reports canonical Job/Company data")
	var salary_before := int(graduate.get("salary", 0))
	var salary := _event("career_salary", [{"type":"salary_increase","target":"primary","amount":400}])
	_configure([salary]); EventManager.activate_chain(salary.event_id, {"primary":1})
	var salary_result := EventManager.resolve_active_event("continue")
	_assert(salary_result.resolved and int(graduate.salary) == salary_before + 400 and salary_result.effect_results[0].before == salary_before and salary_result.effect_results[0].after == salary_before + 400 and not String(salary_result.effect_results[0].company_name).is_empty(), "salary_increase changes only authoritative external salary and reports the actual delta")
	var remove_job := _event("career_remove", [{"type":"job_remove","target":"primary"}])
	_configure([remove_job]); EventManager.activate_chain(remove_job.event_id, {"primary":1})
	var removed_job := EventManager.resolve_active_event("continue")
	_assert(removed_job.resolved and graduate.get("job_id", 1) == null and int(graduate.salary) == 0 and removed_job.effect_results[0].previous_salary == salary_before + 400 and not String(removed_job.effect_results[0].job_name).is_empty(), "job_remove delegates external-employment cleanup and reports prior career state")
	var reject_offer: Dictionary = CareerManager.get_unemployed_offer_pool(graduate)[0]
	CareerManager.request_job_offer(graduate, reject_offer)
	var reject := _event("career_reject", [{"type":"reject_job_offer","target":"primary"}])
	_configure([reject]); EventManager.activate_chain(reject.event_id, {"primary":1})
	var rejected := EventManager.resolve_active_event("continue")
	_assert(rejected.resolved and CareerManager.get_active_job_offer(1).is_empty() and graduate.get("job_id", null) == null and not String(rejected.effect_results[0].job_name).is_empty() and not String(rejected.effect_results[0].company_name).is_empty(), "reject_job_offer clears only CareerManager's active offer and reports canonical offer data")

	_setup()
	CharacterManager.characters[0].birth_date = "1994-01-01"
	EducationManager.is_education_event_active = true
	EducationManager.current_education_event = {"character_id":1,"event_type":"school_enrollment","education_stage":"primary_school"}
	var enroll := _event("education_enroll_event", [{"type":"education_enroll","target":"primary","school_id":1001}])
	_configure([enroll]); EventManager.activate_chain(enroll.event_id, {"primary":1})
	_assert(EventManager.resolve_active_event("continue").resolved and int(CharacterManager.characters[0].school_id) == 1001 and CharacterManager.characters[0].education_status == "studying", "education_enroll delegates the active EducationManager enrollment flow")

	_setup()
	HouseManager.restore_save_state({"houses":[{"house_instance_id":"house_0001","house_definition_id":"family_house","property_id":"house_01","level":1,"role_assignments":{"head_of_household":1,"cook":null,"housekeeper":null,"caregiver":null},"resident_character_ids":[2]}],"next_house_instance_number":2})
	var house_remove := _event("house_remove_event", [{"type":"remove_from_house","target":"primary"}])
	_configure([house_remove]); EventManager.activate_chain(house_remove.event_id, {"primary":1})
	_assert(EventManager.resolve_active_event("continue").resolved and HouseManager.get_character_assignment(1).is_empty() and HouseManager.get_character_assignment(2).house_instance_id == "house_0001", "remove_from_house delegates exact Character cleanup and preserves unrelated residents")

	_setup()
	BusinessManager.businesses = [{"business_instance_id":"business_0001","business_type_id":"hospital","level":1,"plot_id":"test_plot","slots":[{"slot_id":"doctor_01","assigned_character_id":null},{"slot_id":"nurse_01","assigned_character_id":null}]}]
	GameManager.family_money = 500000
	var upgrade_cost := BusinessManager.get_business_upgrade_cost("business_0001")
	var upgrade := _event("business_upgrade_event", [{"type":"business_upgrade","business":"business"}])
	upgrade.participants.business = {"type":"business","source":"trigger"}
	_configure([upgrade]); EventManager.activate_chain(upgrade.event_id, {"primary":1,"business":"business_0001"})
	_assert(EventManager.resolve_active_event("continue").resolved and int(BusinessManager.businesses[0].level) == 2 and GameManager.family_money == 500000 - upgrade_cost, "business_upgrade delegates canonical cost, slots, and level mutation")

	_setup()
	CharacterManager.characters[0].gender = "female"
	CharacterManager.characters[2].gender = "male"
	CharacterManager.characters[2].linked_character_id = 1
	CharacterManager.characters[2].relationship_status = "candidate"
	RelationshipNpcManager.relationship_candidate_ids = [3]
	var status_set := _event(
		"relationship_status_event",
		[{"type":"relationship_status_set","target":"target","value":"dating"}]
	)
	status_set.participants.target = {"type":"relationship_npc","source":"trigger"}
	_configure([status_set]); EventManager.activate_chain(status_set.event_id, {"primary":1,"target":3})
	var status_result := EventManager.resolve_active_event("continue")
	_assert(
		status_result.resolved
		and CharacterManager.characters[2].relationship_status == "dating"
		and status_result.effect_results[0].before == "candidate"
		and status_result.effect_results[0].after == "dating",
		"relationship_status_set delegates narrow external Relationship status mutation"
	)
	HouseManager.restore_save_state({
		"houses": [{
			"house_instance_id":"relationship_event_house",
			"house_definition_id":"family_house",
			"property_id":"relationship_event_house_plot",
			"level":1,
			"role_assignments":{"head_of_household":1,"cook":null,"housekeeper":null,"caregiver":null},
			"resident_character_ids":[]
		}],
		"next_house_instance_number":2
	})
	var marry := _event("relationship_marry_event", [{"type":"relationship_marry","primary":"primary","target":"target"}])
	marry.participants.target = {"type":"relationship_npc","source":"trigger"}
	_configure([marry]); EventManager.activate_chain(marry.event_id, {"primary":1,"target":3})
	_assert(
		EventManager.resolve_active_event("continue").resolved
		and CharacterManager.characters[0].partner_id == 3
		and CharacterManager.characters[2].is_player_family
		and String(HouseManager.get_character_assignment(3).get("assignment_type", "")) == "resident",
		"relationship_marry delegates RelationshipNpcManager family entry and canonical spouse House placement"
	)
	var divorce := _event("relationship_divorce_event", [{"type":"relationship_divorce","primary":"primary","target":"target"}])
	divorce.participants.target = {"type":"character","source":"trigger"}
	_configure([divorce]); EventManager.activate_chain(divorce.event_id, {"primary":1,"target":3})
	_assert(
		EventManager.resolve_active_event("continue").resolved
		and CharacterManager.characters[0].partner_id == null
		and not CharacterManager.characters[2].is_player_family
		and HouseManager.get_character_assignment(3).is_empty(),
		"relationship_divorce delegates partner, House, and external-spouse cleanup"
	)

	_setup()
	CharacterManager.characters[0].gender = "female"
	CharacterManager.characters[0].birth_date = "1945-01-01"
	CharacterManager.characters[2].gender = "male"
	CharacterManager.characters[2].linked_character_id = 1
	CharacterManager.characters[2].relationship_status = "candidate"
	RelationshipNpcManager.relationship_candidate_ids = [3]
	var stale_marry := _event("relationship_stale_marry_event", [{"type":"relationship_marry","primary":"primary","target":"target"}])
	stale_marry.participants.target = {"type":"relationship_npc","source":"trigger"}
	_configure([stale_marry]); EventManager.activate_chain(stale_marry.event_id, {"primary":1,"target":3})
	var stale_result := EventManager.resolve_active_event("continue")
	_assert(
		not stale_result.resolved
		and CharacterManager.characters[0].partner_id == null
		and not CharacterManager.characters[2].is_player_family
		and stale_result.effect_results.size() == 1
		and String(stale_result.effect_results[0].get("code", "")) == "marriage_unavailable",
		"relationship_marry revalidates the age boundary at final Event resolution"
	)
	EventManager.cancel_active_event()


func _test_runtime_export_import_and_reset() -> void:
	_setup()
	var completed := _event("export_completed", []); completed.repeat = {"mode":"once"}
	var active := _event("export_active", [{"type":"money_change","amount":77}])
	var registry := _registry([completed, active])
	EventManager.configure_runtime(registry, null, 123)
	EventManager.activate_chain(completed.event_id, {"primary":1}); EventManager.resolve_active_event("continue")
	EventManager.activate_chain(active.event_id, {"primary":1})
	var money_before := GameManager.family_money
	var state := EventManager.export_runtime_state()
	var json_text := JSON.stringify(state)
	EventManager.configure_runtime(registry, null, 999)
	_assert(EventManager.import_runtime_state(JSON.parse_string(json_text)), "Runtime state imports from its JSON-safe export")
	_assert(EventManager.active_event != null and EventManager.active_event.event_id == active.event_id and EventManager.story_history.has_completed(completed.event_id, {"primary":1}, {}), "Import restores active queue state and story history")
	_assert(GameManager.family_money == money_before, "Import does not replay already-applied or pending effects")
	var resolved := EventManager.resolve_active_event("continue")
	_assert(resolved.resolved and GameManager.family_money == money_before + 77, "Imported active Event resolves exactly once")
	EventManager.reset_runtime_state()
	_assert(EventManager.active_event == null and EventManager.queued_events.is_empty() and EventManager.story_history.records.is_empty() and EventManager.state_provider.cooldown_records.is_empty(), "Runtime reset clears every Phase 4A Event state surface")


func _event(event_id: String, effects: Array) -> Dictionary:
	return {"event_id":event_id,"category":"general","domain":"general","subtype":"phase4a_fixture","enabled":true,"rarity":"common","weight":1.0,"priority":0,"exclusive_group":null,"trigger":{"type":"chain"},"participants":{"primary":{"type":"character","source":"trigger"}},"requirements":{"all":[]},"repeat":{"mode":"repeatable"},"cooldown":null,"behavior":{"blocking":true,"pause_game":true},"content":{"title":event_id,"description":"Phase 4A fixture"},"presentation":{"template":"standard_event"},"choices":[{"choice_id":"continue","title":"Continue","requirements":{"all":[]},"resolution":{"mode":"deterministic","effects":effects}}]}


func _registry(events: Array) -> EventDataRegistry:
	var registry := EventDataRegistry.new()
	var document := {"schema_version":1,"category":"general","pools":[],"events":events}
	var loaded := registry.load_from_json_sources({"general.json":JSON.stringify(document)})
	_assert(loaded, "Phase 4A fixture registry validates", registry.get_diagnostic_text())
	return registry


func _configure(events: Array) -> void:
	EventManager.configure_runtime(_registry(events), null, 17)


func _setup() -> void:
	CharacterManager.characters = [_character(1, true), _character(2, true), _character(3, false)]
	GameManager.family_money = 10000; GameManager.diamonds = 100
	TimeManager.current_year = 2000; TimeManager.current_month = 1; TimeManager.current_day = 1
	ItemManager.reset_runtime_state()
	HouseManager.houses = []
	BusinessManager.businesses = []
	CareerManager.active_job_offers = {}
	EducationManager.current_education_event = {}; EducationManager.is_education_event_active = false
	RelationshipNpcManager.relationship_candidate_ids = []


func _character(id: int, family: bool) -> Dictionary:
	return {"character_id":id,"character_type":"family" if family else "relationship_npc","linked_character_id":null,"first_name":"Character %d" % id,"gender":"female","birth_date":"1980-01-01","life_stage":"young_adult","is_alive":true,"is_player_family":family,"parent_ids":[],"children_ids":[],"partner_id":null,"relationship_cooldown_until":null,"flag_ids":[],"health":80,"happiness":80,"logic":80,"attractiveness":80,"social":80,"confidence":80,"discipline":80,"creativity":80,"job_id":null,"company_id":null,"salary":0,"school_id":null,"major_id":null,"event_log":[]}


func _set_item_dates(instance_id: String, purchase_date: String, expiration_date: String) -> void:
	for instance in ItemManager.family_inventory:
		if typeof(instance) == TYPE_DICTIONARY and String(instance.get("instance_id", "")) == instance_id:
			instance["purchase_date"] = purchase_date; instance["expiration_date"] = expiration_date


func _store_state() -> void:
	original = {"characters":CharacterManager.characters.duplicate(true),"money":GameManager.family_money,"diamonds":GameManager.diamonds,"items":ItemManager.create_save_state(),"houses":HouseManager.houses.duplicate(true),"businesses":BusinessManager.businesses.duplicate(true),"offers":CareerManager.active_job_offers.duplicate(true),"year":TimeManager.current_year,"month":TimeManager.current_month,"day":TimeManager.current_day,"paused":TimeManager.is_paused,"speed":TimeManager.speed_multiplier}


func _restore_state() -> void:
	EventManager.configure_runtime(_registry([]))
	CharacterManager.characters = original.characters; GameManager.family_money = original.money; GameManager.diamonds = original.diamonds
	ItemManager.restore_save_state(original.items); HouseManager.houses = original.houses; BusinessManager.businesses = original.businesses; CareerManager.active_job_offers = original.offers
	TimeManager.current_year = original.year; TimeManager.current_month = original.month; TimeManager.current_day = original.day; TimeManager.is_paused = original.paused; TimeManager.speed_multiplier = original.speed


func _assert(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		passed += 1; print("[PASS] ", name)
	else:
		failed += 1; push_error("[FAIL] " + name)
		if not detail.is_empty(): print(detail)
