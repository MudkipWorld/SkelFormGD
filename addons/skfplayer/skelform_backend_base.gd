@tool
extends Resource
class_name SkelformBackend

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
	var pos_override: Vector2
	var initPos: Vector2
	var uv: Vector2

	func _init(_init_pos := Vector2.ZERO, _uv := Vector2.ZERO):
		initPos = _init_pos
		pos_override = initPos
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
	
	var rot_override: float
	var scale_override: Vector2
	var pos_override: Vector2
	
	var ik_bone_ids: Array
	var ik_mode: String
	var ik_constraint: String
	var ik_family_id: int
	var ik_target_id: int
	var init_rot: float
	var init_scale: Vector2
	var init_pos: Vector2
	var zindex: int = 0
	var tint : Color = Color.WHITE
	
	var visible : float = 0.0
	
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
		b.ik_constraint = ik_constraint
		b.ik_family_id = ik_family_id
		b.ik_target_id = ik_target_id
		b.init_rot = init_rot
		b.init_scale = init_scale
		b.init_pos = init_pos
		
		b.rot_override =rot_override
		b.pos_override = pos_override
		b.scale_override = scale_override
		
		b.zindex = zindex
		b.binds = binds.duplicate(true)
		b.indices = indices.duplicate()
		b.vertices = []
		b.tint = tint
		b.visible = visible
		for v in vertices:
			var nv := Vertex.new(v.initPos, v.uv)
			nv.pos_override = v.pos_override
			nv.pos = v.pos
			b.vertices.append(nv)
		return b

	func reset_bone():
		rot = init_rot
		scale = init_scale
		pos = init_pos
		for i in vertices:
			i.pos = i.initPos

class Keyframe:
	var frame: int
	var bone_id: int
	var element: String
	var value: float
	var start_handle : Vector2 = Vector2.ZERO
	var end_handle : Vector2 = Vector2(1,1)
	func _init(f=0, b=0, e="", v=0.0):
		frame = f
		bone_id = b
		element = e
		value = v

class AnimationData:
	var name: String
	var keyframes: Array
	var fps: int
	var cached_frames: Array = []
	var cached_bone_frames: Array = []

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
	var cached_bones : Array
	var ik_root_ids: Array
	var animations: Array
	var atlases: Array
	var styles: Array
	var tint : Color = Color.WHITE

class CachedBoneState:
	var pos: Vector2
	var rot: float
	var scale: Vector2
	var tex: String
	var ik_constraint: String
	var tint : Color = Color.WHITE
	var visible : float = 0.0

class CachedBoneFrame:
	var bones: Array 

class ModelData:
	var armature : Armature
	var image : Array

static var existing_files : Dictionary[String, ModelData] = {}

func animate(bones: Array, anims: Array, frames: Array, smooth_frames: Array) -> void:
	pass

func reset_bone(bone: Bone, frame: int, smooth_frame: int, anims: Array) -> void:
	pass

func is_animated(element: String, bone_id: int, anims: Array) -> bool:
	for anim in anims:
		for kf in anim.keyframes:
			if kf.bone_id == bone_id and kf.element == element:
				return true
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

func get_prev_keyframe_value(keyframes: Array, bone_id: int, element: String, frame: int, default_val) -> Variant:
	var prev = null
	for kf in keyframes:
		if kf.bone_id == bone_id and kf.element == element and kf.frame <= frame:
			prev = kf
	return prev.value if prev != null else default_val

func interpolate_keyframes(bone_id: int, field: float, keyframes: Array, element: String, frame: int, smooth_frame: int) -> float:
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
	var target_value = interpolate(current_frame, total_frames, prev_kf.value, next_kf.value)
	return interpolate(current_frame, smooth_frame, prev_kf.value, target_value)

func interpolate(current: float, max_val: float, start_val: float, end_val: float) -> float:
	if max_val == 0 or current >= max_val:
		return end_val
	var t : float = current / max_val
	return start_val + (end_val - start_val) * t

func construct(anim: AnimationData, frame: float, options: ConstructOptions, armature : Armature) -> Array:
	return []

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
	pass

func inheritance(bones: Array, ik_rots: Dictionary) -> Array:
	return []

func inverse_kinematics(bones: Array, ik_root_ids: Array, option : ConstructOptions) -> Dictionary:
	var ik_rots : Dictionary = {} 
	return ik_rots

func apply_constraints(chain: Array, family: Bone, root: Vector2, target: Vector2):
	pass

func point_bones(chain: Array) -> void:
	pass

func fabrik(chain: Array, root: Vector2, target: Vector2) -> void:
	pass

func arc_ik(chain: Array, root: Vector2, target: Vector2) -> void:
	pass

func check_bone_flip(bone: Bone, scale: Vector2):
	var either : bool = scale.x < 0 or scale.y < 0
	var both : bool = scale.x < 0 and scale.y < 0
	if either && !both:
		bone.rot = -bone.rot

func inherit_vert(pos : Vector2, bone : Bone):
	pass

func load_armature_from_file(path: String,options: ConstructOptions = null) -> Dictionary:
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
		b.pos_override = Vector2(pos_d.get("x", 0.0), pos_d.get("y", 0.0))
		b.scale_override = Vector2(scale_d.get("x", 1.0), scale_d.get("y", 1.0))
		b.rot_override = float(bone_data.get("rot", 0.0))

		var init_pos_d = bone_data.get("init_pos", pos_d)
		var init_scale_d = bone_data.get("init_scale", scale_d)
		b.init_pos = Vector2(init_pos_d.x, init_pos_d.y)
		b.init_scale = Vector2(init_scale_d.x, init_scale_d.y)
		b.init_rot = b.rot_override

		b.tex = String(bone_data.get("tex", ""))
		b.zindex = int(bone_data.get("zindex", 0))

		var r = bone_data.get("TintR", 1.0)
		var g = bone_data.get("TintG", 1.0)
		var bl = bone_data.get("TintB", 1.0)
		var a = bone_data.get("TintA", 1.0)
		b.tint = Color(r, g, bl, a)

		b.ik_family_id = int(bone_data.get("ik_family_id", -1))
		b.ik_mode = bone_data.get("ik_mode", "FABRIK")
		b.ik_target_id = int(bone_data.get("ik_target_id", -1))
		b.ik_constraint = bone_data.get("ik_constraint", "Clockwise")

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
			kf.element = kf_data.get("element", "")
			
			var start_handle = kf_data.get("start_handle", {"x":0.0,"y":1.0})
			var end_handle = kf_data.get("end_handle", {"x":0.0,"y":1.0})
			
			kf.start_handle = Vector2(start_handle["x"], start_handle["y"])
			kf.end_handle = Vector2(end_handle["x"], end_handle["y"])
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
