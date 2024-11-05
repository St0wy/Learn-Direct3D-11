package main

import "core:fmt"
import win32 "core:sys/windows"
import "vendor:directx/d3d11"

GpuMesh :: struct {
	vertex_buffer: ^d3d11.IBuffer,
	index_buffer:  ^d3d11.IBuffer,
}

upload_mesh_to_gpu :: proc(
	renderer: ^D3DRenderer,
	mesh: Mesh,
) -> (
	GpuMesh,
	bool,
) {
	gpu_mesh: GpuMesh

	byte_vertices_size := u32(size_of(Vertex) * len(mesh.vertices))
	vertex_buffer_description := d3d11.BUFFER_DESC {
		ByteWidth = byte_vertices_size,
		Usage     = .IMMUTABLE,
		BindFlags = {.VERTEX_BUFFER},
	}

	result := renderer.device->CreateBuffer(
		&vertex_buffer_description,
		&d3d11.SUBRESOURCE_DATA {
			pSysMem = raw_data(mesh.vertices),
			SysMemPitch = byte_vertices_size,
		},
		&gpu_mesh.vertex_buffer,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create vertex buffer (%X)", u32(result))
		return gpu_mesh, false
	}

	byte_indices_size := u32(size_of(u32) * len(mesh.indices))
	index_buffer_description := d3d11.BUFFER_DESC {
		ByteWidth = byte_indices_size,
		Usage     = .IMMUTABLE,
		BindFlags = {.INDEX_BUFFER},
	}

	result =
	renderer.device->CreateBuffer(
		&index_buffer_description,
		&d3d11.SUBRESOURCE_DATA {
			pSysMem = raw_data(mesh.indices),
			SysMemPitch = byte_indices_size,
		},
		&gpu_mesh.index_buffer,
	)
	if (!win32.SUCCEEDED(result)) {
		fmt.eprintln("Could not create index buffer (%X)", u32(result))
		return gpu_mesh, false
	}

	return gpu_mesh, true
}
