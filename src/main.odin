package main

import "base:intrinsics"
import win32 "core:sys/windows"

@(private="file")
L :: intrinsics.constant_utf16_cstring

main :: proc() {
	window := create_window(L("Hello"), win32.CW_USEDEFAULT, win32.CW_USEDEFAULT)
	defer destroy_window(window)

	msg: win32.MSG
	for (win32.GetMessageW(&msg, nil, 0, 0) > 0) {
		win32.TranslateMessage(&msg)
		win32.DispatchMessageW(&msg)
	}
}
