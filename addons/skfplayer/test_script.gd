extends RefCounted
class_name SkelformBackendTest

class ConstructOptions:
	var position: Vector2
	var scale: Vector2
	var fabrik_iterations : int
	var disable_ik : bool = false

	func _init(pos: Vector2 = Vector2.ZERO, s: Vector2 = Vector2.ONE, flip: bool = true, fab_i : int = 10, _dis_ik : bool = false):
		position = pos
		scale = s
		fabrik_iterations = fab_i
		disable_ik = _dis_ik

class Vertex:
	var pos: Vector2
	var initPos: Vector2
	var uv: Vector2

	func _init(_init_pos := Vector2.ZERO, _uv := Vector2.ZERO):
		initPos = _init_pos
		pos = _init_pos
		uv = _uv

class Bone:
	var name: String
	var id: int
	var parent_id: int
	var style_ids: Array
	var tex: String
	var rot: float
	var scale: Vector2
	var pos: Vector2
	var ik_bone_ids: Array
	var ik_mode: int
	var ik_constraint_str: String
	var ik_constraint: int
	var ik_family_id: int
	var ik_target_id: int
	var init_rot: float
	var init_scale: Vector2
	var init_pos: Vector2
	var zindex: int = 0
	var tint : Color = Color.WHITE
	
	var binds: Array = []
	var vertices: Array[Vertex] = []
	var indices: PackedInt32Array

	func _init(_name="", _id=0, _parent_id=-1):
		name = _name
		id = _id
		parent_id = _parent_id
		style_ids = []
		ik_bone_ids = []
		scale = Vector2.ONE
		pos = Vector2.ZERO
		init_scale = Vector2.ONE
		init_pos = Vector2.ZERO

	func copy() -> Bone:
		var b := Bone.new(name, id, parent_id)
		b.style_ids = style_ids.duplicate(true)
		b.tex = tex
		b.rot = rot
		b.scale = scale
		b.pos = pos
		b.ik_bone_ids = ik_bone_ids.duplicate(true)
		b.ik_mode = ik_mode
		b.ik_constraint_str = ik_constraint_str
		b.ik_constraint = ik_constraint
		b.ik_family_id = ik_family_id
		b.ik_target_id = ik_target_id
		b.init_rot = init_rot
		b.init_scale = init_scale
		b.init_pos = init_pos
		b.zindex = zindex
		b.binds = binds.duplicate(true)
		b.indices = indices.duplicate()
		b.vertices = []
		b.tint = tint
		for v in vertices:
			var nv := Vertex.new(v.initPos, v.uv)
			nv.pos = v.pos 
			b.vertices.append(nv)
		return b

class Keyframe:
	var frame: int
	var bone_id: int
	var element: int
	var value: float
	var start_handle : Vector2 = Vector2.ZERO
	var end_handle : Vector2 = Vector2(1,1)
	func _init(f=0, b=0, e=0, v=0.0):
		frame = f
		bone_id = b
		element = e
		value = v

class AnimationData:
	var name: String
	var keyframes: Array
	var fps: int
	var cached_frames: Array = []
	var cached_solved_frames: Array = []

	func _init(_name="", _fps=60):
		name = _name
		fps = _fps
		keyframes = []

class TextureData:
	var name: String
	var offset: Vector2
	var size: Vector2
	var atlas_idx: int

class Style:
	var name: String
	var textures: Array

class Atlas:
	var filename: String
	var size: Vector2

class Armature:
	var bones: Array
	var ik_root_ids: Array
	var animations: Array
	var atlases: Array
	var styles: Array
	var tint : Color = Color.WHITE

class CachedSolvedBone:
	var pos: Vector2
	var rot: float
	var scale: Vector2
	var tex: String
	var ik_constraint: int

class CachedSolvedFrame:
	var bones: Array 

class ModelData:
	var armature : Armature
	var image : Array

var thread : Thread 

static var existing_files : Dictionary[String, ModelData] = {}

func get_interpolated_val(bone_id: int, init_val: float, element: int, frame: int, keyframes: Array) -> float:
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

func animate(bones: Array, anims: Array, frames: Array, smooth_frames: Array) -> void:
	for i in range(anims.size()):
		var anim = anims[i]
		var frame = frames[i]
		var smooth = smooth_frames[i] if i < smooth_frames.size() else 0
		
		for bone in bones:
			interpolate_bone(bone, anim.keyframes, bone.id, frame, smooth)
		
		for bone in bones:
			reset_bone(bone, frame, smooth, anims)

func reset_bone(bone: Bone, frame: int, smooth_frame: int, anims: Array) -> void:
	if not is_animated("PositionX", bone.id, anims):
		bone.pos.x = interpolate_value(bone.init_pos.x, 0, frame, bone.init_pos.x, Vector2.ZERO, Vector2.ZERO)
	if not is_animated("PositionY", bone.id, anims):
		bone.pos.y = interpolate_value(bone.init_pos.y, 0,frame, bone.init_pos.y,Vector2.ZERO, Vector2.ZERO)
	if not is_animated("Rotation", bone.id, anims):
		bone.rot = interpolate_value(bone.init_rot, 0,frame, bone.init_rot,Vector2.ZERO, Vector2.ZERO)
	if not is_animated("ScaleX", bone.id, anims):
		bone.scale.x = interpolate_value(bone.init_scale.x, 0,frame, bone.init_scale.x, Vector2.ZERO, Vector2.ZERO)
	if not is_animated("ScaleY", bone.id, anims):
		bone.scale.y = interpolate_value(bone.init_scale.y, 0,frame, bone.init_scale.y,Vector2.ZERO, Vector2.ZERO)

func is_animated(property_name: String, bone_id: int, anims: Array) -> bool:
	for anim in anims:
		for kf in anim.keyframes:
			if kf.bone_id == bone_id and property_matches_element(property_name, kf.element):
				return true
	return false

func property_matches_element(prop: String, element: int) -> bool:
	match prop:
		"PositionX": return element == 0
		"PositionY": return element == 1
		"Rotation": return element == 2
		"ScaleX":   return element == 3
		"ScaleY":   return element == 4
		"IkConstraint": return element == 6
	return false

func interpolate_value(current: int, max: int,start_val: float,end_val: float,start_handle: Vector2,end_handle: Vector2) -> float:

	if(start_handle.y == 999.0 && end_handle.y == 999.0):
		return start_val;

	if(max == 0 || current >= max):
		return end_val;
	
	var initial = current / max
	var t = initial
	for i in 5 :
		var x = cubic_bezier(t, start_handle.x, end_handle.x)
		var dx = cubic_bezier_derivative(t, start_handle.x, end_handle.x)
		if(abs(dx) < 1e-5):
			break
		
		t -= (x - initial) / dx
		t = clamp(t, 0.0, 1.0)
	

	var progress = cubic_bezier(t, start_handle.y, end_handle.y)
	return start_val + (end_val - start_val) * progress

func cubic_bezier(t: float, p1: float, p2: float) -> float:
	var u = 1. - t
	return 3. * u * u * t * p1 + 3. * u * t * t * p2 + t * t * t

func cubic_bezier_derivative(t: float, p1: float, p2: float) -> float:
	var u = 1. - t
	return 3. * u * u * p1 + 6. * u * t * (p2 - p1) + 3. * t * t * (1. - p2)

func get_prev_keyframe_value(keyframes: Array, bone_id: int, element: int, frame: int, default_val) -> Variant:
	var prev = null
	for kf in keyframes:
		if kf.bone_id == bone_id and kf.element == element and kf.frame <= frame:
			prev = kf
	return prev.value if prev != null else default_val

func interpolate_bone(bone: Bone, keyframes: Array, bone_id: int, frame: int, smooth_frame: int) -> void:
	bone.pos.x = interpolate_keyframes(bone_id, bone.pos.x, keyframes, 0, frame, smooth_frame)
	bone.pos.y = interpolate_keyframes(bone_id, bone.pos.y, keyframes, 1, frame, smooth_frame)
	bone.rot   = interpolate_keyframes(bone_id, bone.rot,   keyframes, 2, frame, smooth_frame)
	bone.scale.x = interpolate_keyframes(bone_id, bone.scale.x, keyframes, 3, frame, smooth_frame) 
	bone.scale.y = interpolate_keyframes(bone_id, bone.scale.y, keyframes, 4, frame, smooth_frame) 
	bone.tex = get_prev_keyframe_value(keyframes, bone_id, 5, frame, bone.tex)
	bone.ik_constraint = get_prev_keyframe_value(keyframes, bone_id, 6, frame, bone.ik_constraint)

func interpolate_keyframes(bone_id: int, field: float, keyframes: Array, element: int, frame: int, smooth_frame: int) -> float:
	var prev_kf = get_prev_keyframe(bone_id, element, frame, keyframes)
	var next_kf = get_next_keyframe(bone_id, element, frame, keyframes)
	if prev_kf == null:
		prev_kf = next_kf
	elif next_kf == null:
		next_kf = prev_kf
	if prev_kf == null and next_kf == null:
		return field

	var total_frames = next_kf.frame - prev_kf.frame
	var current_frame = frame - prev_kf.frame
	var result = interpolate_value(current_frame, total_frames,  prev_kf.value, next_kf.value, prev_kf.start_handle,  next_kf.end_handle)

	return interpolate_value(current_frame, smooth_frame, field, result, Vector2.ZERO, Vector2.ZERO)

func construct(armature: Armature, options: ConstructOptions = null) -> Array:
	if options == null:
		options = SkelformBackendTest.ConstructOptions.new()
	var rest_bones : Array = []
	for b in armature.bones:
		rest_bones.append(b.copy())

	rest_bones = inheritance(rest_bones, {}) 
	
	var ik_results = inverse_kinematics(rest_bones, armature.ik_root_ids, options)
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

func construct_baked(anim: AnimationData, frame: float, options: ConstructOptions) -> Array:
	if anim.cached_solved_frames.is_empty():
		return []

	var idx := int(frame) % anim.cached_solved_frames.size()
	var baked: CachedSolvedFrame = anim.cached_solved_frames[idx]

	var final_bones := []
	for b in baked.bones:
		final_bones.append(b.copy())

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

func get_prev_keyframe(bone_id: int, element: int, frame: int, keyframes: Array) -> Keyframe:
	var prev: Keyframe = null
	for kf in keyframes:
		if kf.bone_id == bone_id and kf.element == element and kf.frame <= frame:
			prev = kf
	return prev

func get_next_keyframe(bone_id: int, element: int, frame: int, keyframes: Array) -> Keyframe:
	for kf in keyframes:
		if kf.bone_id == bone_id and kf.element == element and kf.frame > frame:
			return kf
	return null

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
					var rotated = rotate_point(vert.initPos, norm_angle)
					vert.pos = bind_bone.pos + rotated * weight
				else:
					var world_pos = inherit_vert(vert.initPos, bind_bone)
					vert.pos = vert.pos.lerp(world_pos, weight)

func inheritance(bones: Array, ik_rots: Dictionary) -> Array:
	for i in range(bones.size()):
		var bone : Bone = bones[i]
		if bone.parent_id == -1:
			continue
		var parent : Bone = bones[bone.parent_id]
		bone.rot += parent.rot
		bone.scale *= parent.scale
		bone.pos *= parent.scale
		bone.pos = rotate_point(bone.pos, parent.rot)
		bone.pos += parent.pos

		if ik_rots.has(bone.id):
			bone.rot = ik_rots[bone.id]
				
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
			0:
				if option == null:
					for i in range(10):
						fabrik(chain, root_bone.pos, target_bone.pos)
				else:
					for i in range(option.fabrik_iterations):
						fabrik(chain, root_bone.pos, target_bone.pos)
			1:
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
	if family.ik_constraint == 0:
		return

	var joint_dir : Vector2 = (chain[1].pos - root).normalized()
	var base_dir : Vector2 = (target - root).normalized()
	var dir : float = joint_dir.x * base_dir.y - base_dir.x * joint_dir.y
	var base_angle := atan2(base_dir.y, base_dir.x)
	var cw : bool = family.ik_constraint == 1 and dir > 0.0
	var ccw : bool = family.ik_constraint == 2 and dir < 0.0

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
			next_length = magnitude(chain[i].pos - chain[i - 1].pos)
		chain[i].pos = next_pos - dir
		next_pos = chain[i].pos

	var prev_pos = root
	var prev_length = 0.0
	for i in range(chain.size()):
		var dir = (prev_pos - chain[i].pos).normalized() * prev_length
		if dir.x != dir.x or dir.y != dir.y: 
			dir = Vector2.ZERO
		if i != chain.size() - 1:
			prev_length = magnitude(chain[i].pos - chain[i + 1].pos)
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
		b.pos = rotate_point(pos - root, base_angle) + root

func check_bone_flip(bone: Bone, scale: Vector2):
	var either : bool = scale.x < 0 or scale.y < 0
	var both : bool = scale.x < 0 and scale.y < 0
	if either && !both:
		bone.rot = -bone.rot

func rotate_point(point: Vector2, rot: float) -> Vector2:
	return Vector2(point.x * cos(rot) - point.y * sin(rot),point.x * sin(rot) + point.y * cos(rot))

func magnitude(v: Vector2) -> float:
	return sqrt(v.x * v.x + v.y * v.y)

func inherit_vert(pos, bone):
	pos = rotate_point(pos, bone.rot)
	pos += bone.pos
	return pos

func load_armature_from_file(path: String) -> Dictionary:
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
		if thread == null:
			thread = Thread.new()
		existing_files[path] = raw_model
		#print("New File Detected.") 
	return {arm = raw_model.armature, img_at = raw_model.image}

static func build_armature_from_dict(data: Dictionary) -> Armature:
	var arm := Armature.new()
	var bones = []
	arm.ik_root_ids = data.get("ik_root_ids", [])
	arm.animations = []
	arm.atlases = []
	arm.styles = []
	var texture_size_map := {}
	for style_data in data.get("styles", []):
		var s : Style = Style.new()
		s.name = style_data.get("name", "Default")
		s.textures = []
		for tex_data in style_data.get("textures", []):
			var t : TextureData = TextureData.new()
			t.name = tex_data.get("name", "")
			var offset = tex_data.get("offset", {"x": 0, "y": 0})
			t.offset = Vector2(offset.x, offset.y)
			var size = tex_data.get("size", {"x": 0, "y": 0})
			t.size = Vector2(size.x, size.y)
			t.atlas_idx = tex_data.get("atlas_idx", 0)
			s.textures.append(t)
			texture_size_map[t.name] = t.size
		arm.styles.append(s)

	for bone_data in data.get("bones", []):
		var b := Bone.new()
		b.id = int(bone_data.get("id", 0))
		b.parent_id = int(bone_data.get("parent_id", -1))
		b.name = String(bone_data.get("name", ""))

		var pos_d = bone_data.get("pos", {})
		var scale_d = bone_data.get("scale", {})
		b.pos = Vector2(pos_d.get("x", 0.0), pos_d.get("y", 0.0))
		b.scale = Vector2(scale_d.get("x", 1.0), scale_d.get("y", 1.0))
		b.rot = float(bone_data.get("rot", 0.0))

		var init_pos_d = bone_data.get("init_pos", pos_d)
		var init_scale_d = bone_data.get("init_scale", scale_d)
		b.init_pos = Vector2(init_pos_d.get("x", 0.0), init_pos_d.get("y", 0.0))
		b.init_scale = Vector2(init_scale_d.get("x", 1.0), init_scale_d.get("y", 1.0))
		b.init_rot = float(bone_data.get("init_rot", b.rot))

		b.tex = String(bone_data.get("tex", ""))
		b.zindex = int(bone_data.get("zindex", 0))

		b.ik_family_id = int(bone_data.get("ik_family_id", -1))
		b.ik_mode = int(bone_data.get("ik_mode", 0))
		b.ik_target_id = int(bone_data.get("ik_target_id", -1))
		b.ik_constraint = int(bone_data.get("ik_constraint", 0))
		b.ik_constraint_str = String(bone_data.get("ik_constraint_str", "None"))

		var ik_ids = bone_data.get("ik_bone_ids", [])
		b.ik_bone_ids = ik_ids.duplicate(true)
		b.binds = []
		for bind_data in bone_data.get("binds", []):
			b.binds.append({
				"bone_id": int(bind_data.get("bone_id", -1)),
				"is_path": bool(bind_data.get("is_path", false)),
				"verts": bind_data.get("verts", []).duplicate(true),
			})
		b.vertices = []
		for v_data in bone_data.get("vertices", []):
			var px = float(v_data["pos"]["x"])
			var py = float(v_data["pos"]["y"])
			var ux = float(v_data["uv"]["x"])
			var uy = float(v_data["uv"]["y"])
			b.vertices.append(Vertex.new(Vector2(px, py), Vector2(ux, uy)))
		b.indices = PackedInt32Array()
		for idx in bone_data.get("indices", []):
			b.indices.append(int(idx))
		if not b.vertices.is_empty() and b.indices.is_empty():
			var poly := PackedVector2Array()
			for v in b.vertices:
				poly.append(v.pos)
			if poly.size() >= 3:
				var tri := Geometry2D.triangulate_polygon(poly)
				if not tri.is_empty():
					b.indices = PackedInt32Array(tri)
		bones.append(b)

	for anim_data in data.get("animations", []):
		var anim : AnimationData = AnimationData.new()
		anim.name = anim_data.get("name", "")
		anim.fps = anim_data.get("fps", 24)
		anim.keyframes = []
		for kf_data in anim_data.get("keyframes", []):
			var kf := Keyframe.new()
			kf.frame = kf_data.get("frame", 0)
			kf.bone_id = kf_data.get("bone_id", 0)
			kf.element = kf_data.get("element", 0)
			kf.value = kf_data.get("value", 0.0)
			anim.keyframes.append(kf)
		arm.animations.append(anim)
		
	for atlas_data in data.get("atlases", []):
		var a : Atlas = Atlas.new()
		a.filename = atlas_data.get("filename", "")
		var size = atlas_data.get("size", {"x": 0, "y": 0})
		a.size = Vector2(size.x, size.y)
		arm.atlases.append(a)
		
	arm.bones = bones.duplicate_deep(1)
	return arm
