extends Node2D

@export var N := 1000
@export var pos := PackedVector2Array()
@export var vel := PackedVector2Array()
@export var radius := 4.0
@export var g := 500.0
@export var mass := 5.0
@export var bounce := 0.1
@export var friction := 0.2
@export var mouse_strength := 50000.0

var objects := []
var root: Quadtree
var calculate_task_id := -1

func _ready() -> void:
	pos.resize(N)
	vel.resize(N)
	
	# Assuming a starting max boundary distribution area
	var max_spawn_dist := 800.0

	for i in range(N):
		var body_rid = PhysicsServer2D.body_create()
		objects.append(body_rid)
		
		PhysicsServer2D.body_set_param(body_rid, PhysicsServer2D.BODY_PARAM_GRAVITY_SCALE, 0.0)
		PhysicsServer2D.body_set_mode(body_rid, PhysicsServer2D.BODY_MODE_RIGID)
		PhysicsServer2D.body_set_param(body_rid, PhysicsServer2D.BODY_PARAM_BOUNCE, bounce)
		PhysicsServer2D.body_set_param(body_rid, PhysicsServer2D.BODY_PARAM_FRICTION, friction)

		var shape_rid = PhysicsServer2D.circle_shape_create()
		PhysicsServer2D.shape_set_data(shape_rid, radius)
		PhysicsServer2D.body_add_shape(body_rid, shape_rid)

		var world_rid = get_world_2d().space
		PhysicsServer2D.body_set_space(body_rid, world_rid)

		# 1. Determine orbital starting position distributed around the center
		var spawn_pos = Vector2(randf_range(-max_spawn_dist, max_spawn_dist), randf_range(-max_spawn_dist, max_spawn_dist))
		if spawn_pos.length() < 10.0: 
			spawn_pos = Vector2(10.0, 10.0)
		
		# 2. Perpendicular tangent vector (Rotates counter-clockwise around center)
		var orbit_dir = Vector2(-spawn_pos.y, spawn_pos.x).normalized()
		
		# 3. Calculate stable Keplerian orbit velocity using estimated Enclosed Mass approximation
		var dist = spawn_pos.length()
		var enclosed_ratio = clamp(dist / max_spawn_dist, 0.0, 1.0)
		var m_enclosed = N * mass * (enclosed_ratio * enclosed_ratio)
		var speed = sqrt((g * m_enclosed) / dist)
		
		var initial_velocity = orbit_dir * speed

		# 4. Push initial state values to PhysicsServer
		var body_transform = Transform2D(0, spawn_pos)
		PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, body_transform)
		PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, initial_velocity)
		PhysicsServer2D.body_set_param(body_rid, PhysicsServer2D.BODY_PARAM_MASS, mass)

func _physics_process(_delta: float) -> void:
	# Pull true real-time states into arrays from the server loop
	for i in range(N):
		pos[i] = PhysicsServer2D.body_get_state(objects[i], PhysicsServer2D.BODY_STATE_TRANSFORM).origin
		vel[i] = PhysicsServer2D.body_get_state(objects[i], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)

	# Capture dynamic input safely on the main thread
	var mouse_pos = get_global_mouse_position()
	var mouse_down = 0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		mouse_down = 1      # Attract
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		mouse_down = -1     # Repel

	# Offload next simulation math step if previous one completed
	if calculate_task_id == -1 or WorkerThreadPool.is_task_completed(calculate_task_id):
		var snapshot = pos.duplicate()
		calculate_task_id = WorkerThreadPool.add_task(_run_simulation.bind(snapshot, mouse_pos, mouse_down))

func _run_simulation(snapshot: PackedVector2Array, mouse_pos: Vector2, mouse_down: int) -> void:
	var forces := PackedVector2Array()
	forces.resize(N)
	forces.fill(Vector2.ZERO)
	
	# Centered boundary mapping to handle full area limits flawlessly
	var sim_area = Rect2(Vector2(-10000, -10000), Vector2(20000, 20000))
	root = Quadtree.new(sim_area, 1)

	for i in range(N):
		root.insert(objects[i], snapshot[i])
	
	root.update_mass_distribution(mass)

	for i in range(N):
		# Barnes-Hut calculation
		forces[i] = root.calculate_force(objects[i], mass, snapshot[i], g)
		
		# Gentle center pulling stabilizer force
		var center_pull = (Vector2.ZERO - snapshot[i]).normalized() * 10.0
		forces[i] += center_pull
		
		# Interactive mouse implementation
		if mouse_down != 0:
			var dir_to_mouse = mouse_pos - snapshot[i]
			var distance_squared = max(dir_to_mouse.length_squared(), 900.0) # Softening cap
			forces[i] += mouse_down * dir_to_mouse.normalized() * (mouse_strength / distance_squared)
			
		PhysicsServer2D.body_set_constant_force(objects[i], forces[i])

func _exit_tree() -> void:
	if calculate_task_id != -1:
		WorkerThreadPool.wait_for_task_completion(calculate_task_id)
	for rid in objects:
		PhysicsServer2D.free_rid(rid)
