# This justfile only works on windows (but so does the program)

set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]

build: (_setup "./out/dbg")
	odin build src -out:out/dbg/learn-directx-11.exe -o:minimal -show-timings -debug -vet-unused -vet-unused-variables -vet-unused-imports -vet-shadowing -vet-using-stmt -vet-using-param -vet-style -vet-semicolon -vet-cast -vet-tabs -strict-style -warnings-as-errors -error-pos-style:unix

build-rel: (_setup "./out/rel")
	odin build src -out:out/rel/learn-directx-11.exe -o:speed -show-timings -disable-assert -no-bounds-check -lld -subsystem:console -error-pos-style:unix

run: (_setup "./out/dbg")
	odin run src/ -out:out/learn-directx-11.exe -o:minimal -show-timings -debug -error-pos-style:unix

@_setup DIRECTORY:
	New-Item -ItemType Directory -Path {{DIRECTORY}} -Force > $null