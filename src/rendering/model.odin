package rendering

import glm "core:math/linalg/glsl"

Vertex :: struct {
	position:            glm.vec3,
	normal:              glm.vec3,
	texture_coordinates: glm.vec2,
	color:               glm.vec3,
}

Mesh :: struct {
	vertices: []Vertex,
	indices:  []u32,
}

MeshManager :: struct {
	meshes: [dynamic]Mesh,
}

MeshId :: distinct u32

// TODO : Check if model is a good idea
Model :: struct {
	mesh_id:     MeshId,
	material_id: MaterialId,
}

load_model_from_obj_path :: proc(obj_path: string) -> (Model, bool) {
	model: Model
	return model, false
}
