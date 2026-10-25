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

	return ResourceSaver.save(armature_resource, save_path + "." + _get_save_extension())
