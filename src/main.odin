package main

import "base:intrinsics"
import "core:fmt"
import glm "core:math/linalg/glsl"
import win32 "core:sys/windows"
import "vendor:directx/d3d11"
import d3d "vendor:directx/d3d_compiler"
import "vendor:directx/dxgi"

@(private = "file")
L :: intrinsics.constant_utf16_cstring

Direct3DRenderer :: struct {
	window:              Window,
	base_device:         ^d3d11.IDevice,
	base_device_context: ^d3d11.IDeviceContext,
	device:              ^d3d11.IDevice,
	device_context:      ^d3d11.IDeviceContext,
	dxgi_device:         ^dxgi.IDevice,
	dxgi_adapter:        ^dxgi.IAdapter,
	dxgi_factory:        ^dxgi.IFactory2,
	swapchain:           ^dxgi.ISwapChain1,
	framebuffer:         ^d3d11.ITexture2D,
	framebuffer_view:    ^d3d11.IRenderTargetView,
	depth_buffer:        ^d3d11.ITexture2D,
	depth_buffer_view:   ^d3d11.IDepthStencilView,
}

main :: proc() {
	renderer: Direct3DRenderer
	renderer.window = create_window(
		L("Hello"),
		win32.CW_USEDEFAULT,
		win32.CW_USEDEFAULT,
	)
	defer destroy_window(renderer.window)

	feature_levels := [1]d3d11.FEATURE_LEVEL{d3d11.FEATURE_LEVEL._11_0}

	result := d3d11.CreateDevice(
		nil,
		.HARDWARE,
		nil,
		{.BGRA_SUPPORT},
		&feature_levels[0],
		len(feature_levels),
		d3d11.SDK_VERSION,
		&renderer.base_device,
		nil,
		&renderer.base_device_context,
	)
	if (result != 0) {
		show_windows_error_and_panic(
			fmt.tprintf(
				"Could not create D3D11 device with error : %X",
				u32(result),
			),
		)
	}

	renderer.base_device->QueryInterface(
		d3d11.IDevice_UUID,
		(^rawptr)(&renderer.device),
	)

	renderer.base_device_context->QueryInterface(
		d3d11.IDeviceContext_UUID,
		(^rawptr)(&renderer.device_context),
	)

	renderer.device->QueryInterface(
		dxgi.IDevice_UUID,
		(^rawptr)(&renderer.dxgi_device),
	)

	renderer.dxgi_device->GetAdapter(&renderer.dxgi_adapter)

	renderer.dxgi_adapter->GetParent(
		dxgi.IFactory2_UUID,
		(^rawptr)(&renderer.dxgi_factory),
	)

	swapchain_description := dxgi.SWAP_CHAIN_DESC1 {
		Width = 0,
		Height = 0,
		Format = .B8G8R8A8_UNORM_SRGB,
		Stereo = false,
		SampleDesc = {Count = 1, Quality = 0},
		BufferUsage = {.RENDER_TARGET_OUTPUT},
		BufferCount = 2,
		Scaling = .STRETCH,
		SwapEffect = .DISCARD,
		AlphaMode = .UNSPECIFIED,
	}

	renderer.dxgi_factory->CreateSwapChainForHwnd(
		renderer.device,
		renderer.window.hwnd,
		&swapchain_description,
		nil,
		nil,
		&renderer.swapchain,
	)

	renderer.swapchain->GetBuffer(
		0,
		d3d11.ITexture2D_UUID,
		(^rawptr)(&renderer.framebuffer),
	)

	renderer.device->CreateRenderTargetView(
		renderer.framebuffer,
		nil,
		&renderer.framebuffer_view,
	)

	depth_buffer_description: d3d11.TEXTURE2D_DESC
	renderer.framebuffer->GetDesc(&depth_buffer_description)
	depth_buffer_description.Format = .D24_UNORM_S8_UINT
	depth_buffer_description.BindFlags = {.DEPTH_STENCIL}

	renderer.device->CreateTexture2D(
		&depth_buffer_description,
		nil,
		&renderer.depth_buffer,
	)

	renderer.device->CreateDepthStencilView(
		renderer.depth_buffer,
		nil,
		&renderer.depth_buffer_view,
	)

	shader_source := #load("shaders/shaders.hlsl")

	vs_blob: ^d3d11.IBlob
	d3d.Compile(
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

	vertex_shader: ^d3d11.IVertexShader
	renderer.device->CreateVertexShader(
		vs_blob->GetBufferPointer(),
		vs_blob->GetBufferSize(),
		nil,
		&vertex_shader,
	)

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

	input_layout: ^d3d11.IInputLayout
	renderer.device->CreateInputLayout(
		&input_element_desc[0],
		len(input_element_desc),
		vs_blob->GetBufferPointer(),
		vs_blob->GetBufferSize(),
		&input_layout,
	)

	ps_blob: ^d3d11.IBlob
	d3d.Compile(
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

	pixel_shader: ^d3d11.IPixelShader
	renderer.device->CreatePixelShader(
		ps_blob->GetBufferPointer(),
		ps_blob->GetBufferSize(),
		nil,
		&pixel_shader,
	)

	rasterizer_description := d3d11.RASTERIZER_DESC {
		FillMode = .SOLID,
		CullMode = .BACK,
	}
	rasterizer_state: ^d3d11.IRasterizerState
	renderer.device->CreateRasterizerState(
		&rasterizer_description,
		&rasterizer_state,
	)

	sampler_description := d3d11.SAMPLER_DESC {
		Filter         = .MIN_MAG_MIP_POINT,
		AddressU       = .WRAP,
		AddressV       = .WRAP,
		AddressW       = .WRAP,
		ComparisonFunc = .NEVER,
	}
	sampler_state: ^d3d11.ISamplerState
	renderer.device->CreateSamplerState(&sampler_description, &sampler_state)

	depth_stencil_description := d3d11.DEPTH_STENCIL_DESC {
		DepthEnable    = true,
		DepthWriteMask = .ALL,
		DepthFunc      = .LESS,
	}
	depth_stencil_state: ^d3d11.IDepthStencilState
	renderer.device->CreateDepthStencilState(
		&depth_stencil_description,
		&depth_stencil_state,
	)

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
	renderer.device->CreateBuffer(
		&constant_buffer_description,
		nil,
		&constant_buffer,
	)

	vertex_buffer_description := d3d11.BUFFER_DESC {
		ByteWidth = size_of(vertex_data),
		Usage     = .IMMUTABLE,
		BindFlags = {.VERTEX_BUFFER},
	}
	vertex_buffer: ^d3d11.IBuffer
	renderer.device->CreateBuffer(
		&vertex_buffer_description,
		&d3d11.SUBRESOURCE_DATA {
			pSysMem = &vertex_data[0],
			SysMemPitch = size_of(vertex_data),
		},
		&vertex_buffer,
	)

	index_buffer_description := d3d11.BUFFER_DESC {
		ByteWidth = size_of(index_data),
		Usage     = .IMMUTABLE,
		BindFlags = {.INDEX_BUFFER},
	}
	index_buffer: ^d3d11.IBuffer
	renderer.device->CreateBuffer(
		&index_buffer_description,
		&d3d11.SUBRESOURCE_DATA {
			pSysMem = &index_data[0],
			SysMemPitch = size_of(index_data),
		},
		&vertex_buffer,
	)

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
	renderer.device->CreateTexture2D(
		&texture_description,
		&texture_data,
		&texture,
	)

	texture_view: ^d3d11.IShaderResourceView
	renderer.device->CreateShaderResourceView(texture, nil, &texture_view)

	clear_color := [?]f32{0.025, 0.025, 0.025, 1.0}

	vertex_buffer_stride := u32(11 * 4)
	vertex_buffer_offset := u32(0)

	model_rotation := glm.vec3{0.0, 0.0, 0.0}
	model_translation := glm.vec3{0.0, 0.0, 0.0}

	quit := false
	for (quit) {
		msg: win32.MSG
		for (win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_REMOVE)) {
			win32.TranslateMessage(&msg)
			// Handle message here
			win32.DispatchMessageW(&msg)
		}

		viewport := d3d11.VIEWPORT {
			0,
			0,
			f32(depth_buffer_description.Width),
			f32(depth_buffer_description.Height),
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
		renderer.device_context->OMSetBlendState(
			nil,
			nil,
			u32(d3d11.COLOR_WRITE_ENABLE_ALL),
		)

		renderer.device_context->DrawIndexed(len(index_data), 0, 0)

		renderer.swapchain->Present(1, {.TEST})
		// if (result != 0) {fmt.printfln("res : %i", result)}
	}
}
