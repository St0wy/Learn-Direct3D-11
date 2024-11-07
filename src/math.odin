package main

Color :: [3]f32;

linear_to_srgb :: proc(rgb: Color) -> Color
{
	rgb = clamp(rgb, 0.0, 1.0);

    return lerp(
        pow(rgb, vec3(1.0 / 2.4)) * 1.055 - 0.055,
        rgb * 12.92,
        rgb < vec3(0.0031308)
    );
}