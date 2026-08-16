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

	camera.min_zoom = 0.9
	camera.max_zoom = 1.2
	camera.default_zoom = 1.0
	camera.bounds_padding = Vector2.ZERO

	print("")
	print("========================================")
	print("Family Tree pan-bound tests starting")
	print("========================================")

	_test_content_bounds_are_stored()
	_test_small_tree_centers_camera()
	_test_horizontal_pan_is_clamped()
	_test_vertical_pan_is_clamped()
	_test_zoom_reclamps_position()

	print("")
	print("========================================")
	print(
		"Family Tree pan-bound tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print(
			"ALL FAMILY TREE PAN-BOUND TESTS PASSED."
		)
	else:
		push_error(
			"Family Tree pan bounds have %d failing test(s)."
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


func _test_content_bounds_are_stored() -> void:
	var bounds := Rect2(
		Vector2(
			0.0,
			0.0
		),
		Vector2(
			2000.0,
			2500.0
		)
	)

	camera.set_content_bounds(
		bounds
	)

	var valid: bool = (
		camera.has_content_bounds
		and camera.content_bounds == bounds
	)

	_assert_true(
		valid,
		"Camera stores dynamic Family Tree content bounds"
	)


func _test_small_tree_centers_camera() -> void:
	camera.set_zoom_level(
		1.0
	)

	var viewport_size: Vector2 = (
		camera.get_viewport_rect().size
	)

	var small_bounds := Rect2(
		Vector2(
			100.0,
			100.0
		),
		Vector2(
			maxf(
				100.0,
				viewport_size.x * 0.25
			),
			maxf(
				100.0,
				viewport_size.y * 0.25
			)
		)
	)

	camera.set_content_bounds(
		small_bounds
	)

	var expected_center: Vector2 = small_bounds.get_center()

	var valid: bool = camera.position.is_equal_approx(
		expected_center
	)

	_assert_true(
		valid,
		"Small Family Tree stays centered instead of drifting off-screen"
	)


func _test_horizontal_pan_is_clamped() -> void:
	var viewport_size: Vector2 = (
		camera.get_viewport_rect().size
	)

	var bounds := Rect2(
		Vector2.ZERO,
		Vector2(
			viewport_size.x * 3.0,
			viewport_size.y * 2.0
		)
	)

	camera.set_zoom_level(
		1.0
	)

	camera.set_content_bounds(
		bounds
	)

	camera.position.x = -100000.0
	camera.call(
		"_clamp_position_to_content"
	)

	var half_width: float = (
		viewport_size.x
		* 0.5
	)

	var valid: bool = is_equal_approx(
		camera.position.x,
		half_width
	)

	_assert_true(
		valid,
		"Horizontal pan cannot move Family Tree completely off-screen"
	)


func _test_vertical_pan_is_clamped() -> void:
	var viewport_size: Vector2 = (
		camera.get_viewport_rect().size
	)

	var bounds := Rect2(
		Vector2.ZERO,
		Vector2(
			viewport_size.x * 2.0,
			viewport_size.y * 3.0
		)
	)

	camera.set_zoom_level(
		1.0
	)

	camera.set_content_bounds(
		bounds
	)

	camera.position.y = 100000.0
	camera.call(
		"_clamp_position_to_content"
	)

	var expected_y: float = (
		bounds.end.y
		- viewport_size.y * 0.5
	)

	var valid: bool = is_equal_approx(
		camera.position.y,
		expected_y
	)

	_assert_true(
		valid,
		"Vertical pan cannot move Family Tree completely off-screen"
	)


func _test_zoom_reclamps_position() -> void:
	var viewport_size: Vector2 = (
		camera.get_viewport_rect().size
	)

	var bounds := Rect2(
		Vector2.ZERO,
		Vector2(
			viewport_size.x * 2.0,
			viewport_size.y * 2.0
		)
	)

	camera.set_content_bounds(
		bounds
	)

	camera.position = Vector2(
		-100000.0,
		-100000.0
	)

	camera.set_zoom_level(
		0.9
	)

	var half_visible: Vector2 = (
		viewport_size
		/ 0.9
		* 0.5
	)

	var valid: bool = (
		camera.position.x >= half_visible.x - 0.01
		and camera.position.y >= half_visible.y - 0.01
	)

	_assert_true(
		valid,
		"Changing zoom immediately reapplies pan bounds"
	)
