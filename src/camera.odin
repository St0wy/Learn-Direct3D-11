package main

import "core:math"
import "core:math/linalg"

CameraMovement :: enum {
	Forward,
	Backward,
	Left,
	Right,
	Up,
	Down,
}

CameraMovementSet :: bit_set[CameraMovement]

Camera :: struct {
	view_matrix: linalg.Matrix4f32,
	projection_matrix: linalg.Matrix4f32,
	position: linalg.Vector3f32,
	front: linalg.Vector3f32,
	up: linalg.Vector3f32,
	right: linalg.Vector3f32,
	world_up: linalg.Vector3f32,
	// TODO: Maybe replace the rotation / position stuff with a proper transform with quaternions and stuff
	yaw: f32,
	pitch: f32,
	movement_speed: f32,
	view_sensitivity: f32,
	fov_y: f32,
	aspect_ratio: f32,
}

make_camera :: proc(position: linalg.Vector3f32 = {0, 0, 0}, aspect_ratio: f32 = 16.0 / 9.0) -> Camera {
	camera := Camera {
		position = position,
		front = {0, 0, -1}, // TODO: Check the coordinate system
		up = {0, 1, 0},
		right = {1, 0, 0},
		world_up = {0, 1, 0},
		movement_speed = 2.5,
		view_sensitivity = 0.1,
		fov_y = 45,
		aspect_ratio = aspect_ratio,
	}

	update_camera_vectors(&camera)
	update_camera_view_matrix(&camera)
	update_camera_projection_matrix(&camera)

	return camera
}

camera_process_movement :: proc(camera: ^Camera, movement_state: CameraMovementSet, delta_time: f32) {
	velocity := camera.movement_speed * delta_time

	flat_front := linalg.Vector3f32{camera.front.x, 0, camera.front.z}
	flat_front = linalg.normalize(flat_front)

	flat_right := linalg.Vector3f32{camera.right.x, 0, camera.right.z}
	flat_right = linalg.normalize(flat_right)

	if (.Forward in movement_state) {
		camera.position += flat_front * velocity
	}
	if (.Backward in movement_state) {
		camera.position -= flat_front * velocity
	}
	if (.Left in movement_state) {
		camera.position -= flat_right * velocity
	}
	if (.Right in movement_state) {
		camera.position += flat_right * velocity
	}
	if (.Up in movement_state) {
		camera.position += camera.world_up * velocity
	}
	if (.Down in movement_state) {
		camera.position -= camera.world_up * velocity
	}

	update_camera_view_matrix(camera)
}

camera_process_view :: proc(camera: ^Camera, offset: linalg.Vector2f32, constrain_pitch: bool = true) {
	offset := offset
	offset *= camera.view_sensitivity

	camera.yaw *= offset.x
	camera.pitch *= offset.y

	if constrain_pitch {
		camera.pitch = math.clamp(camera.pitch, -89, 89)
	}

	update_camera_vectors(camera)
	update_camera_view_matrix(camera)
}

camera_process_fov_change :: proc(camera: ^Camera, offset: f32) {
	camera.fov_y -= offset
	camera.fov_y = math.clamp(camera.fov_y, 1, 120)
	update_camera_projection_matrix(camera)
}

update_camera_vectors :: proc(camera: ^Camera) {
	front: linalg.Vector3f32
	front.x = math.cos(linalg.to_radians(camera.yaw)) * math.cos(linalg.to_radians(camera.pitch))
	front.y = math.sin_f32(linalg.to_radians(camera.pitch))
	front.z = math.sin_f32(linalg.to_radians(camera.yaw)) * math.cos(linalg.to_radians(camera.pitch))

	camera.front = linalg.normalize(front)
	camera.right = linalg.normalize(linalg.cross(camera.front, camera.world_up))
	camera.up = linalg.normalize(linalg.cross(camera.right, camera.front))
}

update_camera_view_matrix :: proc(camera: ^Camera) {
	camera.view_matrix = linalg.matrix4_look_at_f32(camera.position, camera.position + camera.front, camera.up, false)
}

update_camera_projection_matrix :: proc(camera: ^Camera) {
	camera.projection_matrix = linalg.matrix4_perspective(linalg.to_radians(camera.fov_y), camera.aspect_ratio, 0.3, 1000, false)
}