package main

import "base:intrinsics"
import "base:runtime"
import win32 "core:sys/windows"

@(private = "file")
L :: intrinsics.constant_utf16_cstring

Window :: struct {
	instance:     win32.HINSTANCE,
	class_name:   win32.LPCWSTR,
	window_class: win32.WNDCLASSW,
	atom:         win32.ATOM,
	hwnd:         win32.HWND,
}

// on_size :: proc(hwnd: win32.HWND, flag: win32.UINT, width: u16, height: u16) {

// }

wndproc :: proc "system" (
	hwnd: win32.HWND,
	msg: win32.UINT,
	wparam: win32.WPARAM,
	lparam: win32.LPARAM,
) -> win32.LRESULT {
	context = runtime.default_context()
	switch msg {
	case win32.WM_DESTROY:
		win32.PostQuitMessage(0)
		return 0
	case win32.WM_PAINT:
		ps: win32.PAINTSTRUCT
		win32.BeginPaint(hwnd, &ps)
		win32.EndPaint(hwnd, &ps)
	// case win32.WM_SIZE:
	// 	width := win32.LOWORD(lparam)
	// 	height := win32.HIWORD(lparam)
	case:
		return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
	}

	return 0
}

create_window :: proc(
	title: win32.LPCWSTR,
	width: i32,
	height: i32,
) -> (
	Window,
	bool,
) {
	window: Window
	window.class_name = L("OdinMainClass")

	window.instance = win32.HINSTANCE(win32.GetModuleHandleW(nil))
	if (window.instance == nil) {return window, false}

	window.window_class = win32.WNDCLASSW {
		lpfnWndProc   = wndproc,
		// lpfnWndProc   = win32.DefWindowProcW,
		hInstance     = window.instance,
		lpszClassName = window.class_name,
		hCursor       = win32.LoadCursorA(nil, win32.IDC_ARROW),
	}

	window.atom = win32.RegisterClassW(&window.window_class)
	if window.atom == 0 {return window, false}

	window.hwnd = win32.CreateWindowExW(
		0,
		window.class_name,
		title,
		win32.WS_OVERLAPPEDWINDOW,
		win32.CW_USEDEFAULT,
		win32.CW_USEDEFAULT,
		width,
		height,
		nil,
		nil,
		window.instance,
		nil,
	)
	if window.hwnd == nil {return window, false}
	win32.ShowWindow(window.hwnd, win32.SW_SHOWDEFAULT)

	return window, true
}

destroy_window :: proc(window: Window) {
	if !win32.UnregisterClassW(
		win32.LPCWSTR(uintptr(window.atom)),
		window.instance,
	) {
		panic("Could not unregister window successfully")
	}
}