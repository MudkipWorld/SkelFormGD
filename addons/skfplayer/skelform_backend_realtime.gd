@tool
extends SkelformBackend
class_name SkelformBackendRealTime

func animate(bones: Array, anims: Array, frames: Array, smooth_frames: Array) -> void:
	for i in range(anims.size()):
		var anim = anims[i]
		var frame = frames[i]
		var smooth = smooth_frames[i] if i < smooth_frames.size() else 0
		
		for bone in bones:
			interpolate_bone(bone, anim.keyframes, bone.id, frame, smooth)
		
		for bone in bones:
			reset_bone(bone, frame, smooth, anims)

func interpolate_bone(bone: Bone, keyframes: Array, bone_id: int, frame: int, smooth_frame: int) -> void:
	bone.pos.x = interpolate_keyframes(bone_id, bone.pos.x, keyframes, "PositionX", frame, smooth_frame)
	bone.pos.y = interpolate_keyframes(bone_id, bone.pos.y, keyframes, "PositionY", frame, smooth_frame)
	bone.rot   = interpolate_keyframes(bone_id, bone.rot,   keyframes, "Rotation", frame, smooth_frame)
	bone.scale.x = interpolate_keyframes(bone_id, bone.scale.x, keyframes, "ScaleX", frame, smooth_frame) 
	bone.scale.y = interpolate_keyframes(bone_id, bone.scale.y, keyframes,"ScaleY", frame, smooth_frame)
	#bone.tex = get_prev_keyframe_value(keyframes, bone_id, 5, frame, bone.tex)
	bone.ik_constraint = get_prev_keyframe_value(keyframes, bone_id, "IkConstraint", frame, bone.ik_constraint)
	
	bone.tint.r = interpolate_keyframes(bone_id, bone.tint.r, keyframes, "TintR", frame, smooth_frame)
	bone.tint.g = interpolate_keyframes(bone_id, bone.tint.g, keyframes, "TintG", frame, smooth_frame)
	bone.tint.b = interpolate_keyframes(bone_id, bone.tint.b, keyframes, "TintB", frame, smooth_frame)
	bone.tint.a = interpolate_keyframes(bone_id, bone.tint.a, keyframes, "TintA", frame, smooth_frame)
	bone.visible = interpolate_keyframes(bone_id, bone.visible, keyframes, "Hidden", frame, smooth_frame)

func reset_bone(bone: Bone, frame: int, smooth_frame: int, anims: Array) -> void:
	if not is_animated("PositionX", bone.id, anims):
		bone.pos.x = interpolate_value(bone.init_pos.x, 0, frame, bone.init_pos.x, Vector2.ZERO, Vector2(1,1))
	if not is_animated("PositionY", bone.id, anims):
		bone.pos.y = interpolate_value(bone.init_pos.y, 0,frame, bone.init_pos.y,Vector2.ZERO, Vector2(1,1))
	if not is_animated("Rotation", bone.id, anims):
		bone.rot = interpolate_value(bone.init_rot, 0,frame, bone.init_rot,Vector2.ZERO, Vector2(1,1))
	if not is_animated("ScaleX", bone.id, anims):
		bone.scale.x = interpolate_value(bone.init_scale.x, 0,frame, bone.init_scale.x, Vector2.ZERO, Vector2(1,1))
	if not is_animated("ScaleY", bone.id, anims):
		bone.scale.y = interpolate_value(bone.init_scale.y, 0,frame, bone.init_scale.y,Vector2.ZERO, Vector2(1,1))

func construct(anim: AnimationData, frame: float, options: ConstructOptions, armature : Armature) -> Array:
	if options == null:
		options = ConstructOptions.new()
		
	if armature.cached_bones.is_empty():
		for b in armature.bones:
			armature.cached_bones.append(b.copy())
	
	reset_inheritance(armature.cached_bones, armature.bones)
	inheritance(armature.cached_bones, {}) 
	
	var ik_results = inverse_kinematics(armature.cached_bones, armature.ik_root_ids, options)
	var final_bones := []
	for b in armature.bones:
		final_bones.append(b.copy())
	final_bones = inheritance(final_bones, ik_results)
	construct_verts(final_bones)
	
	for b in final_bones:
		b.pos.y = -b.pos.y
		b.rot = -b.rot

		b.scale *= options.scale
		b.pos *= options.scale
		b.pos += options.position

		check_bone_flip(b, options.scale)
		
		for v in b.vertices:
			v.pos.y = -v.pos.y
			v.pos *= options.scale
	
	return final_bones

func inheritance(bones: Array, ik_rots: Dictionary) -> Array:
	var count := bones.size()
	for i in range(count):
		var bone: Bone = bones[i]
		if bone.parent_id < 0:
			continue
			
		var parent: Bone = bones[bone.parent_id]
		bone.rot += parent.rot
		bone.scale *= parent.scale
		var scaled_pos := bone.pos * parent.scale
		var cos_r := cos(parent.rot)
		var sin_r := sin(parent.rot)
		
		bone.pos = Vector2(
			scaled_pos.x * cos_r - scaled_pos.y * sin_r,
			scaled_pos.x * sin_r + scaled_pos.y * cos_r
		) + parent.pos
		if ik_rots.has(bone.id):
			bone.rot = ik_rots[bone.id]
			
	return bones

func reset_inheritance(cached_bones : Array, bones : Array):
	for b in range(bones.size()):
		cached_bones[b].pos = bones[b].pos
		cached_bones[b].rot = bones[b].rot
		cached_bones[b].scale = bones[b].scale

func construct_verts(bones: Array) -> void:
	var bone_map := {}
	for b in bones:
		bone_map[b.id] = b
	for b in bones:
		for vert in b.vertices:
			vert.pos = inherit_vert(vert.initPos, b)
		for bi in range(b.binds.size()):
			var bind = b.binds[bi]
			if bind.bone_id == -1:
				continue
			var bind_bone = bone_map.get(bind.bone_id)
			if bind_bone == null:
				continue
			for vert_info in bind.verts:
				var vert_id = vert_info.id
				if vert_id >= b.vertices.size():
					continue
				var vert = b.vertices[vert_id]
				var weight = vert_info.weight
				if bind.is_path:
					var prev_idx = max(0, bi - 1)
					var next_idx = min(b.binds.size() - 1, bi + 1)
					var prev_bone = bone_map.get(b.binds[prev_idx].bone_id)
					var next_bone = bone_map.get(b.binds[next_idx].bone_id)
					if not prev_bone or not next_bone:
						continue
					var prev_dir = (bind_bone.pos - prev_bone.pos).normalized()
					var next_dir = (next_bone.pos - bind_bone.pos).normalized()
					var prev_norm = Vector2(-prev_dir.y, prev_dir.x)
					var next_norm = Vector2(-next_dir.y, next_dir.x)
					var average = (prev_norm + next_norm).normalized()
					var norm_angle = atan2(average.y, average.x)
					var rotated = vert.initPos.rotated(norm_angle)
					vert.pos = bind_bone.pos + rotated * weight
				else:
					var world_pos = inherit_vert(vert.initPos, bind_bone)
					vert.pos = vert.pos.lerp(world_pos, weight)

func inverse_kinematics(bones: Array, ik_root_ids: Array, option : ConstructOptions) -> Dictionary:
	var ik_rots : Dictionary = {} 
	for id in ik_root_ids:
		var root_bone = bones[id]
		if root_bone == null: continue
		
		if root_bone.ik_target_id == -1:
			continue
		
		var chain: Array = []
		for id_b in root_bone.ik_bone_ids:
			chain.append(bones[id_b])
		if chain.is_empty():
			continue

		var target_bone = bones[root_bone.ik_target_id]
		if target_bone == null:
			continue
		
		match root_bone.ik_mode:
			"FABRIK":
				if option == null:
					for i in range(10):
						fabrik(chain, root_bone.pos, target_bone.pos)
				else:
					for i in range(option.fabrik_iterations):
						fabrik(chain, root_bone.pos, target_bone.pos)
			"Arc":
				arc_ik(chain, root_bone.pos, target_bone.pos)
		point_bones(chain)
		apply_constraints(chain, root_bone, root_bone.pos, target_bone.pos)
		for b in range(chain.size()):
			if b == chain.size()- 1:
				continue
			ik_rots[chain[b].id] = chain[b].rot
	return ik_rots

func apply_constraints(chain: Array, family: Bone, root: Vector2, target: Vector2) -> void:
	if chain.size() < 2:
		return

	var joint_dir : Vector2 = (chain[1].pos - root).normalized()
	var base_dir : Vector2 = (target - root).normalized()
	var dir : float = joint_dir.x * base_dir.y - base_dir.x * joint_dir.y
	var base_angle := atan2(base_dir.y, base_dir.x)
	var cw: bool = family.ik_constraint == "Clockwise" && dir > 0;
	var ccw: bool = family.ik_constraint == "CounterClockwise" && dir < 0;

	if cw or ccw:
		for bone in chain:
			bone.rot = -bone.rot + base_angle * 2.0

func point_bones(chain: Array) -> void:
	if chain.is_empty():
		return
	var tip_pos = chain[-1].pos
	for i in range(chain.size() - 2, -1, -1):
		var b = chain[i]
		var dir = tip_pos - b.pos
		b.rot = atan2(dir.y, dir.x)
		tip_pos = b.pos
	if chain.size() >= 2:
		var last_bone = chain[-1]
		var prev_bone = chain[-2]
		var dir = last_bone.pos - prev_bone.pos
		last_bone.rot = atan2(dir.y, dir.x)

func fabrik(chain: Array, root: Vector2, target: Vector2) -> void:
	var next_pos = target
	var next_length = 0.0
	for i in range(chain.size() - 1, -1, -1):
		var dir = (next_pos - chain[i].pos).normalized() * next_length
		if dir.x != dir.x or dir.y != dir.y: 
			dir = Vector2.ZERO
		if i != 0:
			next_length = (chain[i].pos - chain[i - 1].pos).length()
		chain[i].pos = next_pos - dir
		next_pos = chain[i].pos

	var prev_pos = root
	var prev_length = 0.0
	for i in range(chain.size()):
		var dir = (prev_pos - chain[i].pos).normalized() * prev_length
		if dir.x != dir.x or dir.y != dir.y: 
			dir = Vector2.ZERO
		if i != chain.size() - 1:
			prev_length = (chain[i].pos - chain[i + 1].pos).length()
		chain[i].pos = prev_pos - dir
		prev_pos = chain[i].pos

func arc_ik(chain: Array, root: Vector2, target: Vector2) -> void:
	if chain.size() < 2:
		return

	var dist := [0.0]
	var max_length = (chain[-1].pos - root).length()
	var curr_length = 0.0

	for i in range(1, chain.size()):
		curr_length += (chain[i].pos - chain[i-1].pos).length()
		dist.append(curr_length / max_length)

	var base = target - root
	var base_angle = atan2(base.y, base.x)
	var base_mag = min(base.length(), max_length)
	var peak = max_length / base_mag
	var valley = base_mag / max_length

	for i in range(1, chain.size()):
		var b = chain[i]
		var pos = Vector2(
			b.pos.x * valley,
			root.y + (1.0 - peak) * sin(dist[i] * PI) * base_mag
		)
		b.pos = (pos - root).rotated(base_angle) + root

func inherit_vert(pos : Vector2, bone : Bone):
	pos = pos.rotated(bone.rot)
	pos += bone.pos
	return pos

func load_armature_from_file(path: String, options: ConstructOptions = null) -> Dictionary:
	var raw_model: ModelData
	var is_new_file: bool = false
	if existing_files.has(path):
		raw_model = existing_files[path]
		#print("Existing File Detected.")
	else:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {}
		file.close()
		var zip := ZIPReader.new()
		var err := zip.open(path)
		if err != OK:
			return {}
		if !zip.file_exists("armature.json"):
			zip.close()
			return {}
		var json_text = zip.read_file("armature.json").get_string_from_utf8()
		var atlases: Array = []

		var index : int = 0
		for i in zip.get_files():
			var _name := "atlas%d.png" %index
			if !zip.file_exists(_name):
				continue

			var buf := zip.read_file(_name)
			var img := Image.new()
			img.load_png_from_buffer(buf)
			img.fix_alpha_edges()
			atlases.append(img)
			index +=1
			print(_name)

		zip.close()
		var data = JSON.parse_string(json_text)
		if typeof(data) != TYPE_DICTIONARY:
			return {}
		raw_model = ModelData.new()
		raw_model.armature = build_armature_from_dict(data)
		raw_model.image = atlases

		existing_files[path] = raw_model
		#print("New File Detected.") 
	return {arm = raw_model.armature, img_at = raw_model.image}
