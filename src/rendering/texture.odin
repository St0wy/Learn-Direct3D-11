package rendering

import "core:bytes"
import "core:fmt"
import "core:image/png"
import "core:path/filepath"

TextureType :: enum {
	BaseColor,
}

TextureColorSpace :: enum {
	Srgb,
	Linear,
}

TextureChannels :: enum {
	Rgb,
	Rgba,
}

channel_count :: proc(texture_channels: TextureChannels) -> int {
	switch texture_channels {
	case .Rgb:
		return 3
	case .Rgba:
		return 4
	case:
		panic("Someone should handle the new texture channels")
	}
}

Texture :: struct {
	using descriptor: TextureDescriptor,
	width:            int,
	height:           int,
	data:             []u8,
}

TextureDescriptor :: struct {
	type:        TextureType,
	color_space: TextureColorSpace,
	channels:    TextureChannels,
	depth:       int,
	path:        string,
}

load_texture :: proc(load_descriptor: TextureDescriptor) -> (Texture, bool) {
	texture: Texture

	// Only support PNG for now
	extension := filepath.ext(load_descriptor.path)
	if (extension != ".png") {return texture, false}

	png_image: ^png.Image
	load_error: png.Error
	png_image, load_error = png.load(load_descriptor.path)
	// The image buffer is intentionally not freed, because 
	// it will be transfered to the texture. 
	// The metadata isn't read, so I assume it's safe to leave alone
	// defer free(png_image)
	defer png.destroy(png_image)

	if (load_error != nil) {
		fmt.printfln(
			"Could not load texture %v, with error %v",
			load_descriptor.path,
			load_error,
		)
		return texture, false
	}

	if (png_image.channels != channel_count(load_descriptor.channels) &&
		   png_image.depth != load_descriptor.depth) {
		fmt.printfln(
			"Could not load texture %v, because it doesn't have the correct channels count and bit depth",
			load_descriptor.path,
		)
		return texture, false
	}

	texture.data = bytes.buffer_to_bytes(&png_image.pixels)
	texture.descriptor = load_descriptor

	return texture, true
}
