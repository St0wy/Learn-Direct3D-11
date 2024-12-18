package rendering

import "core:fmt"
import win32 "core:sys/windows"
import "vendor:directx/d3d11"
import d3d "vendor:directx/d3d_compiler"
import "vendor:directx/dxgi"

D3DRenderer :: struct {
	// D3D11 stuff
	window_handle:        win32.HWND,
	base_device:          ^d3d11.IDevice,
	base_device_context:  ^d3d11.IDeviceContext,
	device:               ^d3d11.IDevice,
	device_context:       ^d3d11.IDeviceContext,
	dxgi_device:          ^dxgi.IDevice,
	dxgi_adapter:         ^dxgi.IAdapter,
	dxgi_factory:         ^dxgi.IFactory2,
	swapchain:            ^dxgi.ISwapChain1,
	framebuffer:          ^d3d11.ITexture2D,
	framebuffer_view:     ^d3d11.IRenderTargetView,
	depth_buffer:         ^d3d11.ITexture2D,
	depth_buffer_view:    ^d3d11.IDepthStencilView,
	rasterizer_state:     ^d3d11.IRasterizerState,
	sampler_state:        ^d3d11.ISamplerState,
	depth_stencil_state:  ^d3d11.IDepthStencilState,
	viewport:             d3d11.VIEWPORT,
	debug:                ^d3d11.IDebug,
	// My own stuff
	gpu_textures_manager: GpuTexturesManager,
	gpu_mesh_manager:     GpuMeshManager,
	materials_manager:    MaterialsManager,
	// Things that will maybe move
	// main_pipeline:        Pipeline,
	constant_buffer:      ^d3d11.IBuffer,
}

Pipeline :: struct {
	vs_blob:        ^d3d11.IBlob,
	vertex_shader:  ^d3d11.IVertexShader,
	input_layout:   ^d3d11.IInputLayout,
	ps_blob:        ^d3d11.IBlob,
	pixel_shader:   ^d3d11.IPixelShader,
	is_initialized: bool,
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
		nil, // This returns the feature levels
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
		fmt.eprintln("Could not create device (%X)", u32(result))
		return renderer, false
	}

	result =
	renderer.base_device_context->QueryInterface(
		d3d11.IDeviceContext_UUID,
		(^rawptr)(&renderer.device_context),
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create device context (%X)", u32(result))
		return renderer, false
	}

	when ODIN_DEBUG {
		result =
		renderer.device->QueryInterface(
			d3d11.IDebug_UUID,
			(^rawptr)(&renderer.debug),
		)

		if (!win32.SUCCEEDED(result)) {
			renderer.debug = nil
		}
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
		Format = .B8G8R8A8_UNORM,
		Stereo = false,
		SampleDesc = {Count = 1, Quality = 0},
		BufferUsage = {.RENDER_TARGET_OUTPUT},
		BufferCount = 3,
		Scaling = .NONE,
		SwapEffect = .FLIP_DISCARD,
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

	could_setup_swapchain := setup_swapchain(&renderer)
	if (!could_setup_swapchain) {return renderer, false}

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

destroy_renderer :: proc(renderer: ^D3DRenderer) {
	renderer.device_context->Flush()
	renderer.device_context->ClearState()

	renderer.framebuffer->Release()
	renderer.framebuffer_view->Release()
	renderer.depth_buffer->Release()
	renderer.depth_buffer_view->Release()

	renderer.rasterizer_state->Release()
	renderer.sampler_state->Release()
	renderer.depth_stencil_state->Release()

	renderer.device->Release()
	renderer.device_context->Release()
	renderer.base_device->Release()
	renderer.base_device_context->Release()
	renderer.dxgi_device->Release()
	renderer.dxgi_adapter->Release()
	renderer.dxgi_factory->Release()
	renderer.swapchain->Release()

	destroy_gpu_textures_manager(renderer.gpu_textures_manager)
	destroy_gpu_mesh_manager(renderer.gpu_mesh_manager)
	destroy_materials_manager(renderer.materials_manager)

	when ODIN_DEBUG {
		renderer.debug->ReportLiveDeviceObjects({.DETAIL})
		renderer.debug->Release()
	}
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

// TODO : Return the pipeline and don't store it
create_pipeline :: proc(
	renderer: ^D3DRenderer,
	pipeline_descriptor: PipelineDescriptor,
) -> (
	Pipeline,
	bool,
) {
	pipeline: Pipeline

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
		&pipeline.vs_blob,
		nil,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintfln("Could not compile vertex shader (%X)", u32(result))
		return pipeline, false
	}

	result =
	renderer.device->CreateVertexShader(
		pipeline.vs_blob->GetBufferPointer(),
		pipeline.vs_blob->GetBufferSize(),
		nil,
		&pipeline.vertex_shader,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintfln("Could not create vertex shader (%X)", u32(result))
		return pipeline, false
	}

	result =
	renderer.device->CreateInputLayout(
		&pipeline_descriptor.input_element_description[0],
		cast(u32)len(pipeline_descriptor.input_element_description),
		pipeline.vs_blob->GetBufferPointer(),
		pipeline.vs_blob->GetBufferSize(),
		&pipeline.input_layout,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create input layout (%X)", u32(result))
		return pipeline, false
	}

	result = d3d.Compile(
		raw_data(pipeline_descriptor.pixel_shader_source),
		len(pipeline_descriptor.pixel_shader_source),
		pipeline_descriptor.pixel_shader_filename,
		nil,
		nil,
		pipeline_descriptor.pixel_shader_entry,
		"ps_5_0",
		0,
		0,
		&pipeline.ps_blob,
		nil,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not compile pixel shader (%X)", u32(result))
		return pipeline, false
	}

	result =
	renderer.device->CreatePixelShader(
		pipeline.ps_blob->GetBufferPointer(),
		pipeline.ps_blob->GetBufferSize(),
		nil,
		&pipeline.pixel_shader,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create pixel shader (%X)", u32(result))
		return pipeline, false
	}

	return pipeline, true
}

destroy_pipeline :: proc(pipeline: Pipeline) {
	pipeline.input_layout->Release()

	pipeline.vs_blob->Release()
	pipeline.vertex_shader->Release()

	pipeline.ps_blob->Release()
	pipeline.pixel_shader->Release()
}

init_constant_buffer :: proc(renderer: ^D3DRenderer, $C: typeid) -> bool {
	constant_buffer_description := d3d11.BUFFER_DESC {
		ByteWidth      = size_of(C),
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

destroy_constant_buffer :: proc(renderer: ^D3DRenderer) {
	renderer.constant_buffer->Release()
}

upload_constant_buffer :: proc(renderer: ^D3DRenderer, constants: $C) -> bool {
	mapped_subresource: d3d11.MAPPED_SUBRESOURCE

	result := renderer.device_context->Map(
		renderer.constant_buffer,
		0,
		.WRITE_DISCARD,
		{},
		&mapped_subresource,
	)
	if (!win32.SUCCEEDED(result)) {return false}

	mapped_constants := (^C)(mapped_subresource.pData)
	mapped_constants^ = constants

	renderer.device_context->Unmap(renderer.constant_buffer, 0)

	return true
}

clear :: proc(renderer: ^D3DRenderer, clear_color: [4]f32) {
	clear_color := clear_color
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
}

// The const buffer is stored inside the renderer struct
// ? FIXME: Maybe I should find a better way to handle const buffers, but I spent too much time on this API stuff
// ? So this is a problem for future me
bind_pipeline_and_const_buffer :: proc(
	renderer: ^D3DRenderer,
	pipeline: Pipeline,
) {
	renderer.device_context->IASetInputLayout(pipeline.input_layout)

	renderer.device_context->VSSetShader(pipeline.vertex_shader, nil, 0)

	renderer.device_context->PSSetShader(pipeline.pixel_shader, nil, 0)

	renderer.device_context->VSSetConstantBuffers(
		0,
		1,
		&renderer.constant_buffer,
	)
}

setup_material_resources :: proc(
	renderer: ^D3DRenderer,
	material_id: MaterialId,
) {

	material := get_mat(renderer.materials_manager, material_id)
	switch mat in material {
	case DemoMaterial:
		base_color_view :=
			get_tex(renderer.gpu_textures_manager, mat.base_color_id).view
		renderer.device_context->PSSetShaderResources(0, 1, &base_color_view)
		renderer.device_context->PSSetSamplers(0, 1, &renderer.sampler_state)
	}
}

setup_renderer_state :: proc(renderer: ^D3DRenderer) {
	renderer.device_context->RSSetViewports(1, &renderer.viewport)
	renderer.device_context->RSSetState(renderer.rasterizer_state)

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
}

draw_mesh :: proc(
	renderer: ^D3DRenderer,
	gpu_mesh_id: GpuMeshId,
	material_id: MaterialId,
	pipeline: Pipeline,
) {
	bind_pipeline_and_const_buffer(renderer, pipeline)

	setup_material_resources(renderer, material_id)

	gpu_mesh := get_gpu_mesh(renderer.gpu_mesh_manager, gpu_mesh_id)

	vertex_buffer_offset := u32(0)

	// For now, only triangle list are supported
	renderer.device_context->IASetPrimitiveTopology(.TRIANGLELIST)

	renderer.device_context->IASetVertexBuffers(
		0,
		1,
		&gpu_mesh.vertex_buffer,
		&gpu_mesh.vertex_buffer_stride,
		&vertex_buffer_offset,
	)
	renderer.device_context->IASetIndexBuffer(
		gpu_mesh.index_buffer,
		.R32_UINT,
		0,
	)

	renderer.device_context->DrawIndexed(gpu_mesh.index_buffer_len, 0, 0)
}

present :: proc(renderer: ^D3DRenderer) {
	result := renderer.swapchain->Present(1, {})
	if (!win32.SUCCEEDED(result)) {
		panic(fmt.tprintfln("Could not present swapchain : %X", u32(result)))
	}
}

resize_renderer :: proc(renderer: ^D3DRenderer, size: [2]i32) -> bool {
	assert(size.x > 0 && size.y > 0)

	fmt.printfln("Resizing renderer to : %i %i", size.x, size.y)

	renderer.device_context->OMSetRenderTargets(0, nil, nil)

	renderer.framebuffer->Release()
	renderer.framebuffer = nil
	renderer.framebuffer_view->Release()
	renderer.framebuffer_view = nil

	renderer.depth_buffer->Release()
	renderer.depth_buffer = nil
	renderer.depth_buffer_view->Release()
	renderer.depth_buffer_view = nil

	renderer.device_context->Flush()

	result := renderer.swapchain->ResizeBuffers(
		3,
		u32(size.x),
		u32(size.y),
		.B8G8R8A8_UNORM,
		{},
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintfln("Could not resize swapchain buffers : %X", u32(result))
		return false
	}

	could_setup_swapchain := setup_swapchain(renderer)
	if (!could_setup_swapchain) {return false}

	return true
}

setup_swapchain :: proc(renderer: ^D3DRenderer) -> bool {
	result := renderer.swapchain->GetBuffer(
		0,
		d3d11.ITexture2D_UUID,
		(^rawptr)(&renderer.framebuffer),
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln(
			"Could not get framebuffer from swapchain (%X)",
			u32(result),
		)
		return false
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
		return false
	}

	depth_buffer_description: d3d11.TEXTURE2D_DESC
	renderer.framebuffer->GetDesc(&depth_buffer_description)
	depth_buffer_description.Format = .D24_UNORM_S8_UINT
	depth_buffer_description.BindFlags = {.DEPTH_STENCIL}

	renderer.viewport = {
		0,
		0,
		f32(depth_buffer_description.Width),
		f32(depth_buffer_description.Height),
		0,
		1,
	}

	result =
	renderer.device->CreateTexture2D(
		&depth_buffer_description,
		nil,
		&renderer.depth_buffer,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create depth buffer (%X)", u32(result))
		return false
	}

	result =
	renderer.device->CreateDepthStencilView(
		renderer.depth_buffer,
		nil,
		&renderer.depth_buffer_view,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create depth buffer view (%X)", u32(result))
		return false
	}

	return true
}
