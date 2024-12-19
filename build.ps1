If ($args[0] -eq "release") {
    Write-Host "Building release..."

    New-Item -ItemType Directory -Path ./out/rel -Force > $null

    odin build src -out:out/rel/learn-directx-11.exe -o:speed -show-timings -disable-assert -no-bounds-check -lld -subsystem:console
} Elseif ($args[0] -eq "run") {
    Write-Host "Building debug and running program..."

    New-Item -ItemType Directory -Path ./out/dbg -Force > $null

    odin run src/ -out:out/learn-directx-11.exe -o:minimal -show-timings -debug
} Else {
    Write-Host "Building debug..."

    New-Item -ItemType Directory -Path ./out/dbg -Force > $null

    odin build src -out:out/dbg/learn-directx-11.exe -o:minimal -show-timings -debug -vet-unused -vet-unused-variables -vet-unused-imports -vet-shadowing `
        -vet-using-stmt -vet-using-param -vet-style -vet-semicolon -vet-cast -vet-tabs -strict-style `
        -warnings-as-errors -linker:radlink
}

exit $LASTEXITCODE