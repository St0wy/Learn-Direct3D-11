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

	vs_blob: ^d3d11.IBlob
	result := d3d.Compile(
		raw_data(shader_source),
		len(shader_source),
		"shaders.hlsl",
		nil,
		nil,
		"vs_main",
		"vs_5_0",
		0,
		0,
		&vs_blob,
		nil,
	)
	assert(vs_blob != nil)
	check_error("Could not compiler vertex shader", result)

	vertex_shader: ^d3d11.IVertexShader
	result =
	renderer.device->CreateVertexShader(
		vs_blob->GetBufferPointer(),
		vs_blob->GetBufferSize(),
		nil,
		&vertex_shader,
	)
	check_error("Could not create vertex shader", result)


	input_layout: ^d3d11.IInputLayout
	result =
	renderer.device->CreateInputLayout(
		&input_element_desc[0],
		len(input_element_desc),
		vs_blob->GetBufferPointer(),
		vs_blob->GetBufferSize(),
		&input_layout,
	)
	check_error("Could not create input layout", result)

	ps_blob: ^d3d11.IBlob
	result = d3d.Compile(
		raw_data(shader_source),
		len(shader_source),
		"shaders.hlsl",
		nil,
		nil,
		"ps_main",
		"ps_5_0",
		0,
		0,
		&ps_blob,
		nil,
	)
	check_error("Could not compile pixel shader", result)

	pixel_shader: ^d3d11.IPixelShader
	result =
	renderer.device->CreatePixelShader(
		ps_blob->GetBufferPointer(),
		ps_blob->GetBufferSize(),
		nil,
		&pixel_shader,
	)
	check_error("Could not create pixel shader", result)

	rasterizer_description := d3d11.RASTERIZER_DESC {
		FillMode = .SOLID,
		CullMode = .BACK,
	}
	rasterizer_state: ^d3d11.IRasterizerState
	result =
	renderer.device->CreateRasterizerState(
		&rasterizer_description,
		&rasterizer_state,
	)
	check_error("Could not create rasterizer state", result)

	sampler_description := d3d11.SAMPLER_DESC {
		Filter         = .MIN_MAG_MIP_POINT,
		AddressU       = .WRAP,
		AddressV       = .WRAP,
		AddressW       = .WRAP,
		ComparisonFunc = .NEVER,
	}
	sampler_state: ^d3d11.ISamplerState
	result =
	renderer.device->CreateSamplerState(&sampler_description, &sampler_state)
	check_error("Could not create sampler state", result)

	depth_stencil_description := d3d11.DEPTH_STENCIL_DESC {
		DepthEnable    = true,
		DepthWriteMask = .ALL,
		DepthFunc      = .LESS,
	}
	depth_stencil_state: ^d3d11.IDepthStencilState
	result =
	renderer.device->CreateDepthStencilState(
		&depth_stencil_description,
		&depth_stencil_state,
	)
	check_error("Could not create depth stencil state", result)

	Constants :: struct #align (16) {
		transform:    glm.mat4,
		projection:   glm.mat4,
		light_vector: glm.vec3,
	}

	constant_buffer_description := d3d11.BUFFER_DESC {
		ByteWidth      = size_of(Constants),
		Usage          = .DYNAMIC,
		BindFlags      = {.CONSTANT_BUFFER},
		CPUAccessFlags = {.WRITE},
	}
	constant_buffer: ^d3d11.IBuffer
	result =
	renderer.device->CreateBuffer(
		&constant_buffer_description,
		nil,
		&constant_buffer,
	)
	check_error("Could not create constant buffer", result)

	vertex_buffer_description := d3d11.BUFFER_DESC {
		ByteWidth = size_of(vertex_data),
		Usage     = .IMMUTABLE,
		BindFlags = {.VERTEX_BUFFER},
	}
	vertex_buffer: ^d3d11.IBuffer
	result =
	renderer.device->CreateBuffer(
		&vertex_buffer_description,
		&d3d11.SUBRESOURCE_DATA {
			pSysMem = &vertex_data[0],
			SysMemPitch = size_of(vertex_data),
		},
		&vertex_buffer,
	)
	check_error("Could not create vertex buffer", result)

	index_buffer_description := d3d11.BUFFER_DESC {
		ByteWidth = size_of(index_data),
		Usage     = .IMMUTABLE,
		BindFlags = {.INDEX_BUFFER},
	}
	index_buffer: ^d3d11.IBuffer
	result =
	renderer.device->CreateBuffer(
		&index_buffer_description,
		&d3d11.SUBRESOURCE_DATA {
			pSysMem = &index_data[0],
			SysMemPitch = size_of(index_data),
		},
		&index_buffer,
	)
	check_error("Could not create index buffer", result)

	texture_description := d3d11.TEXTURE2D_DESC {
		Width = TEXTURE_WIDTH,
		Height = TEXTURE_HEIGHT,
		MipLevels = 1,
		ArraySize = 1,
		Format = .R8G8B8A8_UNORM_SRGB,
		SampleDesc = {Count = 1},
		Usage = .IMMUTABLE,
		BindFlags = {.SHADER_RESOURCE},
	}

	texture_data := d3d11.SUBRESOURCE_DATA {
		pSysMem     = &texture_data[0],
		SysMemPitch = TEXTURE_WIDTH * 4,
	}

	texture: ^d3d11.ITexture2D
	result =
	renderer.device->CreateTexture2D(
		&texture_description,
		&texture_data,
		&texture,
	)
	check_error("Could not create model texture", result)

	texture_view: ^d3d11.IShaderResourceView
	result =
	renderer.device->CreateShaderResourceView(texture, nil, &texture_view)
	check_error("Could not create shader resource view", result)

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
			constant_buffer,
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
		renderer.device_context->Unmap(constant_buffer, 0)

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
		renderer.device_context->IASetInputLayout(input_layout)
		renderer.device_context->IASetVertexBuffers(
			0,
			1,
			&vertex_buffer,
			&vertex_buffer_stride,
			&vertex_buffer_offset,
		)
		renderer.device_context->IASetIndexBuffer(index_buffer, .R32_UINT, 0)

		renderer.device_context->VSSetShader(vertex_shader, nil, 0)
		renderer.device_context->VSSetConstantBuffers(0, 1, &constant_buffer)

		renderer.device_context->RSSetViewports(1, &viewport)
		renderer.device_context->RSSetState(rasterizer_state)

		renderer.device_context->PSSetShader(pixel_shader, nil, 0)
		renderer.device_context->PSSetShaderResources(0, 1, &texture_view)
		renderer.device_context->PSSetSamplers(0, 1, &sampler_state)

		renderer.device_context->OMSetRenderTargets(
			1,
			&renderer.framebuffer_view,
			renderer.depth_buffer_view,
		)
		renderer.device_context->OMSetDepthStencilState(depth_stencil_state, 0)
		renderer.device_context->OMSetBlendState(nil, nil, ~u32(0))

		renderer.device_context->DrawIndexed(len(index_data), 0, 0)

		result = renderer.swapchain->Present(1, {})
		check_error("Could not present swapchain", result)

		free_all(context.temp_allocator)
	}
}
