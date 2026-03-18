@tool
extends SkelformBackend
class_name SkelformBackendCached

func cache_model_animations(armature: Armature, options: ConstructOptions = null):
	cache_model(armature)
	cache_model_poses(armature, options)

func cache_model(armature: Armature):
	for anim in armature.animations:
		anim.cached_frames = []
		if anim.keyframes.is_empty():
			continue
		var last_frame = anim.keyframes[-1].frame
		var bone_count = armature.bones.size()
		for f in range(last_frame + 1):
			var frame_data = {}
			for bone_idx in range(bone_count):
				var bone = armature.bones[bone_idx]
				var px = get_interpolated_val(bone.id, bone.init_pos.x, "PositionX", f, anim.keyframes)
				var py = get_interpolated_val(bone.id, bone.init_pos.y, "PositionY", f, anim.keyframes)
				var pr = get_interpolated_val(bone.id, bone.init_rot, "Rotation", f, anim.keyframes)
				var psx = get_interpolated_val(bone.id, bone.init_scale.x, "ScaleX", f, anim.keyframes)
				var psy = get_interpolated_val(bone.id, bone.init_scale.y, "ScaleY", f, anim.keyframes)
				var p_tex = get_prev_keyframe_value(anim.keyframes, bone.id, "Texture", f, bone.tex)
				var p_ik = get_prev_keyframe_value(anim.keyframes, bone.id, "IkConstraint", f, bone.ik_constraint)
				
				var tint_r = get_interpolated_val(bone.id, bone.tint.r, "TintR", f, anim.keyframes)
				var tint_g = get_interpolated_val(bone.id, bone.tint.g, "TintG", f, anim.keyframes)
				var tint_b = get_interpolated_val(bone.id, bone.tint.b, "TintB", f, anim.keyframes)
				var tint_a = get_interpolated_val(bone.id, bone.tint.a, "TintA", f, anim.keyframes)
				var visib = get_interpolated_val(bone.id, bone.visible, "Hidden", f, anim.keyframes)
				
				var state = CachedBoneState.new()
				state.pos = Vector2(px, py)
				state.rot = pr
				state.scale = Vector2(psx, psy)
				state.tex = p_tex
				state.ik_constraint = p_ik
				state.tint = Color(tint_r, tint_g, tint_b, tint_a)
				state.visible = visib
				
				frame_data[bone.id] = state
			anim.cached_frames.append(frame_data)

func cache_model_poses(armature: Armature, options: ConstructOptions = null) -> void:
	for anim in armature.animations:
		anim.cached_bone_frames = []
		if anim.cached_frames.is_empty():
			continue
		for f in range(anim.cached_frames.size()):
			var rest_bones: Array = []
			for b in armature.bones:
				var c = b.copy()
				rest_bones.append(c)
			var local_frame: Dictionary = anim.cached_frames[f]
			for bone in rest_bones:
				var s: CachedBoneState = local_frame.get(bone.id)
				if s:
					bone.pos_override = s.pos
					bone.rot_override = s.rot
					bone.scale_override = s.scale
					bone.tex = s.tex
					bone.ik_constraint = s.ik_constraint
				else:
					bone.reset_bone()
			rest_bones = inheritance(rest_bones, {})
			var ik_rots = inverse_kinematics(rest_bones, armature.ik_root_ids, null)
			var final_bones: Array = []
			for b in armature.bones:
				var c = b.copy()
				final_bones.append(c)
			for bone in final_bones:
				var s: CachedBoneState = local_frame.get(bone.id)
				if s:
					bone.pos_override = s.pos
					bone.rot_override = s.rot
					bone.scale_override = s.scale
					bone.tex = s.tex
					bone.ik_constraint = s.ik_constraint
				else:
					bone.reset_bone()
			final_bones = inheritance(final_bones, ik_rots)
			construct_verts(final_bones)
			var solved : CachedBoneFrame = CachedBoneFrame.new()
			solved.bones = []
			for b in final_bones:
				solved.bones.append(b.copy())
			anim.cached_bone_frames.append(solved)

func get_interpolated_val(bone_id: int, init_val: float, element: String, frame: int, keyframes: Array) -> float:
	var prev_kf = get_prev_keyframe(bone_id, element, frame, keyframes)
	var next_kf = get_next_keyframe(bone_id, element, frame, keyframes)
	if prev_kf == null:
		prev_kf = next_kf
	elif next_kf == null:
		next_kf = prev_kf
	if prev_kf == null and next_kf == null:
		return init_val 
	var total_frames = next_kf.frame - prev_kf.frame
	var current_frame = frame - prev_kf.frame
	if total_frames == 0:
		return next_kf.value
	
	var t = float(current_frame) / float(total_frames)
	return lerp(prev_kf.value, next_kf.value, t)

func reset_bone(bone: Bone, frame: int, smooth_frame: int, anims: Array) -> void:
	if not is_animated("PositionX", bone.id, anims):
		bone.pos_override.x = interpolate_value(bone.init_pos.x, 0, frame, bone.init_pos.x, Vector2.ZERO, Vector2(1,1))
	if not is_animated("PositionY", bone.id, anims):
		bone.pos_override.y = interpolate_value(bone.init_pos.y, 0,frame, bone.init_pos.y,Vector2.ZERO, Vector2(1,1))
	if not is_animated("Rotation", bone.id, anims):
		bone.rot_override = interpolate_value(bone.init_rot, 0,frame, bone.init_rot,Vector2.ZERO, Vector2(1,1))
	if not is_animated("ScaleX", bone.id, anims):
		bone.scale_override.x = interpolate_value(bone.init_scale.x, 0,frame, bone.init_scale.x, Vector2.ZERO, Vector2(1,1))
	if not is_animated("ScaleY", bone.id, anims):
		bone.scale_override.y = interpolate_value(bone.init_scale.y, 0,frame, bone.init_scale.y,Vector2.ZERO, Vector2(1,1))

func construct(anim: AnimationData, frame: float, options: ConstructOptions, _armature : Armature) -> Array:
	if anim.cached_bone_frames.is_empty():
		return []
	var idx := int(frame) % anim.cached_bone_frames.size()
	var cache: CachedBoneFrame = anim.cached_bone_frames[idx]

	for b in cache.bones:
		b.reset_bone()
		b.pos = b.pos_override
		b.rot = b.rot_override
		b.scale = b.scale_override
		b.scale *= options.scale
		b.pos *= options.scale
		b.pos += options.position
		b.pos.y*=-1
		b.rot*=-1
		check_bone_flip(b, options.scale)

		for v in b.vertices:
			v.pos.y = -v.pos_override.y
			v.pos.x = v.pos_override.x
			v.pos *= options.scale
			v.pos += options.position

	return cache.bones

func get_prev_keyframe(bone_id: int, element: String, frame: int, keyframes: Array) -> Keyframe:
	var prev: Keyframe = null
	for kf in keyframes:
		if kf.bone_id != bone_id:
			continue
		if kf.element != element:
			continue
		if kf.frame > frame:
			break
		prev = kf
	return prev

func get_next_keyframe(bone_id: int, element: String, frame: int, keyframes: Array) -> Keyframe:
	for kf in keyframes:
		if kf.bone_id != bone_id:
			continue
		if kf.element != element:
			continue
		if kf.frame > frame:
			return kf
	return null

func construct_verts(bones: Array) -> void:
	var bone_map := {}
	for b in bones:
		bone_map[b.id] = b
	for b in bones:
		for vert in b.vertices:
			vert.pos_override = inherit_vert(vert.initPos, b)
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
					var prev_dir = bind_bone.pos_override - prev_bone.pos_override
					var next_dir = next_bone.pos_override - bind_bone.pos_override
					var prev_normal = (Vector2(-prev_dir.y, prev_dir.x)).normalized()
					var next_normal = (Vector2(-next_dir.y, next_dir.x)).normalized()
					var average = prev_normal + next_normal
					var normal_angle = atan2(average.y, average.x)
					var rotated = (vert.initPos).rotated(normal_angle)
					vert.pos_override = bind_bone.pos_override + rotated * weight
				else:
					var endpos = inherit_vert(vert.initPos, bind_bone) - vert.pos_override
					vert.pos_override += endpos * weight

func inheritance(bones: Array, ik_rots: Dictionary) -> Array:
	var count := bones.size()
	for i in range(count):
		var bone: Bone = bones[i]
		if bone.parent_id < 0:
			continue

		var parent: Bone = bones[bone.parent_id]

		bone.rot_override += parent.rot_override
		bone.scale_override *= parent.scale_override

		var scaled_pos := bone.pos_override * parent.scale_override
		var cos_r := cos(parent.rot_override)
		var sin_r := sin(parent.rot_override)

		bone.pos_override = Vector2(
			scaled_pos.x * cos_r - scaled_pos.y * sin_r,
			scaled_pos.x * sin_r + scaled_pos.y * cos_r
		) + parent.pos_override

		if ik_rots.has(bone.id):
			bone.rot_override = ik_rots[bone.id]

	return bones

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
						fabrik(chain, root_bone.pos_override, target_bone.pos_override)
				else:
					for i in range(option.fabrik_iterations):
						fabrik(chain, root_bone.pos_override, target_bone.pos_override)
			"Arc":
				arc_ik(chain, root_bone.pos_override, target_bone.pos_override)
		point_bones(chain)
		apply_constraints(chain, root_bone, root_bone.pos_override, target_bone.pos_override)
		for b in range(chain.size()):
			if b == chain.size()- 1:
				continue
			ik_rots[chain[b].id] = chain[b].rot_override
	return ik_rots

func apply_constraints(chain: Array, family: Bone, root: Vector2, target: Vector2):
	if chain.size() < 2:
		return

	var joint_dir : Vector2 = (chain[1].pos_override - root).normalized()
	var base_dir : Vector2 = (target - root).normalized()
	var dir: float = joint_dir.x * base_dir.y - base_dir.x * joint_dir.y;
	var baseAngle: float = atan2(base_dir.y, base_dir.x);
	var cw: bool = family.ik_constraint == "Clockwise" && dir > 0;
	var ccw: bool = family.ik_constraint == "CounterClockwise" && dir < 0;
	if ccw || cw:
		for i in chain:
			i.rot_override = -i.rot_override + baseAngle * 2

func point_bones(chain: Array) -> void:
	if chain.is_empty():
		return
	var tip_pos = chain[-1].pos_override
	for i in range(chain.size() - 2, -1, -1):
		var b = chain[i]
		var dir = tip_pos - b.pos_override
		b.rot_override = atan2(dir.y, dir.x)
		tip_pos = b.pos_override
	if chain.size() >= 2:
		var last_bone = chain[-1]
		var prev_bone = chain[-2]
		var dir = last_bone.pos_override - prev_bone.pos_override
		last_bone.rot_override = atan2(dir.y, dir.x)

func fabrik(chain: Array, root: Vector2, target: Vector2) -> void:
	var next_pos = target
	var next_length = 0.0
	for i in range(chain.size() - 1, -1, -1):
		var dir = (next_pos - chain[i].pos_override).normalized() * next_length
		if dir.x != dir.x or dir.y != dir.y: 
			dir = Vector2.ZERO
		if i != 0:
			next_length = (chain[i].pos_override - chain[i - 1].pos_override).length()
		chain[i].pos_override = next_pos - dir
		next_pos = chain[i].pos_override

	var prev_pos = root
	var prev_length = 0.0
	for i in range(chain.size()):
		var dir = (prev_pos - chain[i].pos_override).normalized() * prev_length
		if dir.x != dir.x or dir.y != dir.y: 
			dir = Vector2.ZERO
		if i != chain.size() - 1:
			prev_length = (chain[i].pos_override - chain[i + 1].pos_override).length()
		chain[i].pos_override = prev_pos - dir
		prev_pos = chain[i].pos_override

func arc_ik(chain: Array, root: Vector2, target: Vector2) -> void:
	var dist : Array = [0.0]
	var max_length = (chain[-1].pos_override - root).length()
	var curr_length = 0.0

	for i in range(1, chain.size()):
		curr_length += (chain[i].pos_override - chain[i-1].pos_override).length()
		dist.append(curr_length / max_length)

	var base = target - root
	var base_angle = atan2(base.y, base.x)
	var base_mag = min(base.length(), max_length)
	var peak = max_length / base_mag
	var valley = base_mag / max_length

	for i in range(1, chain.size()):
		var b = chain[i]
		var pos = Vector2(b.pos_override.x * valley, root.y + (1.0 - peak) * sin(dist[i] * PI) * base_mag)
		b.pos_override = (pos - root).rotated(base_angle) + root

func check_bone_flip(bone: Bone, scale: Vector2):
	var either : bool = scale.x < 0 or scale.y < 0
	var both : bool = scale.x < 0 and scale.y < 0
	if either && !both:
		bone.rot = -bone.rot

func inherit_vert(pos : Vector2, bone : Bone):
	pos = pos.rotated(bone.rot_override)
	pos += bone.pos_override
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

		cache_model_animations(raw_model.armature, options)
		existing_files[path] = raw_model
		#print("New File Detected.") 
	return {arm = raw_model.armature, img_at = raw_model.image}
