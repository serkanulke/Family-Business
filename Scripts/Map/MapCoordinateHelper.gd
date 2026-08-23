extends RefCounted
class_name MapCoordinateHelper

const MAIN_TILE_SIZE := Vector2(200.0, 100.0)
const DETAIL_TILE_SIZE := Vector2(50.0, 25.0)
const DETAIL_SUBDIVISION := 4


static func grid_to_world(cell: Vector2i, tile_size: Vector2 = MAIN_TILE_SIZE) -> Vector2:
	return Vector2(
		float(cell.x - cell.y) * tile_size.x * 0.5,
		float(cell.x + cell.y) * tile_size.y * 0.5
	)


static func main_grid_to_world(cell: Vector2i) -> Vector2:
	return grid_to_world(cell, MAIN_TILE_SIZE)


static func detail_grid_to_world(cell: Vector2i) -> Vector2:
	return grid_to_world(cell, DETAIL_TILE_SIZE)


static func main_to_detail(cell: Vector2i) -> Vector2i:
	return cell * DETAIL_SUBDIVISION


static func detail_to_main(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(cell.x) / float(DETAIL_SUBDIVISION)),
		floori(float(cell.y) / float(DETAIL_SUBDIVISION))
	)


static func get_south_anchor(grid_origin: Vector2i, footprint: Vector2i) -> Vector2:
	return main_grid_to_world(grid_origin + footprint)


static func get_footprint_polygon(footprint: Vector2i) -> PackedVector2Array:
	var origin := Vector2i.ZERO
	var south_anchor := get_south_anchor(origin, footprint)
	return PackedVector2Array([
		main_grid_to_world(origin) - south_anchor,
		main_grid_to_world(Vector2i(footprint.x, 0)) - south_anchor,
		Vector2.ZERO,
		main_grid_to_world(Vector2i(0, footprint.y)) - south_anchor
	])


static func arrays_align_exactly(main_cell: Vector2i) -> bool:
	var main_position := main_grid_to_world(main_cell)
	var subdivided_position := detail_grid_to_world(main_to_detail(main_cell))
	return (
		main_position.is_equal_approx(subdivided_position)
		and DETAIL_TILE_SIZE * DETAIL_SUBDIVISION == MAIN_TILE_SIZE
	)
