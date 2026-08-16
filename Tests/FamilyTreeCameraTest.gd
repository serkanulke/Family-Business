extends Node

const FAMILY_TREE_CAMERA_SCRIPT := preload(
	"res://Scripts/FamilyTree/FamilyTreeCamera.gd"
)

var passed: int = 0
var failed: int = 0
var camera: Camera2D


func _ready() -> void:
	camera = FAMILY_TREE_CAMERA_SCRIPT.new()
	add_child(
		camera
	)

	print("")
	print("========================================")
	print("Family Tree camera tests starting")
	print("========================================")

	_test_default_zoom()
	_test_minimum_zoom_clamp()
	_test_maximum_zoom_clamp()
	_test_reset_view()
	_test_editable_zoom_limits()

	print("")
	print("========================================")
	print(
		"Family Tree camera tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print(
			"ALL FAMILY TREE CAMERA TESTS PASSED."
		)
	else:
		push_error(
			"Family Tree camera has %d failing test(s)."
			% failed
		)


func _assert_true(
	condition: bool,
	test_name: String
) -> void:
	if condition:
		passed += 1
		print(
			"[PASS] ",
			test_name
		)
	else:
		failed += 1
		push_error(
			"[FAIL] "
			+ test_name
		)


func _test_default_zoom() -> void:
	camera.min_zoom = 0.9
	camera.max_zoom = 1.2
	camera.default_zoom = 1.0
	camera.reset_view()

	var valid: bool = is_equal_approx(
		camera.get_zoom_level(),
		1.0
	)

	_assert_true(
		valid,
		"Default Family Tree zoom is 1.0"
	)


func _test_minimum_zoom_clamp() -> void:
	camera.min_zoom = 0.9
	camera.max_zoom = 1.2
	camera.set_zoom_level(
		0.2
	)

	var valid: bool = is_equal_approx(
		camera.get_zoom_level(),
		0.9
	)

	_assert_true(
		valid,
		"Family Tree cannot zoom farther out than 0.9"
	)


func _test_maximum_zoom_clamp() -> void:
	camera.min_zoom = 0.9
	camera.max_zoom = 1.2
	camera.set_zoom_level(
		4.0
	)

	var valid: bool = is_equal_approx(
		camera.get_zoom_level(),
		1.2
	)

	_assert_true(
		valid,
		"Family Tree cannot zoom closer than 1.2"
	)


func _test_reset_view() -> void:
	camera.default_position = Vector2(
		540.0,
		960.0
	)

	camera.position = Vector2(
		100.0,
		200.0
	)

	camera.set_zoom_level(
		1.2
	)

	camera.reset_view()

	var valid: bool = (
		camera.position == Vector2(
			540.0,
			960.0
		)
		and is_equal_approx(
			camera.get_zoom_level(),
			camera.default_zoom
		)
	)

	_assert_true(
		valid,
		"Reset restores default position and zoom"
	)


func _test_editable_zoom_limits() -> void:
	camera.min_zoom = 0.8
	camera.max_zoom = 1.3
	camera.default_zoom = 1.0

	camera.set_zoom_level(
		0.1
	)

	var lower_valid: bool = is_equal_approx(
		camera.get_zoom_level(),
		0.8
	)

	camera.set_zoom_level(
		2.0
	)

	var upper_valid: bool = is_equal_approx(
		camera.get_zoom_level(),
		1.3
	)

	var valid: bool = (
		lower_valid
		and upper_valid
	)

	_assert_true(
		valid,
		"Zoom limits remain editable for later balancing"
	)
