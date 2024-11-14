package rendering

import glm "core:math/linalg/glsl"

Vertex :: struct {
	position:            glm.vec3,
	normal:              glm.vec3,
	texture_coordinates: glm.vec2,
	color:               glm.vec3,
}

// TODO : Create mesh manager + mesh id
Mesh :: struct {
	vertices: []Vertex,
	indices:  []u32,
}

Model :: struct {
	mesh:        Mesh,
	material_id: MaterialId,
}

load_model_from_obj_path :: proc(obj_path: string) -> (Model, bool) {
	mesh: Model
	return mesh, false
}
