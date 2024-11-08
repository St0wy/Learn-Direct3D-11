package main

import "core:math"
import glm "core:math/linalg/glsl"

linear_to_srgb_float :: #force_inline proc(x: f32) -> f32 {
	if (x <= 0.0031308) {return x * 12.92}
	return 1.055 * math.pow(x, 1.0 / 2.4) - 0.055
}

linear_to_srgb_fast_float :: #force_inline proc(x: f32) -> f32 {
	s1 := math.sqrt(x)
	s2 := math.sqrt(s1)
	s3 := math.sqrt(s2)
	return 0.66200269 * s1 + 0.6841221 * s2 - 0.3235836 * s3 - 0.022541147 * x
}

linear_to_srgb_sqrt :: #force_inline proc(c: glm.vec3) -> glm.vec3 {
	return {math.sqrt(c.x), math.sqrt(c.y), math.sqrt(c.z)}
}

linear_to_srgb_fast :: #force_inline proc(c: glm.vec3) -> glm.vec3 {
	return {
		linear_to_srgb_fast_float(c.x),
		linear_to_srgb_fast_float(c.y),
		linear_to_srgb_fast_float(c.z),
	}
}

linear_to_srgb :: #force_inline proc(c: glm.vec3) -> glm.vec3 {
	return {
		linear_to_srgb_float(c.x),
		linear_to_srgb_float(c.y),
		linear_to_srgb_float(c.z),
	}
}
