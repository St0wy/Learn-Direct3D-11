package main

import "base:intrinsics"
import win32 "core:sys/windows"

@(private = "file")
L :: intrinsics.constant_utf16_cstring

Window :: struct {
	instance:      win32.HINSTANCE,
	window_class:  win32.WNDCLASSW,
	atom:          win32.ATOM,
	hwnd:          win32.HWND,
	height_offset: i32,
	position:      [2]i32,
	size:          [2]i32,
	event:         WindowEvent,
}

WindowEvent :: struct {
	type:        WindowEventType,
	point:       [2]i32,
	keycode:     u8,
	is_in_focus: bool,
}

// Only handling a subset of events on purpose
WindowEventType :: enum {
	None,
	WindowMoved,
	WindowResized,
	WindowClosed,
	WindowEnteredFocus,
	WindowLeftFocus,
	WindowRefresh,
	KeyPressed, // This event is triggered on key down, repeat, and up
	MouseMoved,
}

GlobalWindowsEvents :: struct {
	hwnd:     win32.HWND,
	position: [2]i32,
	size:     [2]i32,
}

KeyState :: struct {
	current:  bool,
	previous: bool,
}

global_keyboard_state: [max(u8)]KeyState

global_windows_events: GlobalWindowsEvents = {
	hwnd     = nil,
	position = {-1, -1},
	size     = {-1, -1},
}

wnd_proc :: proc "system" (
	hwnd: win32.HWND,
	msg: win32.UINT,
	wparam: win32.WPARAM,
	lparam: win32.LPARAM,
) -> win32.LRESULT {
	switch msg {
	case win32.WM_MOVE:
		global_windows_events.hwnd = hwnd
		global_windows_events.position.x = i32(win32.LOWORD(lparam))
		global_windows_events.position.y = i32(win32.HIWORD(lparam))
		return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
	case win32.WM_SIZE:
		global_windows_events.hwnd = hwnd
		global_windows_events.size.x = i32(win32.LOWORD(lparam))
		global_windows_events.size.y = i32(win32.HIWORD(lparam))
		return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
	case:
		return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
	}

	return 0
}

create_window :: proc(title: string, size: [2]i32) -> (Window, bool) {
	window: Window

	// TODO : Handle DPI properly
	win32.SetProcessDPIAware()

	class_name := win32.utf8_to_wstring(title)
	window.instance = win32.HINSTANCE(win32.GetModuleHandleW(nil))
	if (window.instance == nil) {return window, false}

	window.window_class = win32.WNDCLASSW {
		lpfnWndProc   = wnd_proc,
		hInstance     = window.instance,
		lpszClassName = class_name,
		hCursor       = win32.LoadCursorW(
			nil,
			win32.wstring(win32._IDC_ARROW),
		),
	}

	window.atom = win32.RegisterClassW(&window.window_class)
	if window.atom == 0 {return window, false}

	wide_title := win32.utf8_to_wstring(title)

	dummy_window := win32.CreateWindowExW(
		0,
		class_name,
		wide_title,
		win32.WS_OVERLAPPEDWINDOW,
		win32.CW_USEDEFAULT,
		win32.CW_USEDEFAULT,
		size.x,
		size.y,
		nil,
		nil,
		window.instance,
		nil,
	)
	defer win32.DestroyWindow(dummy_window)

	window_rect, client_rect: win32.RECT
	win32.GetWindowRect(dummy_window, &window_rect)
	win32.GetClientRect(dummy_window, &client_rect)

	window.height_offset =
		(window_rect.bottom - window_rect.top) -
		(client_rect.bottom - client_rect.top)

	window.hwnd = win32.CreateWindowExW(
		0,
		class_name,
		wide_title,
		win32.WS_OVERLAPPEDWINDOW,
		win32.CW_USEDEFAULT,
		win32.CW_USEDEFAULT,
		size.x,
		size.y + window.height_offset,
		nil,
		nil,
		window.instance,
		nil,
	)
	if window.hwnd == nil {return window, false}

	global_windows_events.hwnd = nil
	global_windows_events.position = {-1, -1}
	global_windows_events.size = {-1, -1}

	window.size = size

	return window, true
}

show_window :: proc(window: ^Window) {
	win32.ShowWindow(window.hwnd, win32.SW_SHOWNORMAL)
}

// This code was done by studying how RGFW does it
check_window_event :: proc(window: ^Window) -> ^WindowEvent {
	assert(window != nil)

	if (global_windows_events.hwnd == window.hwnd) {
		if (global_windows_events.position.x != -1) {
			window.position = global_windows_events.position
			window.event.type = .WindowMoved
		}

		if (global_windows_events.size.x != -1) {
			window.size = global_windows_events.size
			window.event.type = .WindowResized
		}

		global_windows_events.hwnd = nil
		global_windows_events.position = {-1, -1}
		global_windows_events.size = {-1, -1}

		return &window.event
	}

	window.event.is_in_focus = win32.GetForegroundWindow() == window.hwnd

	msg: win32.MSG
	if (win32.PeekMessageW(&msg, window.hwnd, 0, 0, win32.PM_REMOVE)) {
		switch (msg.message) {
		case win32.WM_CLOSE:
			fallthrough
		case win32.WM_QUIT:
			window.event.type = .WindowClosed
		case win32.WM_ACTIVATE:
			window.event.is_in_focus =
				win32.LOWORD(msg.wParam) == win32.WA_INACTIVE

			if (window.event.is_in_focus) {
				window.event.type = .WindowEnteredFocus
			} else {
				window.event.type = .WindowLeftFocus
			}
		case win32.WM_PAINT:
			window.event.type = .WindowRefresh
		case win32.WM_KEYUP:
			window.event.keycode = u8(msg.wParam)
			global_keyboard_state[window.event.keycode].previous =
				is_key_pressed(window, window.event.keycode)

			window.event.type = .KeyPressed
			global_keyboard_state[window.event.keycode].current = true
		case win32.WM_KEYDOWN:
			window.event.keycode = u8(msg.wParam)
			global_keyboard_state[window.event.keycode].previous =
				is_key_pressed(window, window.event.keycode)

			window.event.type = .KeyPressed
			global_keyboard_state[window.event.keycode].current = true
		case win32.WM_INPUT:
			// Handle mouse being captured by the window for FPS movement

			size := u32(size_of(win32.RAWINPUT))
			@(static) raw: [size_of(win32.RAWINPUT)]win32.RAWINPUT
			win32.GetRawInputData(
				cast(win32.HRAWINPUT)msg.lParam,
				win32.RID_INPUT,
				raw_data(raw[:]),
				&size,
				size_of(win32.RAWINPUTHEADER),
			)

			is_not_mouse := raw[0].header.dwType != win32.RIM_TYPEMOUSE
			mouse_didnt_move :=
				raw[0].data.mouse.lLastX == 0 && raw[0].data.mouse.lLastY == 0
			if (is_not_mouse || mouse_didnt_move) {
				break
			}

			window.event.type = .MouseMoved
			window.event.point.x = raw[0].data.mouse.lLastX
			window.event.point.y = raw[0].data.mouse.lLastY
		// TODO : Mouseclicks
		case:
			window.event.type = .None
		}

		win32.TranslateMessage(&msg)
		win32.DispatchMessageW(&msg)
	} else {
		window.event.type = .None
	}

	if (!win32.IsWindow(window.hwnd)) {
		window.event.type = .WindowClosed
	}

	if (window.event.type != .None) {
		return &window.event
	} else {
		return nil
	}
}

destroy_window :: proc(window: Window) {
	win32.UnregisterClassW(
		win32.LPCWSTR(uintptr(window.atom)),
		window.instance,
	)
	win32.DestroyWindow(window.hwnd)
}

// Will repeat if key is held
is_key_pressed :: proc(window: ^Window, key: u8) -> bool {
	return(
		global_keyboard_state[key].current &&
		(window == nil || window.event.is_in_focus) \
	)
}

was_key_pressed :: proc(window: ^Window, key: u8) -> bool {
	return(
		global_keyboard_state[key].previous &&
		(window == nil || window.event.is_in_focus) \
	)
}

is_key_held :: proc(window: ^Window, key: u8) -> bool {
	return is_key_pressed(window, key) && was_key_pressed(window, key)
}

is_key_released :: proc(window: ^Window, key: u8) -> bool {
	return !is_key_pressed(window, key) && was_key_pressed(window, key)
}

is_key_newly_pressed :: proc(window: ^Window, key: u8) -> bool {
	return is_key_pressed(window, key) && !was_key_pressed(window, key)
}

is_window_minimized :: proc(window: ^Window) -> bool {
	placement: win32.WINDOWPLACEMENT
	win32.GetWindowPlacement(window.hwnd, &placement)

	return placement.showCmd == u32(win32.SW_SHOWMINIMIZED)
}
