package main

import "base:intrinsics"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:mem"
import win32 "core:sys/windows"
import "core:time"
import "vendor:directx/d3d11"

import "rendering"
import "windowing"

Constants :: struct #align (16) {
	transform:    glm.mat4,
	projection:   glm.mat4,
	light_vector: glm.vec3,
}

main :: proc() {
	when ODIN_DEBUG {
		track_alloc: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track_alloc, context.allocator)
		context.allocator = mem.tracking_allocator(&track_alloc)
		defer {
			for _, entry in track_alloc.allocation_map {
				fmt.eprintf(
					"\n- %v leaked %v bytes",
					entry.location,
					entry.size,
				)
			}

			for entry in track_alloc.bad_free_array {
				fmt.eprintf("\n- %v bad free\n", entry.location)
			}
			mem.tracking_allocator_destroy(&track_alloc)
		}
	}

	stopwatch: time.Stopwatch
	time.stopwatch_start(&stopwatch)
	window, window_succes := windowing.create_window(
		"Hello",
		{win32.CW_USEDEFAULT, win32.CW_USEDEFAULT},
	)
	if (!window_succes) {fmt.printfln("Could not create window.");return}
	defer windowing.destroy_window(window)
	window_creation_time := time.stopwatch_duration(stopwatch)
	fmt.printfln(
		"Created window in %f ms.",
		time.duration_milliseconds(window_creation_time),
	)

	time.stopwatch_reset(&stopwatch)
	time.stopwatch_start(&stopwatch)
	renderer, renderer_success := rendering.create_renderer(window.hwnd)
	assert(renderer_success)
	defer rendering.destroy_renderer(&renderer)
	renderer_creation_time := time.stopwatch_duration(stopwatch)
	fmt.printfln(
		"Created renderer in %f ms.",
		time.duration_milliseconds(renderer_creation_time),
	)

	shader_source := #load("shaders/shaders.hlsl")

	input_element_desc := [?]d3d11.INPUT_ELEMENT_DESC {
		{"POS", 0, .R32G32B32_FLOAT, 0, 0, .VERTEX_DATA, 0},
		{
			"NOR",
			0,
			.R32G32B32_FLOAT,
			0,
			d3d11.APPEND_ALIGNED_ELEMENT,
			.VERTEX_DATA,
			0,
		},
		{
			"TEX",
			0,
			.R32G32_FLOAT,
			0,
			d3d11.APPEND_ALIGNED_ELEMENT,
			.VERTEX_DATA,
			0,
		},
		{
			"COL",
			0,
			.R32G32B32_FLOAT,
			0,
			d3d11.APPEND_ALIGNED_ELEMENT,
			.VERTEX_DATA,
			0,
		},
	}

	// I don't know yet if pipelines should be handled here or inside the renderer
	could_create_pipeline := rendering.init_main_pipeline(
		&renderer,
		{
			vertex_shader_source = shader_source,
			vertex_shader_filename = "shaders.hlsl",
			vertex_shader_entry = "vs_main",
			input_element_description = input_element_desc[:],
			pixel_shader_source = shader_source,
			pixel_shader_filename = "shaders.hlsl",
			pixel_shader_entry = "ps_main",
		},
	)
	assert(could_create_pipeline)
	defer rendering.destroy_pipeline(&renderer.main_pipeline)

	could_init_const_buffer := rendering.init_constant_buffer(
		&renderer,
		Constants,
	)
	assert(could_init_const_buffer)
	defer rendering.destroy_constant_buffer(&renderer)

	mesh := rendering.get_nice_mesh_data()
	texture := rendering.get_nice_texture_data()

	gpu_mesh_id, could_upload_mesh := rendering.upload_mesh_to_gpu(
		&renderer,
		mesh,
	)
	assert(could_upload_mesh)

	gpu_texture_id, could_upload_texture := rendering.upload_texture_to_gpu(
		&renderer,
		texture,
	)
	assert(could_upload_texture)

	demo_material_id := rendering.create_demo_material(
		&renderer.materials_manager,
		gpu_texture_id,
	)

	windowing.show_window(&window)

	model_rotation := glm.vec3{0.0, 0.0, 0.0}
	model_translation := glm.vec3{0.0, 0.0, 4.0}

	should_quit := false
	for (!should_quit) {
		for (windowing.check_window_event(&window) != nil) {
			pressed_quit_key := windowing.is_key_pressed(
				&window,
				win32.VK_ESCAPE,
			)
			if (window.event.type == .WindowClosed || pressed_quit_key) {
				should_quit = true
				break
			}

			if (window.event.type == .WindowResized) {
				could_resize := rendering.resize_renderer(
					&renderer,
					window.size,
				)
				assert(could_resize)
			}
		}

		w := f32(renderer.viewport.Width) / f32(renderer.viewport.Height)
		h := f32(1)
		n := f32(1)
		f := f32(9)

		rotate_x := glm.mat4Rotate({1, 0, 0}, model_rotation.x)
		rotate_y := glm.mat4Rotate({0, 1, 0}, model_rotation.y)
		rotate_z := glm.mat4Rotate({0, 0, 1}, model_rotation.z)
		translate := glm.mat4Translate(model_translation)

		model_rotation.x += 0.005
		model_rotation.y += 0.009
		model_rotation.z += 0.001

		constants: Constants
		constants.transform = translate * rotate_z * rotate_y * rotate_x
		constants.light_vector = {+1, -1, +1}

		constants.projection = {
			2 * n / w,
			0,
			0,
			0,
			0,
			2 * n / h,
			0,
			0,
			0,
			0,
			f / (f - n),
			n * f / (n - f),
			0,
			0,
			1,
			0,
		}

		could_upload_const_buff := rendering.upload_constant_buffer(
			&renderer,
			constants,
		)
		assert(could_upload_const_buff)

		clear_color := rendering.linear_to_srgb(
			glm.vec3({0.025, 0.025, 0.025}),
		)
		rendering.clear(
			&renderer,
			{clear_color.r, clear_color.g, clear_color.b, 1.0},
		)

		rendering.setup_renderer_state(&renderer)
		rendering.setup_main_pipeline(&renderer)

		if (windowing.is_window_minimized(&window)) {
			time.sleep(time.Millisecond * 200)
		} else {
			rendering.draw_mesh(&renderer, gpu_mesh_id, demo_material_id)
		}

		rendering.present(&renderer)

		free_all(context.temp_allocator)
	}
}
