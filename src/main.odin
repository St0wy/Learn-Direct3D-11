package main

import "base:intrinsics"
import win32 "core:sys/windows"
import "vendor:directx/d3d11"
// import "vendor:directx/d3d_compiler"
import "vendor:directx/dxgi"

@(private = "file")
L :: intrinsics.constant_utf16_cstring

Direct3DRenderer :: struct {
	window: Window,
}

main :: proc() {
	renderer: Direct3DRenderer
	renderer.window = create_window(L("Hello"), win32.CW_USEDEFAULT, win32.CW_USEDEFAULT)
	defer destroy_window(renderer.window)

	feature_levels := [1]d3d11.FEATURE_LEVEL{d3d11.FEATURE_LEVEL._11_0}

	swapchain_description := dxgi.SWAP_CHAIN_DESC {
		BufferDesc = dxgi.MODE_DESC{Width = 0, Height = 0, Format = dxgi.FORMAT.B8G8R8A8_UNORM},
		SampleDesc = dxgi.SAMPLE_DESC{Count = 1},
		BufferUsage = dxgi.USAGE{.RENDER_TARGET_OUTPUT},
		BufferCount = 2,
		OutputWindow = renderer.window.hwnd,
		Windowed = true,
		SwapEffect = dxgi.SWAP_EFFECT.DISCARD,
	}

	// TODO : Properly create swapchain and device i think https://gist.github.com/gingerBill/b7b75772f92c5511a9cd3ca2e28eca37

	swapchain: ^dxgi.ISwapChain
	device: ^d3d11.IDevice
	device_context: ^d3d11.IDeviceContext

	d3d11.CreateDeviceAndSwapChain(
		nil,
		d3d11.DRIVER_TYPE.HARDWARE,
		nil,
		d3d11.CREATE_DEVICE_FLAGS{.BGRA_SUPPORT, .DEBUG},
		&feature_levels[0],
		len(feature_levels),
		d3d11.SDK_VERSION,
		&swapchain_description,
		&swapchain,
		&device,
		nil,
		&device_context,
	)

	swapchain->GetDesc(&swapchain_description)

	// msg: win32.MSG
	// for (win32.GetMessageW(&msg, nil, 0, 0) > 0) {
	// 	win32.TranslateMessage(&msg)
	// 	win32.DispatchMessageW(&msg)
	// }
}
