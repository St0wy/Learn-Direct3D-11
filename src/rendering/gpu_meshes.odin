package rendering

import "core:fmt"
import win32 "core:sys/windows"
import "vendor:directx/d3d11"

GpuMesh :: struct {
	vertex_buffer:        ^d3d11.IBuffer,
	index_buffer:         ^d3d11.IBuffer,
	vertex_buffer_stride: u32,
	index_buffer_len:     u32,
}

GpuMeshManager :: struct {
	meshes: [dynamic]GpuMesh,
}

GpuMeshId :: distinct u32

get_gpu_mesh :: proc(manager: GpuMeshManager, id: GpuMeshId) -> GpuMesh {
	return manager.meshes[id]
}

add_gpu_mesh :: proc(
	manager: ^GpuMeshManager,
	gpu_mesh: GpuMesh,
) -> GpuMeshId {
	append(&manager.meshes, gpu_mesh)
	return GpuMeshId(len(manager.meshes) - 1)
}

upload_mesh_to_gpu :: proc(
	renderer: ^D3DRenderer,
	mesh: Mesh,
) -> (
	GpuMeshId,
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
		return 0, false
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
		return 0, false
	}

	gpu_mesh.vertex_buffer_stride = size_of(Vertex)
	gpu_mesh.index_buffer_len = u32(len(mesh.indices))

	gpu_mesh_id := add_gpu_mesh(&renderer.gpu_mesh_manager, gpu_mesh)

	return gpu_mesh_id, true
}

destroy_gpu_mesh_manager :: proc(manager: GpuMeshManager) {
	for mesh in manager.meshes {
		destroy_gpu_mesh(mesh)
	}

	delete(manager.meshes)
}

destroy_gpu_mesh :: proc(gpu_mesh: GpuMesh) {
	gpu_mesh.index_buffer->Release()
	gpu_mesh.vertex_buffer->Release()
}
