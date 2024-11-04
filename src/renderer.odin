package main

import "core:fmt"
import win32 "core:sys/windows"
import "vendor:directx/d3d11"
import d3d "vendor:directx/d3d_compiler"
import "vendor:directx/dxgi"

D3DRenderer :: struct {
	window_handle:       win32.HWND,
	render_zone_width:   u32,
	render_zone_height:  u32,
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
	rasterizer_state:    ^d3d11.IRasterizerState,
	sampler_state:       ^d3d11.ISamplerState,
	depth_stencil_state: ^d3d11.IDepthStencilState,
	main_pipeline:       Pipeline,
	constant_buffer:     ^d3d11.IBuffer,
}

Pipeline :: struct {
	vs_blob:        ^d3d11.IBlob,
	vertex_shader:  ^d3d11.IVertexShader,
	input_layout:   ^d3d11.IInputLayout,
	ps_blob:        ^d3d11.IBlob,
	pixel_shader:   ^d3d11.IPixelShader,
	is_initialized: bool,
}

GpuMesh :: struct {
	vertex_buffer: ^d3d11.IBuffer,
	index_buffer:  ^d3d11.IBuffer,
}

check_error :: #force_inline proc(
	msg: string,
	result: win32.HRESULT,
	loc := #caller_location,
) {
	when ODIN_DEBUG {
		if (!win32.SUCCEEDED(result)) {
			fmt.printfln("Last Windows error: %x", win32.GetLastError())
			panic(
				fmt.tprintfln("%s with error : %X", msg, u32(result)),
				loc = loc,
			)
		}
	}
}

create_renderer :: proc(window_handle: win32.HWND) -> (D3DRenderer, bool) {
	renderer: D3DRenderer
	renderer.window_handle = window_handle


	feature_levels := [1]d3d11.FEATURE_LEVEL{._11_0}

	device_flags := d3d11.CREATE_DEVICE_FLAGS{.BGRA_SUPPORT}

	when ODIN_DEBUG {
		device_flags |= {.DEBUG}
	}

	result := d3d11.CreateDevice(
		nil,
		.HARDWARE,
		nil,
		device_flags,
		&feature_levels[0],
		len(feature_levels),
		d3d11.SDK_VERSION,
		&renderer.base_device,
		nil,
		&renderer.base_device_context,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create D3D11 device (%X)", u32(result))
		return renderer, false
	}

	result =
	renderer.base_device->QueryInterface(
		d3d11.IDevice_UUID,
		(^rawptr)(&renderer.device),
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create base device (%X)", u32(result))
		return renderer, false
	}

	result =
	renderer.base_device_context->QueryInterface(
		d3d11.IDeviceContext_UUID,
		(^rawptr)(&renderer.device_context),
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create base device context (%X)", u32(result))
		return renderer, false
	}

	result =
	renderer.device->QueryInterface(
		dxgi.IDevice_UUID,
		(^rawptr)(&renderer.dxgi_device),
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create device (%X)", u32(result))
		return renderer, false
	}

	result = renderer.dxgi_device->GetAdapter(&renderer.dxgi_adapter)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not get adapter (%X)", u32(result))
		return renderer, false
	}

	result =
	renderer.dxgi_adapter->GetParent(
		dxgi.IFactory2_UUID,
		(^rawptr)(&renderer.dxgi_factory),
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not make dxgi factory (%X)", u32(result))
		return renderer, false
	}

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
		Flags = {},
	}

	result =
	renderer.dxgi_factory->CreateSwapChainForHwnd(
		renderer.device,
		renderer.window_handle,
		&swapchain_description,
		nil,
		nil,
		&renderer.swapchain,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create swapchain (%X)", u32(result))
		return renderer, false
	}

	result =
	renderer.swapchain->GetBuffer(
		0,
		d3d11.ITexture2D_UUID,
		(^rawptr)(&renderer.framebuffer),
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln(
			"Could not get framebuffer from swapchain (%X)",
			u32(result),
		)
		return renderer, false
	}

	result =
	renderer.device->CreateRenderTargetView(
		renderer.framebuffer,
		nil,
		&renderer.framebuffer_view,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln(
			"Could not create render target (framebuffer) view (%X)",
			u32(result),
		)
		return renderer, false
	}

	depth_buffer_description: d3d11.TEXTURE2D_DESC
	renderer.framebuffer->GetDesc(&depth_buffer_description)
	depth_buffer_description.Format = .D24_UNORM_S8_UINT
	depth_buffer_description.BindFlags = {.DEPTH_STENCIL}

	renderer.render_zone_width = depth_buffer_description.Width
	renderer.render_zone_height = depth_buffer_description.Height

	result =
	renderer.device->CreateTexture2D(
		&depth_buffer_description,
		nil,
		&renderer.depth_buffer,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create depth buffer (%X)", u32(result))
		return renderer, false
	}

	result =
	renderer.device->CreateDepthStencilView(
		renderer.depth_buffer,
		nil,
		&renderer.depth_buffer_view,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create depth buffer view (%X)", u32(result))
		return renderer, false
	}

	rasterizer_description := d3d11.RASTERIZER_DESC {
		FillMode = .SOLID,
		CullMode = .BACK,
	}

	result =
	renderer.device->CreateRasterizerState(
		&rasterizer_description,
		&renderer.rasterizer_state,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create rasterizer state (%X)", u32(result))
		return renderer, false
	}

	sampler_description := d3d11.SAMPLER_DESC {
		Filter         = .MIN_MAG_MIP_POINT,
		AddressU       = .WRAP,
		AddressV       = .WRAP,
		AddressW       = .WRAP,
		ComparisonFunc = .NEVER,
	}
	result =
	renderer.device->CreateSamplerState(
		&sampler_description,
		&renderer.sampler_state,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create sampler state (%X)", u32(result))
		return renderer, false
	}

	depth_stencil_description := d3d11.DEPTH_STENCIL_DESC {
		DepthEnable    = true,
		DepthWriteMask = .ALL,
		DepthFunc      = .LESS,
	}
	result =
	renderer.device->CreateDepthStencilState(
		&depth_stencil_description,
		&renderer.depth_stencil_state,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create depth stencil state (%X)", u32(result))
		return renderer, false
	}

	return renderer, true
}

// TODO : Maybe don't take a ptr ? 
destroy_renderer :: proc(renderer: ^D3DRenderer) {

}

PipelineDescriptor :: struct {
	vertex_shader_source:      []u8,
	vertex_shader_filename:    cstring,
	vertex_shader_entry:       cstring,
	input_element_description: []d3d11.INPUT_ELEMENT_DESC,
	pixel_shader_source:       []u8,
	pixel_shader_filename:     cstring,
	pixel_shader_entry:        cstring,
}

init_main_pipeline :: proc(
	renderer: ^D3DRenderer,
	pipeline_descriptor: PipelineDescriptor,
) -> bool {
	result := d3d.Compile(
		raw_data(pipeline_descriptor.vertex_shader_source),
		len(pipeline_descriptor.vertex_shader_source),
		pipeline_descriptor.vertex_shader_filename,
		nil,
		nil,
		pipeline_descriptor.vertex_shader_entry,
		"vs_5_0",
		0,
		0,
		&renderer.main_pipeline.vs_blob,
		nil,
	)
	if (renderer.main_pipeline.vs_blob == nil) {return false}
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not compile vertex shader (%X)", u32(result))
		return false
	}

	result =
	renderer.device->CreateVertexShader(
		renderer.main_pipeline.vs_blob->GetBufferPointer(),
		renderer.main_pipeline.vs_blob->GetBufferSize(),
		nil,
		&renderer.main_pipeline.vertex_shader,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create vertex shader (%X)", u32(result))
		return false
	}

	result =
	renderer.device->CreateInputLayout(
		&pipeline_descriptor.input_element_description[0],
		cast(u32)len(pipeline_descriptor.input_element_description),
		renderer.main_pipeline.vs_blob->GetBufferPointer(),
		renderer.main_pipeline.vs_blob->GetBufferSize(),
		&renderer.main_pipeline.input_layout,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create input layout (%X)", u32(result))
		return false
	}

	result = d3d.Compile(
		raw_data(pipeline_descriptor.pixel_shader_source),
		len(pipeline_descriptor.pixel_shader_source),
		pipeline_descriptor.vertex_shader_filename,
		nil,
		nil,
		pipeline_descriptor.vertex_shader_entry,
		"ps_5_0",
		0,
		0,
		&renderer.main_pipeline.ps_blob,
		nil,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not compile pixel shader (%X)", u32(result))
		return false
	}

	result =
	renderer.device->CreatePixelShader(
		renderer.main_pipeline.ps_blob->GetBufferPointer(),
		renderer.main_pipeline.ps_blob->GetBufferSize(),
		nil,
		&renderer.main_pipeline.pixel_shader,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create pixel shader (%X)", u32(result))
		return false
	}

	return true
}

init_constant_buffer :: proc(
	renderer: ^D3DRenderer,
	constants_size: u32,
) -> bool {
	constant_buffer_description := d3d11.BUFFER_DESC {
		ByteWidth      = constants_size,
		Usage          = .DYNAMIC,
		BindFlags      = {.CONSTANT_BUFFER},
		CPUAccessFlags = {.WRITE},
	}

	result := renderer.device->CreateBuffer(
		&constant_buffer_description,
		nil,
		&renderer.constant_buffer,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create constant buffer (%X)", u32(result))
		return false
	}

	return true
}
