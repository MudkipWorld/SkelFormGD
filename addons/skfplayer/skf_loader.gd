@tool
extends EditorImportPlugin

func _get_importer_name() -> String:
	return "skelform.armature"

func _get_visible_name() -> String:
	return "Skelform Armature"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["skf"])

func _get_save_extension() -> String:
	return "res"

func _get_resource_type() -> String:
	return "Resource"

func _get_import_options(path: String, add_preset: int) -> Array:
	return []

func _get_priority() -> float:
	return 1.0

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array, gen_files: Array) -> Error:
	var zip_reader = ZIPReader.new()
	var err = zip_reader.open(source_file)
	if err != OK:
		return err

	if not zip_reader.file_exists("armature.json"):
		zip_reader.close()
		return ERR_FILE_NOT_FOUND

	var json_text = zip_reader.read_file("armature.json").get_string_from_utf8()
	zip_reader.close()

	var json = JSON.new()
	var parse_err = json.parse(json_text)
	if parse_err != OK:
		return ERR_PARSE_ERROR

	var skelform_data = json.data
	var armature_resource = SkelformArmatureResource.new()
	
	armature_resource.version = skelform_data.get("version", "0.0.0")
	
	var raw_ik_ids = skelform_data.get("ik_root_ids", [])
	armature_resource.ik_root_ids = type_convert(raw_ik_ids, TYPE_ARRAY)

	for bone_data in skelform_data.get("bones", []):
		var bone = SkelformBoneResource.new()
		bone.id = bone_data.get("id", 0)
		bone.name = bone_data.get("name", "")
		bone.parent_id = bone_data.get("parent_id", -1)
		bone.tex = bone_data.get("tex", "")
		bone.z_index = bone_data.get("zindex", 0)
		
		var pos_data = bone_data.get("pos", {"x":0.0, "y":0.0})
		bone.pos = Vector2(pos_data.x, pos_data.y)
		
		var scale_data = bone_data.get("scale", {"x":1.0, "y":1.0})
		bone.scale = Vector2(scale_data.x, scale_data.y)
		
		bone.rot = bone_data.get("rot", 0.0)
		
		var init_pos_data = bone_data.get("init_pos", pos_data)
		bone.init_pos = Vector2(init_pos_data.x, init_pos_data.y)
		
		var init_scale_data = bone_data.get("init_scale", scale_data)
		bone.init_scale = Vector2(init_scale_data.x, init_scale_data.y)
		
		bone.init_rot = bone_data.get("init_rot", 0.0)
		
		bone.ik_family_id = bone_data.get("ik_family_id", -1)
		bone.ik_constraint_str = bone_data.get("ik_constraint_str", "")
		bone.ik_constraint = bone_data.get("ik_constraint", 0)
		bone.ik_mode_str = bone_data.get("ik_mode_str", "")
		bone.ik_mode = bone_data.get("ik_mode", 0)
		bone.ik_target_id = bone_data.get("ik_target_id", -1)
		
		var raw_ik_bones = bone_data.get("ik_bone_ids", [])
		bone.ik_bone_ids = type_convert(raw_ik_bones, TYPE_ARRAY)
		
		armature_resource.bones.append(bone)

	for anim_data in skelform_data.get("animations", []):
		var animation = SkelformAnimationResource.new()
		animation.name = anim_data.get("name", "")
		animation.fps = anim_data.get("fps", 24)
		
		for kf_data in anim_data.get("keyframes", []):
			var kf = SkelformKeyframeResource.new()
			kf.frame = kf_data.get("frame", 0)
			kf.bone_id = kf_data.get("bone_id", 0)
			kf.element = kf_data.get("element", 0)
			kf.element_str = kf_data.get("element_str", "")
			kf.value = kf_data.get("value", 0.0)
			kf.transition = kf_data.get("transition", "Linear")
			animation.keyframes.append(kf)
			
		armature_resource.animations.append(animation)

	for style_data in skelform_data.get("styles", []):
		var style = SkelformStyleResource.new()
		style.name = style_data.get("name", "Default")
		for tex_data in style_data.get("textures", []):
			var tex = SkelformTextureResource.new()
			tex.name = tex_data.get("name", "")
			var offset = tex_data.get("offset", {"x":0, "y":0})
			tex.offset = Vector2(offset.x, offset.y)
			var size = tex_data.get("size", {"x":0, "y":0})
			tex.size = Vector2(size.x, size.y)
			tex.atlas_idx = tex_data.get("atlas_idx", 0)
			style.textures.append(tex)
		armature_resource.styles.append(style)

	for atlas_data in skelform_data.get("atlases", []):
		var atlas = SkelformAtlasResource.new()
		atlas.filename = atlas_data.get("filename", "")
		var size = atlas_data.get("size", {"x":0, "y":0})
		atlas.size = Vector2(size.x, size.y)
		armature_resource.atlases.append(atlas)

	return ResourceSaver.save(armature_resource, save_path + "." + _get_save_extension())
