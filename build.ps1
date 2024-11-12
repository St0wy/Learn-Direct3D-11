if ($args[0] -eq "-r") {
    Write-Host "Building release..."
    If(!(test-path -PathType container "./out/rel"))
    {
        mkdir out/rel
    }
    & odin build src -out:out/rel/learn-directx-11.exe -o:speed -show-timings -disable-assert -no-bounds-check -lld -subsystem:console -error-pos-style:unix
} else {
    Write-Host "Building debug..."
    If(!(test-path -PathType container "./out/dbg"))
    {
        mkdir out/dbg
    }
    & odin build src -out:out/dbg/learn-directx-11.exe -o:minimal -show-timings -debug -vet-unused -vet-unused-variables -vet-unused-imports -vet-shadowing `
        -vet-using-stmt -vet-using-param -vet-style -vet-semicolon -vet-cast -vet-tabs -strict-style `
        -warnings-as-errors -error-pos-style:unix
}