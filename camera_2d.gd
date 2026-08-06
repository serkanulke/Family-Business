extends Camera2D


@export var drag_speed := 1.1

# Mouse tekerleği için zoom miktarı.
@export var zoom_step := 0.1

# İki parmak hareketinin zoom hassasiyeti.
@export var pinch_zoom_sensitivity := 0.005

@export var min_zoom := 0.4
@export var max_zoom := 1.5


# Bilgisayarda test için kullanılır.
var mouse_dragging := false

# Ekrana basılı parmakların konumlarını tutar.
var touch_points: Dictionary = {}

# İki parmak arasındaki önceki mesafe.
var previous_pinch_distance := 0.0


func _unhandled_input(event: InputEvent) -> void:

	# -------------------------------------------------
	# MOBİL DOKUNMATİK KONTROLLER
	# -------------------------------------------------

	if event is InputEventScreenTouch:
		handle_screen_touch(event)
		return

	if event is InputEventScreenDrag:
		handle_screen_drag(event)
		return


	# -------------------------------------------------
	# MOUSE KONTROLLERİ
	# Yalnızca bilgisayarda test amacıyla kullanılacak.
	# -------------------------------------------------

	if event is InputEventMouseButton:

		# Sağ mouse tuşuyla sürükleme.
		if event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_dragging = event.pressed

		# Mouse tekerleği yukarı: yakınlaştır.
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_camera(zoom_step)

		# Mouse tekerleği aşağı: uzaklaştır.
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_camera(-zoom_step)


	if event is InputEventMouseMotion and mouse_dragging:
		position -= event.relative * zoom.x * drag_speed


func handle_screen_touch(event: InputEventScreenTouch) -> void:

	if event.pressed:
		# Parmağın ekrana bastığı konumu kaydet.
		touch_points[event.index] = event.position
	else:
		# Parmak ekrandan kaldırıldığında kaydı sil.
		touch_points.erase(event.index)

	# İki parmak ekrandaysa ilk pinch mesafesini kaydet.
	if touch_points.size() == 2:
		previous_pinch_distance = get_pinch_distance()
	else:
		previous_pinch_distance = 0.0


func handle_screen_drag(event: InputEventScreenDrag) -> void:

	# Hareket eden parmağın yeni konumunu kaydet.
	touch_points[event.index] = event.position

	# Tek parmakla kamera sürükleme.
	if touch_points.size() == 1:
		position -= event.relative * zoom.x * drag_speed
		return

	# İki parmakla zoom.
	if touch_points.size() == 2:
		var current_pinch_distance := get_pinch_distance()

		if previous_pinch_distance > 0.0:
			var distance_difference := (
				current_pinch_distance - previous_pinch_distance
			)

			var zoom_amount := (
				distance_difference * pinch_zoom_sensitivity
			)

			zoom_camera(zoom_amount)

		previous_pinch_distance = current_pinch_distance


func get_pinch_distance() -> float:

	var touch_ids := touch_points.keys()

	if touch_ids.size() < 2:
		return 0.0

	var first_touch: Vector2 = touch_points[touch_ids[0]]
	var second_touch: Vector2 = touch_points[touch_ids[1]]

	return first_touch.distance_to(second_touch)


func zoom_camera(amount: float) -> void:

	var new_zoom := zoom + Vector2(amount, amount)

	new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
	new_zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)

	zoom = new_zoom
