extends MultiMeshInstance2D

@export var manager: Node2D

func _ready() -> void:
	# Auto-find manager if not set
	if manager == null:
		manager = get_parent().get_node("Physics Bodies")
		if manager == null:
			push_error("MultiMeshInstance2D: Cannot find Physics Bodies node!")
			return
	
	setup_multimesh()

func setup_multimesh():
	if manager == null:
		push_warning("Manager property not initialized in MultiMeshInstance2D!")
		return
	
	# Create a simple 2D quad mesh for canvas rendering
	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array([
		Vector3(-0.5, -0.5, 0.0),
		Vector3(0.5, -0.5, 0.0),
		Vector3(0.5, 0.5, 0.0),
		Vector3(-0.5, 0.5, 0.0)
	])
	var uvs = PackedVector2Array([
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0)
	])
	var indices = PackedInt32Array([0, 1, 2, 0, 2, 3])
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Create multimesh
	var mmi = MultiMesh.new()
	mmi.transform_format = MultiMesh.TRANSFORM_2D
	mmi.use_colors = false
	mmi.use_custom_data = true
	mmi.instance_count = manager.N
	mmi.mesh = mesh
	
	self.multimesh = mmi
	
	# Create and apply shader material to the MultiMeshInstance2D node
	var shader = load("res://object.gdshader")
	if shader == null:
		push_error("Failed to load shader: res://object.gdshader")
		return
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	set_material(shader_mat)

func _physics_process(_delta: float) -> void:
	if manager:
		var pos_array = manager.pos
		var vel_array = manager.vel
		var radius = manager.radius
		var count = pos_array.size()
		
		if multimesh.instance_count != count:
			multimesh.instance_count = count
			
		for i in range(count):
			var t = Transform2D()
			t = t.scaled(Vector2(radius * 2.0, radius * 2.0))
			t.origin = pos_array[i]
			multimesh.set_instance_transform_2d(i, t)
			
			# Vector speed translation package passed to GPU via Custom Data channels
			var speed = vel_array[i].length()
			multimesh.set_instance_custom_data(i, Color(vel_array[i].x, vel_array[i].y, speed, 0.0))