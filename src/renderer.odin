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
	main_pipeline:       Pipeline,
}

Pipeline :: struct {
	vs_blob:        ^d3d11.IBlob,
	vertex_shader:  ^d3d11.IVertexShader,
	input_layout:   ^d3d11.IInputLayout,
	ps_blob:        ^d3d11.IBlob,
	pixel_shader:   ^d3d11.IPixelShader,
	is_initialized: bool,
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

	vertex_shader: ^d3d11.IVertexShader
	result =
	renderer.device->CreateVertexShader(
		vs_blob->GetBufferPointer(),
		vs_blob->GetBufferSize(),
		nil,
		&vertex_shader,
	)
    if (!win32.SUCCEEDED(result)) {
		fmt.eprintln(" (%X)", u32(result))
		return false
	}
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
    if (!win32.SUCCEEDED(result)) {
		fmt.eprintln(" (%X)", u32(result))
		return false
	}
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
    if (!win32.SUCCEEDED(result)) {
		fmt.eprintln(" (%X)", u32(result))
		return false
	}
	check_error("Could not compile pixel shader", result)

	pixel_shader: ^d3d11.IPixelShader
	result =
	renderer.device->CreatePixelShader(
		ps_blob->GetBufferPointer(),
		ps_blob->GetBufferSize(),
		nil,
		&pixel_shader,
	)
    if (!win32.SUCCEEDED(result)) {
		fmt.eprintln(" (%X)", u32(result))
		return false
	}
	check_error("Could not create pixel shader", result)
}
