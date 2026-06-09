class_name Quadtree
extends RefCounted

var theta := 0.6 # Balance parameter between performance and precision
var epsilon := 25.0 # Softening factor to eliminate infinite-force snapping stutters

var boundary: Rect2
var capacity: int = 1

var body_rid = null
var body_pos: Vector2 = Vector2.ZERO
var children: Array = []
var is_divided: bool = false

var total_mass: float = 0.0
var center_of_mass: Vector2 = Vector2.ZERO

func _init(_boundary: Rect2, _capacity: int = 1):
	boundary = _boundary
	capacity = _capacity

func insert(node: RID, pos: Vector2) -> bool:
	if not boundary.has_point(pos):
		return false
	
	if body_rid == null and not is_divided:
		body_rid = node
		body_pos = pos
		return true
	
	if not is_divided:
		subdivide()
		var old_body = body_rid
		var old_pos = body_pos
		body_rid = null
		_insert_into_children(old_body, old_pos)

	return _insert_into_children(node, pos)

func _insert_into_children(b, pos) -> bool:
	for child in children:
		if child.insert(b, pos):
			return true
	return false

func subdivide():
	var h_w = boundary.size.x / 2.0
	var h_h = boundary.size.y / 2.0
	var pos = boundary.position

	children.append(Quadtree.new(Rect2(pos.x + h_w, pos.y, h_w, h_h), capacity))       # Top Right
	children.append(Quadtree.new(Rect2(pos.x, pos.y, h_w, h_h), capacity))             # Top Left
	children.append(Quadtree.new(Rect2(pos.x, pos.y + h_h, h_w, h_h), capacity))       # Bottom Left
	children.append(Quadtree.new(Rect2(pos.x + h_w, pos.y + h_h, h_w, h_h), capacity)) # Bottom Right

	is_divided = true

func update_mass_distribution(mass: float) -> void:
	if body_rid != null and not is_divided:
		total_mass = mass
		center_of_mass = body_pos
	else:
		total_mass = 0.0
		center_of_mass = Vector2.ZERO
		for child in children:
			child.update_mass_distribution(mass)
			total_mass += child.total_mass
			center_of_mass += child.center_of_mass * child.total_mass
		
		if total_mass > 0:
			center_of_mass /= total_mass

func calculate_force(target_body: RID, target_mass: float, target_pos: Vector2, g : float) -> Vector2:
	if body_rid == target_body:
		return Vector2.ZERO
	
	var diff = center_of_mass - target_pos
	var distance_sq = diff.length_squared()

	if distance_sq < epsilon * epsilon:
		return Vector2.ZERO
	
	var s_sq = (boundary.size.x) * (boundary.size.x)

	if not is_divided or (s_sq / distance_sq) < theta * theta:
		var force_mag = (g * target_mass * total_mass) / (distance_sq + epsilon)
		return diff * (force_mag / sqrt(distance_sq))
	else:
		var total_force = Vector2.ZERO
		for child in children:
			total_force += child.calculate_force(target_body, target_mass, target_pos, g)
		return total_force