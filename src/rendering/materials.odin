package rendering

DemoMaterial :: struct {
	base_color_id: GpuTextureId,
}

Material :: union {
	DemoMaterial,
}

MaterialsManager :: struct {
	materials: [dynamic]Material,
}

MaterialId :: distinct u32

create_demo_material :: proc(
	materials_manager: ^MaterialsManager,
	base_color_id: GpuTextureId,
) -> MaterialId {
	// Maybe assert some stuff about some properties of the texture ?
	material := DemoMaterial{base_color_id}
	append(&materials_manager.materials, material)

	return MaterialId(len(materials_manager.materials) - 1)
}

get_mat :: proc(
	materials_manager: MaterialsManager,
	material_id: MaterialId,
) -> Material {
	return materials_manager.materials[material_id]
}

destroy_materials_manager :: proc(manager: MaterialsManager) {
	delete(manager.materials)
}
