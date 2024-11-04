package main

import glm "core:math/linalg/glsl"

Vertex :: struct {
	position:            glm.vec3,
	normal:              glm.vec3,
	texture_coordinates: glm.vec2,
}

Mesh :: struct {
	vertices: []Vertex,
	indices:  []int,
}

Material :: struct {
	base_color_texture: []
}

load_model_from_obj_path :: proc(obj_path: string) -> (Mesh, bool) {
	mesh: Mesh
	return mesh, false
}
