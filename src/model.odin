package main

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

// For now there is just one material type, but in the future there will be multiple
Material :: struct {
	base_color_texture: Texture,
}

Model :: struct {
	mesh:     Mesh,
	material: Material,
}

load_model_from_obj_path :: proc(obj_path: string) -> (Model, bool) {
	mesh: Model
	return mesh, false
}
