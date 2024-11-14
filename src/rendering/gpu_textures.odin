package rendering

import "core:fmt"
import win32 "core:sys/windows"
import "vendor:directx/d3d11"
import "vendor:directx/dxgi"

GpuTexture :: struct {
	texture: ^d3d11.ITexture2D,
	view:    ^d3d11.IShaderResourceView,
}

GpuTexturesManager :: struct {
	gpu_textures: [dynamic]GpuTexture,
}

GpuTextureId :: distinct u32

// This is useless for now, but maybe in the future this will use generation indices and the like
add_texture :: proc(
	manager: ^GpuTexturesManager,
	gpu_texture: GpuTexture,
) -> GpuTextureId {
	append(&manager.gpu_textures, gpu_texture)
	return GpuTextureId(len(manager.gpu_textures) - 1)
}

get_tex :: proc(
	manager: GpuTexturesManager,
	texture_id: GpuTextureId,
) -> GpuTexture {
	return manager.gpu_textures[texture_id]
}

destroy_gpu_textures_manager :: proc(manager: GpuTexturesManager) {
	for gpu_texture in manager.gpu_textures {
		destroy_gpu_texture(gpu_texture)
	}

	delete(manager.gpu_textures)
}

figure_out_gpu_texture_format :: proc(
	texture: Texture,
) -> (
	dxgi.FORMAT,
	bool,
) {
	if (texture.channels == .Rgba &&
		   texture.color_space == .Srgb &&
		   texture.depth == 8) {
		return .R8G8B8A8_UNORM_SRGB, true
	}

	return .UNKNOWN, false
}

upload_texture_to_gpu :: proc(
	renderer: ^D3DRenderer,
	texture: Texture,
) -> (
	GpuTextureId,
	bool,
) {
	gpu_texture: GpuTexture

	gpu_texture_format, could_figure_out := figure_out_gpu_texture_format(
		texture,
	)
	if (!could_figure_out) {
		fmt.eprintfln("Texture format not supported by the renderer.")
		return 0, false
	}

	texture_description := d3d11.TEXTURE2D_DESC {
		Width = u32(texture.width),
		Height = u32(texture.height),
		MipLevels = 1,
		ArraySize = 1,
		Format = gpu_texture_format,
		SampleDesc = {Count = 1},
		Usage = .IMMUTABLE,
		BindFlags = {.SHADER_RESOURCE},
	}

	texture_data := d3d11.SUBRESOURCE_DATA {
		pSysMem     = raw_data(texture.data),
		SysMemPitch = u32(texture.width * channel_count(texture.channels)),
	}

	result := renderer.device->CreateTexture2D(
		&texture_description,
		&texture_data,
		&gpu_texture.texture,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create gpu texture (%X)", u32(result))
		return 0, false
	}

	result =
	renderer.device->CreateShaderResourceView(
		gpu_texture.texture,
		nil,
		&gpu_texture.view,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create gpu texture view (%X)", u32(result))
		return 0, false
	}

	id := add_texture(&renderer.gpu_textures_manager, gpu_texture)
	return id, true
}

destroy_gpu_texture :: proc(gpu_texture: GpuTexture) {
	gpu_texture.texture->Release()
	gpu_texture.view->Release()
}
