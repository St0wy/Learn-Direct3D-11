package main

import "base:intrinsics"
import "core:fmt"
import glm "core:math/linalg/glsl"
import win32 "core:sys/windows"
import "vendor:directx/d3d11"
import d3d "vendor:directx/d3d_compiler"
import "vendor:directx/dxgi"

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

	Constants :: struct #align (16) {
		transform:    glm.mat4,
		projection:   glm.mat4,
		light_vector: glm.vec3,
	}

	could_init_const_buffer := init_constant_buffer(
		&renderer,
		size_of(Constants),
	)
	assert(could_init_const_buffer)

	model := get_nice_model()

	gpu_mesh, could_upload_mesh := upload_mesh_to_gpu(&renderer, model.mesh)
	assert(could_upload_mesh)

	gpu_texture, could_upload_texture := upload_texture_to_gpu(
		&renderer,
		model.material.base_color_texture,
	)
	assert(could_upload_texture)

	clear_color := [?]f32{0.025, 0.025, 0.025, 1.0}

	vertex_buffer_stride := u32(11 * 4)
	vertex_buffer_offset := u32(0)

	model_rotation := glm.vec3{0.0, 0.0, 0.0}
	model_translation := glm.vec3{0.0, 0.0, 4.0}

	msg: win32.MSG
	for (msg.message != win32.WM_QUIT) {
		if (win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_REMOVE)) {
			win32.TranslateMessage(&msg)
			// Handle message here maybe
			win32.DispatchMessageW(&msg)
			continue
		}

		viewport := d3d11.VIEWPORT {
			0,
			0,
			f32(renderer.render_zone_width),
			f32(renderer.render_zone_height),
			0,
			1,
		}

		w := viewport.Width / viewport.Height
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

		mapped_subresource: d3d11.MAPPED_SUBRESOURCE

		renderer.device_context->Map(
			renderer.constant_buffer,
			0,
			.WRITE_DISCARD,
			{},
			&mapped_subresource,
		)
		{
			constants := (^Constants)(mapped_subresource.pData)
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
		}
		renderer.device_context->Unmap(renderer.constant_buffer, 0)

		renderer.device_context->ClearRenderTargetView(
			renderer.framebuffer_view,
			&clear_color,
		)
		renderer.device_context->ClearDepthStencilView(
			renderer.depth_buffer_view,
			{.DEPTH},
			1,
			0,
		)

		renderer.device_context->IASetPrimitiveTopology(.TRIANGLELIST)
		renderer.device_context->IASetInputLayout(
			renderer.main_pipeline.input_layout,
		)
		renderer.device_context->IASetVertexBuffers(
			0,
			1,
			&gpu_mesh.vertex_buffer,
			&vertex_buffer_stride,
			&vertex_buffer_offset,
		)
		renderer.device_context->IASetIndexBuffer(
			gpu_mesh.index_buffer,
			.R32_UINT,
			0,
		)

		renderer.device_context->VSSetShader(
			renderer.main_pipeline.vertex_shader,
			nil,
			0,
		)
		renderer.device_context->VSSetConstantBuffers(
			0,
			1,
			&renderer.constant_buffer,
		)

		renderer.device_context->RSSetViewports(1, &viewport)
		renderer.device_context->RSSetState(renderer.rasterizer_state)

		renderer.device_context->PSSetShader(
			renderer.main_pipeline.pixel_shader,
			nil,
			0,
		)
		renderer.device_context->PSSetShaderResources(0, 1, &gpu_texture.view)
		renderer.device_context->PSSetSamplers(0, 1, &renderer.sampler_state)

		renderer.device_context->OMSetRenderTargets(
			1,
			&renderer.framebuffer_view,
			renderer.depth_buffer_view,
		)
		renderer.device_context->OMSetDepthStencilState(
			renderer.depth_stencil_state,
			0,
		)
		renderer.device_context->OMSetBlendState(nil, nil, ~u32(0))

		renderer.device_context->DrawIndexed(len(index_data), 0, 0)

		result := renderer.swapchain->Present(1, {})
		if (!win32.SUCCEEDED(result)) {
			panic(
				fmt.tprintfln("Could not present swapchain : %X", u32(result)),
			)
		}

		free_all(context.temp_allocator)
	}
}
