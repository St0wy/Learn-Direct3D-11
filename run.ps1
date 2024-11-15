If(!(test-path -PathType container "./out/dbg"))
{
    mkdir out/dbg
}
& odin run src/ -out:out/learn-directx-11.exe -o:minimal -show-timings -debug `
    -error-pos-style:unix