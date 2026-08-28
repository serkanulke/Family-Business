extends Node

var passed: int = 0
var failed: int = 0

var saved_characters: Array = []
var saved_next_character_id: int = 1
var saved_time: Dictionary = {}


func _ready() -> void:
	_save_state()
	seed(143)

	print("")
	print("========================================")
	print("Portrait and genetics migration tests")
	print("========================================")

	_run_tests()
	_restore_state()

	print("")
	print(
		"Portrait and genetics migration tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print(
			"ALL PORTRAIT AND GENETICS MIGRATION TESTS PASSED."
		)
	else:
		push_error(
			"Portrait/genetics migration has %d failing test(s)."
			% failed
		)


func _save_state() -> void:
	saved_characters = CharacterManager.characters.duplicate(
		true
	)
	saved_next_character_id = CharacterManager.next_character_id
	saved_time = {
		"day": TimeManager.current_day,
		"month": TimeManager.current_month,
		"year": TimeManager.current_year
	}


func _restore_state() -> void:
	CharacterManager.characters = saved_characters
	CharacterManager.next_character_id = saved_next_character_id
	TimeManager.current_day = int(saved_time["day"])
	TimeManager.current_month = int(saved_time["month"])
	TimeManager.current_year = int(saved_time["year"])


func _reset_world() -> void:
	CharacterManager.characters = []
	CharacterManager.next_character_id = 1
	TimeManager.current_day = 15
	TimeManager.current_month = 6
	TimeManager.current_year = 2000


func _run_tests() -> void:
	_test_canonical_folder_mapping()
	_test_skin_inheritance()
	_test_deferred_hair_and_eye_fields()
	_test_parent_portrait_exclusions()
	_test_life_stage_portrait_transition()
	_test_legacy_portrait_migration()
	_test_child_creation_paths()
	_test_missing_asset_safety()


func _assert_true(
	condition: bool,
	test_name: String
) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)


func _make_character(
	character_id: int,
	gender: String,
	skin_tone: String,
	variant_id: String = "",
	parent_ids: Array = []
) -> Dictionary:
	return {
		"character_id": character_id,
		"first_name": "Test",
		"gender": gender,
		"avatar_theme": "classic",
		"genetics": {
			"skin_tone": skin_tone
		},
		"portrait_variant_id": variant_id,
		"is_alive": true,
		"birth_date": CharacterManager.generate_birth_date_for_age(
			20
		),
		"death_date": null,
		"life_stage": "young_adult",
		"is_player_family": true,
		"parent_ids": parent_ids.duplicate(),
		"is_adopted": false,
		"partner_id": null,
		"children_ids": []
	}


func _test_canonical_folder_mapping() -> void:
	_assert_true(
		CharacterManager.get_gender_portrait_folder(
			"male"
		) == "Male"
		and CharacterManager.get_gender_portrait_folder(
			"female"
		) == "Female",
		"Stored male/female values map to canonical Male/Female folders"
	)

	_assert_true(
		CharacterManager.get_portrait_folder_path(
			"male",
			"mixed",
			"young_adult"
		) == "res://Resources/Characters/Male/Mixed/YoungAdult",
		"Portrait folder combines canonical gender, skin, and life-stage mappings"
	)

	_assert_true(
		CharacterManager.get_available_portrait_variants(
			"male",
			"mixed",
			"young_adult"
		).has(
			"character_001"
		),
		"Portrait variants are discovered from actual PNG filenames"
	)


func _test_skin_inheritance() -> void:
	var light := {"genetics": {"skin_tone": "light"}}
	var mixed := {"genetics": {"skin_tone": "mixed"}}
	var dark := {"genetics": {"skin_tone": "dark"}}

	_assert_true(
		CharacterManager.generate_inherited_skin_tone(
			light,
			light
		) == "light"
		and CharacterManager.generate_inherited_skin_tone(
			mixed,
			mixed
		) == "mixed"
		and CharacterManager.generate_inherited_skin_tone(
			dark,
			dark
		) == "dark",
		"Matching parental skin tones remain unchanged"
	)

	var observed: Dictionary = {}

	for _index in range(120):
		var inherited := (
			CharacterManager.generate_inherited_skin_tone(
				light,
				dark
			)
		)
		observed[inherited] = true

	_assert_true(
		observed.size() == 3
		and observed.has("light")
		and observed.has("mixed")
		and observed.has("dark"),
		"Different parental tones use the full equal-choice light/mixed/dark pool"
	)


func _test_deferred_hair_and_eye_fields() -> void:
	var random_genetics := CharacterManager.generate_random_genetics()
	var inherited := CharacterManager.generate_baby_genetics(
		{"genetics": {"skin_tone": "light"}},
		{"genetics": {"skin_tone": "dark"}}
	)
	var legacy_profile := {
		"skin_tone": "mixed",
		"hair_color": "brown",
		"eye_color": "blue"
	}

	_assert_true(
		random_genetics.has("skin_tone")
		and not random_genetics.has("hair_color")
		and not random_genetics.has("eye_color")
		and inherited.has("skin_tone")
		and not inherited.has("hair_color")
		and not inherited.has("eye_color"),
		"New random and inherited genetics contain only active skin_tone"
	)

	_assert_true(
		CharacterManager.is_valid_genetics_profile(
			{"skin_tone": "light"}
		)
		and CharacterManager.is_valid_genetics_profile(
			legacy_profile
		),
		"Hair and eye fields are optional and harmless in legacy genetics data"
	)

	var first := _make_character(
		1,
		"male",
		"mixed",
		"character_001"
	)
	var second := first.duplicate(true)
	first["genetics"]["hair_color"] = "black"
	first["genetics"]["eye_color"] = "green"
	second["genetics"]["hair_color"] = "blonde"
	second["genetics"]["eye_color"] = "blue"

	_assert_true(
		CharacterManager.get_avatar_path(first)
		== CharacterManager.get_avatar_path(second),
		"Portrait resolution ignores deferred hair and eye values"
	)


func _test_parent_portrait_exclusions() -> void:
	_reset_world()
	var father := _make_character(
		1,
		"male",
		"mixed",
		"character_001"
	)
	var mother := _make_character(
		2,
		"female",
		"light",
		"character_001"
	)
	var second_father := _make_character(
		3,
		"male",
		"mixed",
		"character_002"
	)
	CharacterManager.characters = [
		father,
		mother,
		second_father
	]

	var male_exclusions := (
		CharacterManager.get_parent_portrait_variant_exclusions(
			"male",
			[1, 2]
		)
	)
	var female_exclusions := (
		CharacterManager.get_parent_portrait_variant_exclusions(
			"female",
			[1, 2]
		)
	)
	var two_male_exclusions := (
		CharacterManager.get_parent_portrait_variant_exclusions(
			"male",
			[1, 3]
		)
	)

	_assert_true(
		male_exclusions == ["character_001"]
		and female_exclusions == ["character_001"],
		"A child excludes only persisted parent variants from its own gender set"
	)

	_assert_true(
		two_male_exclusions.has("character_001")
		and two_male_exclusions.has("character_002")
		and two_male_exclusions.size() == 2,
		"Two same-gender parents contribute both portrait exclusions"
	)

	_assert_true(
		CharacterManager.select_random_portrait_variant(
			"male",
			"mixed",
			"young_adult",
			male_exclusions
		).is_empty(),
		"A male child cannot select the father's only matching Male variant"
	)

	var opposite_gender_exclusions := (
		CharacterManager.get_parent_portrait_variant_exclusions(
			"male",
			[2]
		)
	)
	var first_sibling_variant := (
		CharacterManager.select_random_portrait_variant(
			"male",
			"mixed",
			"young_adult",
			opposite_gender_exclusions
		)
	)
	var second_sibling_variant := (
		CharacterManager.select_random_portrait_variant(
			"male",
			"mixed",
			"young_adult",
			opposite_gender_exclusions
		)
	)

	_assert_true(
		opposite_gender_exclusions.is_empty()
		and first_sibling_variant == "character_001"
		and second_sibling_variant == "character_001",
		"Opposite-gender parent filenames are not excluded and siblings may match"
	)


func _test_life_stage_portrait_transition() -> void:
	_reset_world()
	var matching := _make_character(
		1,
		"male",
		"mixed",
		"character_001"
	)
	matching["life_stage"] = "teen"
	CharacterManager.characters = [matching]

	CharacterManager.update_character_life_stage(
		matching
	)

	_assert_true(
		String(matching["life_stage"]) == "young_adult"
		and String(matching["portrait_variant_id"])
		== "character_001"
		and String(matching["portrait_path"]).contains(
			"/Male/Mixed/YoungAdult/character_001.png"
		),
		"Aging preserves the same variant when the destination-stage asset exists"
	)

	var missing := _make_character(
		2,
		"male",
		"mixed",
		"character_999"
	)
	missing["life_stage"] = "teen"
	CharacterManager.characters = [missing]
	CharacterManager.update_character_life_stage(
		missing
	)

	_assert_true(
		String(missing["portrait_variant_id"])
		== "character_001"
		and String(missing["portrait_path"]).contains(
			"/Male/Mixed/YoungAdult/character_001.png"
		),
		"Aging selects a new eligible variant only when the counterpart is missing"
	)

	var blocked := _make_character(
		2,
		"male",
		"mixed",
		"character_999",
		[1]
	)
	blocked["life_stage"] = "teen"
	CharacterManager.characters = [
		_make_character(
			1,
			"male",
			"mixed",
			"character_001"
		),
		blocked
	]
	CharacterManager.update_character_life_stage(
		blocked
	)

	_assert_true(
		String(blocked["portrait_variant_id"])
		== "character_999"
		and String(blocked["portrait_path"])
		== CharacterManager.DEFAULT_AVATAR_PATH,
		"Aging fallback keeps parent exclusion instead of selecting a parent's face"
	)


func _test_legacy_portrait_migration() -> void:
	_reset_world()
	var legacy := _make_character(
		1,
		"male",
		"mixed"
	)
	legacy["portrait_path"] = (
		"res://Resources/Characters/Man/Mixed/YoungAdult/character_001.png"
	)
	CharacterManager.characters = [legacy]
	CharacterManager.normalize_character_portraits()

	_assert_true(
		String(legacy["portrait_variant_id"])
		== "character_001"
		and String(legacy["portrait_path"])
		== "res://Resources/Characters/Male/Mixed/YoungAdult/character_001.png",
		"Legacy Man path becomes Male and recovers its filename variant"
	)

	var legacy_woman_path := (
		CharacterManager.normalize_legacy_portrait_path(
			"res://Resources/Characters/Woman/Light/YoungAdult/character_001.png"
		)
	)

	_assert_true(
		legacy_woman_path
		== "res://Resources/Characters/Female/Light/YoungAdult/character_001.png",
		"Legacy Woman path becomes Female"
	)

	_assert_true(
		CharacterManager.get_portrait_variant_id_from_path(
			"res://Resources/Characters/man/mixed/01.png"
		) == "character_001",
		"Legacy numeric portrait filenames normalize to the migrated variant ID"
	)


func _test_child_creation_paths() -> void:
	_reset_world()
	var mother := _make_character(
		1,
		"female",
		"light",
		"character_001"
	)
	var father := _make_character(
		2,
		"male",
		"dark",
		"character_001"
	)
	CharacterManager.characters = [mother, father]
	CharacterManager.next_character_id = 3

	var biological := CharacterManager.create_baby_character(
		"Biological",
		"male",
		1,
		2
	)
	var biological_genetics: Dictionary = biological.get(
		"genetics",
		{}
	)

	_assert_true(
		not biological.is_empty()
		and biological.has("portrait_variant_id")
		and biological_genetics.has("skin_tone")
		and not biological_genetics.has("hair_color")
		and not biological_genetics.has("eye_color"),
		"Biological newborn uses skin-only genetics and canonical portrait state"
	)

	var before_donor_count := CharacterManager.characters.size()
	var donor_child := (
		CharacterManager.create_donor_conceived_baby_character(
			"Donor",
			"female",
			1,
			2,
			{"skin_tone": "dark"}
		)
	)
	var donor_genetics: Dictionary = donor_child.get(
		"genetics",
		{}
	)

	_assert_true(
		not donor_child.is_empty()
		and CharacterManager.characters.size()
		== before_donor_count + 1
		and donor_child.get("parent_ids", []) == [1, 2]
		and donor_genetics.has("skin_tone")
		and not donor_genetics.has("hair_color")
		and not donor_genetics.has("eye_color"),
		"Donor child uses carrier plus temporary donor skin genetics without persisting the donor"
	)

	var adopted := CharacterManager.create_adopted_child_character(
		"Adopted",
		"female",
		1,
		2
	)
	var adopted_genetics: Dictionary = adopted.get(
		"genetics",
		{}
	)

	_assert_true(
		not adopted.is_empty()
		and bool(adopted.get("is_adopted", false))
		and adopted_genetics.has("skin_tone")
		and not adopted_genetics.has("hair_color")
		and not adopted_genetics.has("eye_color")
		and adopted.has("portrait_variant_id"),
		"Adopted child gets random skin-only genetics and canonical portrait state"
	)


func _test_missing_asset_safety() -> void:
	_assert_true(
		CharacterManager.get_available_portrait_variants(
			"female",
			"dark",
			"baby"
		).is_empty()
		and CharacterManager.get_random_portrait_path(
			"female",
			"dark",
			"baby"
		) == CharacterManager.DEFAULT_AVATAR_PATH
		and CharacterManager.get_portrait_variant_id_from_path(
			CharacterManager.DEFAULT_AVATAR_PATH
		).is_empty(),
		"Missing portrait folders return the approved default avatar without crashing"
	)
