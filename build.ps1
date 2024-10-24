if ($args[0] -eq "-r") {
    Write-Host "Building release..."
    & odin build src -out:out/learn-directx-11.exe -o:aggressive -show-timings -disable-assert -no-bounds-check -lld -no-crt -subsystem:windows
} else {
    Write-Host "Building debug..."
    & odin build src -out:out/learn-directx-11.exe -o:minimal -show-timings -debug -vet-unused -vet-unused-variables -vet-unused-imports -vet-shadowing `
        -vet-using-stmt -vet-using-param -vet-style -vet-semicolon -vet-cast -vet-tabs -strict-style `
        -warnings-as-errors -error-pos-style:unix -sanitize:address
}