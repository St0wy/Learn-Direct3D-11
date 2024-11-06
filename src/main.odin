package main

import "base:intrinsics"
import "core:fmt"
import glm "core:math/linalg/glsl"
import win32 "core:sys/windows"
import "vendor:directx/d3d11"

main :: proc() {
	window, window_succes := create_window(
		"Hello",
		win32.CW_USEDEFAULT,
		win32.CW_USEDEFAULT,
	)
	if (!window_succes) {fmt.printfln("Could not create window.");return}
	defer destroy_window(window)

	renderer, renderer_success := create_renderer(window.hwnd)
	assert(renderer_success)
	defer destroy_renderer(&renderer)

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
	could_create_pipeline := init_main_pipeline(
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
	defer destroy_pipeline(&renderer.main_pipeline)

	Constants :: struct #align (16) {
		transform:    glm.mat4,
		projection:   glm.mat4,
		light_vector: glm.vec3,
	}

	could_init_const_buffer := init_constant_buffer(&renderer, Constants)
	assert(could_init_const_buffer)
	defer destroy_constant_buffer(&renderer)

	model := get_nice_model()

	gpu_mesh, could_upload_mesh := upload_mesh_to_gpu(&renderer, model.mesh)
	assert(could_upload_mesh)
	defer destroy_gpu_mesh(&gpu_mesh)

	gpu_texture, could_upload_texture := upload_texture_to_gpu(
		&renderer,
		model.material.base_color_texture,
	)
	assert(could_upload_texture)

	model_rotation := glm.vec3{0.0, 0.0, 0.0}
	model_translation := glm.vec3{0.0, 0.0, 4.0}

	msg: win32.MSG
	for (msg.message != win32.WM_QUIT) {
		if (win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_REMOVE)) {
			win32.TranslateMessage(&msg)
			win32.DispatchMessageW(&msg)
			continue
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

		could_upload_const_buff := upload_constant_buffer(&renderer, constants)
		assert(could_upload_const_buff)

		clear(&renderer, {0.025, 0.025, 0.025, 1.0})

		setup_renderer_state(&renderer)
		setup_main_pipeline(&renderer, gpu_texture)

		draw_mesh(&renderer, gpu_mesh)

		present(&renderer)

		free_all(context.temp_allocator)
	}
}
