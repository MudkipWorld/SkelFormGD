@tool
extends Resource
class_name SkelformRuntime


class ConstructOptions:
	var position: Vector2
	var scale: Vector2
	var fabrik_iterations : int
	var disable_ik : bool = false
	var propagate_visibility : bool = false

	func _init(pos: Vector2 = Vector2.ZERO, s: Vector2 = Vector2.ONE, flip: bool = true, fab_i : int = 10, _dis_ik : bool = false, prop_visib : bool = false):
		position = pos
		scale = s
		fabrik_iterations = fab_i
		disable_ik = _dis_ik
		propagate_visibility = prop_visib

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
	
	var visuals_id : int = -1
	var physics_id : int = -1
	var inverse_kinematics_id : int = -1
	var ik_family_id : int = -1
	
	var init_rot: float
	var init_scale: Vector2
	var init_pos: Vector2

	var init_hidden : float = 0.0
	
	var zindex: int = 0
	var tint : Color = Color.WHITE
	var init_tint : Color = Color.WHITE
	var phys_global_pos : Vector2
	var phys_global_orbit: float

	var phys_pos_damping: float = 0.0
	var phys_sway: float = 0.0
	var phys_pos_ratio: float = 0.0
	var phys_scale_damping: float = 0.0
	var phys_scale_ratio: float = 0.0
	var phys_global_scale: Vector2
	var phys_rot_damping: float = 0.0
	var phys_global_rot: float = 0.0
	var phys_rot_bounce: float = 0.0
	var phys_global_orbit_vel: float = 0.0
	var phys_global_orbit_diff: float = 0.0

	var hidden : float = 0.0
	var binds: Array = []
	var vertices: Array[Vertex] = []
	var indices: PackedInt32Array

	func _init(_name="", _id=0, _parent_id=-1):
		name = _name
		id = _id
		parent_id = _parent_id
		style_ids = []
		scale = Vector2.ONE
		pos = Vector2.ZERO
		init_scale = Vector2.ONE
		init_pos = Vector2.ZERO
		phys_global_scale = Vector2.ONE

	func copy() -> Bone:
		var b := Bone.new(name, id, parent_id)
		b.style_ids = style_ids.duplicate(true)
		b.tex = tex
		b.rot = rot
		b.scale = scale
		b.pos = pos
		
		b.phys_pos_damping = phys_pos_damping
		b.phys_sway = phys_sway
		b.phys_scale_damping = phys_scale_damping
		b.phys_rot_damping = phys_rot_damping
		b.phys_rot_bounce = phys_rot_bounce
		
		b.visuals_id = visuals_id
		b.physics_id = physics_id
		b.inverse_kinematics_id  = inverse_kinematics_id
		b.ik_family_id = ik_family_id
		
		b.init_rot = init_rot
		b.init_scale = init_scale
		b.init_pos = init_pos
		
		b.zindex = zindex
		b.binds = binds.duplicate(true)
		b.indices = indices.duplicate()
		b.vertices = []
		b.tint = tint
		b.hidden = hidden
		# Copy vertices
		b.vertices.resize(vertices.size())
		for i in range(vertices.size()):
			var v := vertices[i]
			var nv := Vertex.new(v.initPos, v.uv)
			nv.pos_override = v.pos_override
			nv.pos = v.pos
			b.vertices[i] = nv
		return b

	func reset_bone():
		rot = init_rot
		scale = init_scale
		pos = init_pos
		for i in vertices:
			i.pos = i.initPos

class Visual:
	var tex: String = ""
	var init_tex: String = ""
	var tint: Color = Color.WHITE
	var init_tint: Color = Color.WHITE

	var zindex: int = 0

	var pivot_pos := Vector2.ZERO
	var pivot_scale := Vector2.ONE
	var pivot_rot := 0.0

	var vertices: Array = []
	var binds: Array = []

	var indices: PackedInt32Array = []
	var triangles: Array = []

class Keyframe:
	var frame: int
	var bone_id: int
	var element: String
	var value: float
	var value_str : String
	var start_handle : Vector2 = Vector2.ZERO
	var end_handle : Vector2 = Vector2(1,1)
	var next_kf : int = -1
	func _init(f=0, b=0, e="", v=0.0, v_str = ""):
		frame = f
		bone_id = b
		element = e
		value = v
		value_str = v_str

class AnimationData:
	var name: String
	var keyframes: Array
	var fps: int
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

class InverseKinematics:
	var family_id : int 
	var constraint : String
	var init_constraint : String
	var mode : String
	var init_mode : String
	var target_id : int
	var bone_ids : Array
	var mimic_target : bool = false
	var init_mimic_target : bool = false

class Armature:
	var bones: Array
	
	var constructed_by_id : Dictionary[int, Array]
	var physics : Array
	var inverse_kinematics : Array[InverseKinematics]
	var visuals : Array
	var constructed_bones : Array
	var ik_root_ids: Array
	var animations: Array
	var atlases: Array
	var styles: Array
	var tint : Color = Color.WHITE

class ModelData:
	var armature : Armature
	var image : Array

# ---------- Cached Loaded Files
static var existing_files : Dictionary[String, ModelData] = {}

# ---------- Animation

func animate(armature: Armature, anims, frames: Array, smooth_frames: Array) -> void:
	for a in range(anims.size()):
		var animation = anims[a]

		for k in range(animation.keyframes.size()):
			var kf = animation.keyframes[k]

			if kf.frame > frames[a]:
				break

			if kf.next_kf == -1:
				kf.next_kf = k

			var next_kf = animation.keyframes[kf.next_kf]

			var is_last = kf.next_kf == k
			var is_before_frame = next_kf.frame < frames[a]

			if is_before_frame and not is_last:
				continue

			var f = frames[a]
			var sf = smooth_frames[a]

			var bone = armature.bones[kf.bone_id]

			match kf.element:
				"PositionX":
					bone.pos.x = interpolate_keyframes(bone.pos.x, kf, next_kf, f, sf)
				"PositionY":
					bone.pos.y = interpolate_keyframes(bone.pos.y, kf, next_kf, f, sf)
				"Rotation":
					bone.rot = interpolate_keyframes(bone.rot, kf, next_kf, f, sf)
				"ScaleX":
					bone.scale.x = interpolate_keyframes(bone.scale.x, kf, next_kf, f, sf)
				"ScaleY":
					bone.scale.y = interpolate_keyframes(bone.scale.y, kf, next_kf, f, sf)
				"Hidden":
					bone.hidden = kf.value == 1

			if bone.visuals_id != -1:
				var visuals = armature.visuals[bone.visuals_id]

				match kf.element:
					"Texture":
						visuals.tex = kf.value_str
					"TintR":
						visuals.tint.r = interpolate_keyframes(visuals.tint.r, kf, next_kf, f, sf)
					"TintG":
						visuals.tint.g = interpolate_keyframes(visuals.tint.g, kf, next_kf, f, sf)
					"TintB":
						visuals.tint.b = interpolate_keyframes(visuals.tint.b, kf, next_kf, f, sf)
					"TintA":
						visuals.tint.a = interpolate_keyframes(visuals.tint.a, kf, next_kf, f, sf)

			if bone.ik_family_id != -1:
				var ik = armature.inverse_kinematics[bone.ik_family_id]

				match kf.element:
					"IkConstraint":
						ik.constraint = kf.value_str
					"MimicTarget":
						ik.mimic_target = kf.value == 1

	reset_bones(armature, anims, armature.bones, frames[0], smooth_frames[0])

func interpolate_keyframes(field: float, prevKf: Keyframe, nextKf: Keyframe, frame: int, smoothFrame: int) -> float:
	var totalFrames = nextKf.frame - prevKf.frame
	var currentFrame = frame - prevKf.frame
	var result = SkelformUtils.interpolate( currentFrame, totalFrames,  prevKf.value,  nextKf.value,  nextKf.start_handle,  nextKf.end_handle )
	var z = Vector2(0,0)
	return SkelformUtils.interpolate(currentFrame, smoothFrame, field, result, z, z)

func reset_bones( armature ,animations, bones, frame, smoothFrame):
	var element_map : Dictionary = {}

	for anim in animations:
		for kf in anim.keyframes:
			if !element_map.has(kf.bone_id):
				element_map[kf.bone_id] = []

			if kf.element not in element_map[kf.bone_id]:
				element_map[kf.bone_id].append(kf.element)
	
	var z = Vector2(0,0)
	
	for bone in bones:
		if element_map.has(bone.id):
			var reset = element_map[bone.id]

			if "PositionX" not in reset:
				bone.pos.x = SkelformUtils.interpolate(frame, smoothFrame, bone.pos.x, bone.init_pos.x, z, z)
			if "PositionY" not in reset:
				bone.pos.y =SkelformUtils. interpolate(frame, smoothFrame, bone.pos.y, bone.init_pos.y, z, z)
			if "Rotation" not in reset:
				bone.rot = SkelformUtils.interpolate(frame, smoothFrame, bone.rot, bone.init_rot, z, z)
			if "ScaleX" not in reset:
				bone.scale.x = SkelformUtils.interpolate(frame, smoothFrame, bone.scale.x, bone.init_scale.x, z, z)
			if "ScaleY" not in reset:
				bone.scale.y = SkelformUtils.interpolate(frame, smoothFrame, bone.scale.y, bone.init_scale.y, z, z)
			if "Hidden" not in reset:
				bone.hidden = bone.init_hidden
		
			if bone.visuals_id != -1:
				var visuals = armature.visuals[bone.visuals_id]
				if "Texture" not in reset:
					visuals.tex = visuals.init_tex;
				if "TintR" not in reset:
					visuals.tint.r = SkelformUtils.interpolate(frame, smoothFrame, visuals.tint.r, visuals.init_tint.r, z, z)
				if "TintG" not in reset:
					visuals.tint.g = SkelformUtils.interpolate(frame, smoothFrame, visuals.tint.g, visuals.init_tint.g, z, z)
				if "TintB" not in reset:
					visuals.tint.b = SkelformUtils.interpolate(frame, smoothFrame, visuals.tint.b, visuals.init_tint.b, z, z)
				if "TintA" not in reset:
					visuals.tint.a = SkelformUtils.interpolate(frame, smoothFrame, visuals.tint.a, visuals.init_tint.a, z, z)

			if (bone.ik_family_id != -1):
				var ik = armature.inverse_kinematics[bone.ik_family_id]
				if "IkConstraint"not in reset:
					ik.constraint = ik.init_constraint;
				if "MimicTarget"not in reset:
					ik.mimic_target = ik.init_mimic_target;

		else:
			bone.pos.x = SkelformUtils.interpolate(frame, smoothFrame, bone.pos.x, bone.init_pos.x, z, z)
			bone.pos.y = SkelformUtils.interpolate(frame, smoothFrame, bone.pos.y, bone.init_pos.y, z, z)
			bone.rot = SkelformUtils.interpolate(frame, smoothFrame, bone.rot, bone.init_rot, z, z)
			bone.scale.x = SkelformUtils.interpolate(frame, smoothFrame, bone.scale.x, bone.init_scale.x, z, z)
			bone.scale.y = SkelformUtils.interpolate(frame, smoothFrame, bone.scale.y, bone.init_scale.y, z, z)
			bone.hidden = bone.init_hidden

func construct(options: ConstructOptions, armature : Armature, delta : float) -> Array:
	var constructed_bones : Array = []
	if armature.constructed_by_id.has(get_instance_id()):
		constructed_bones = armature.constructed_by_id[get_instance_id()]
	else:
		for bone in armature.bones:
			constructed_bones.append(bone.copy())
		armature.constructed_by_id[get_instance_id()] = constructed_bones
		
	constructed_bones.sort_custom(func(a: Bone, b: Bone) -> bool:return a.id < b.id)
	
	armature.bones.sort_custom(func(a: Bone, b: Bone) -> bool:return a.id < b.id)

	reset_inheritance(constructed_bones, armature.bones)
	inheritance(constructed_bones, {}, [])
	var ik_rots: Dictionary = {}
	if armature.inverse_kinematics.size() > 0:
		ik_rots = SkelformPhysics.inverse_kinematics(constructed_bones, armature.inverse_kinematics, options)
		reset_inheritance(constructed_bones, armature.bones)
		inheritance(constructed_bones, ik_rots, [])

	if armature.physics.size() > 0:
		SkelformPhysics.simulate_physics(armature.bones, constructed_bones)
		reset_inheritance(constructed_bones, armature.bones)
		inheritance(constructed_bones, ik_rots, armature.bones)

	SkelformPhysics.construct_verts(constructed_bones, armature.visuals)

	for i in range(constructed_bones.size()):
		var b : Bone = constructed_bones[i]
		var ab : Bone = armature.bones[i]
		b.hidden = ab.hidden
		b.pos.y = -b.pos.y
		b.rot = -b.rot

		b.scale *= options.scale
		b.pos *= options.scale
		b.pos += options.position

		SkelformUtils.check_bone_flip(b, options.scale)
		

	for visual in armature.visuals:
		var vis : Visual = visual
		for v in vis.vertices:
			v.pos.y = -v.pos.y;
			v.pos   *= options.scale;
			v.pos   += options.position;
	
	if options.propagate_visibility:
		SkelformUtils.propagate_visibility(constructed_bones)

	return constructed_bones

static func reset_inheritance(constructed_bones : Array, bones : Array):
	for b in range(bones.size()):
		constructed_bones[b].pos = bones[b].pos
		constructed_bones[b].rot = bones[b].rot
		constructed_bones[b].scale = bones[b].scale

static func inheritance(bones: Array, ik_rots, armature_bones: Array):
	for b in range(bones.size()):
		var bone = bones[b]
		if bone.parent_id != -1:
			var parent : Bone = null
			for l in bones:
				if l.id == bone.parent_id:
					parent = l
					break
					
			var orbit_rot = parent.rot
			if armature_bones.size() > 0 && armature_bones[b].phys_sway > 0.0:
				orbit_rot -= armature_bones[b].phys_global_orbit_diff
				
			bone.rot += orbit_rot
			bone.scale *= parent.scale
			bone.pos *= parent.scale
			bone.pos = bones[b].pos.rotated(parent.rot)
			bone.pos += parent.pos

		if ik_rots.has(bone.id):
			bone.rot = ik_rots[bone.id]

		if armature_bones.size() > 0:
			if armature_bones[b].phys_rot_damping > 0.0:
				bone.rot = armature_bones[b].phys_global_rot
			if armature_bones[b].phys_pos_damping > 0.0:
				bone.pos = armature_bones[b].phys_global_pos
			if armature_bones[b].phys_scale_damping > 0.0:
				bone.scale = armature_bones[b].phys_global_scale

# ---------- File Loading

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

static func build_armature_from_dict(data: Dictionary) -> Armature:
	var arm := Armature.new()
	var bones = []
	arm.ik_root_ids = data.get("ik_root_ids", [])
	arm.animations = []
	arm.atlases = []
	arm.styles = []
	arm.visuals = []
	arm.inverse_kinematics = []
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
		var b : Bone = Bone.new()
		b.id = int(bone_data.get("id", 0))
		b.parent_id = int(bone_data.get("parent_id", -1))
		b.name = String(bone_data.get("name", ""))

		var pos_d = bone_data.get("pos", {})
		var scale_d = bone_data.get("scale", {})

		b.pos = Vector2(pos_d.x, pos_d.y)
		b.rot = float(bone_data.get("rot", 0.0))
		b.scale = Vector2(scale_d.x, scale_d.y)

		var init_pos_d = bone_data.get("init_pos", pos_d)
		var init_scale_d = bone_data.get("init_scale", scale_d)
		b.init_pos = Vector2(init_pos_d.x, init_pos_d.y)
		b.init_scale = Vector2(init_scale_d.x, init_scale_d.y)
		b.init_rot = float(bone_data.get("init_rot", 0.0))

		b.tex = String(bone_data.get("tex", ""))
		b.zindex = int(bone_data.get("zindex", 0))

		var tint = bone_data.get('tint', {'r' : 1.0,'g' : 1.0,'b' : 1.0,'a' : 1.0, })
		var r = tint.get('r', 1.0)
		var g = tint.get('g', 1.0)
		var bl = tint.get('b', 1.0)
		var a = tint.get('a', 1.0)
		b.tint = Color(r, g, bl, a)
		b.init_tint = Color(r, g, bl, a)
		
		var visib = bone_data.get('hidden', 0.0)
		b.hidden = visib

		b.visuals_id = bone_data.get('visuals_id',-1)
		b.physics_id = bone_data.get('physics_id', -1)
		b.inverse_kinematics_id = bone_data.get('inverse_kinematics_id', -1)
		b.ik_family_id = int(bone_data.get("family_id", -1))

		var visib_init = bone_data.get('init_hidden', 0.0)
		b.init_hidden = visib_init

		b.phys_pos_damping = bone_data.get("phys_pos_damping", 0.0)
		b.phys_sway = bone_data.get("phys_sway", 0.0)
		b.phys_scale_damping = bone_data.get("phys_scale_damping", 0.0)
		b.phys_rot_damping = bone_data.get("phys_rot_damping", 0.0)
		b.phys_rot_bounce = bone_data.get("phys_rot_bounce", 0.0)

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

	for ik_data in data.get("inverse_kinematics", []):
		var inv_kinematics : InverseKinematics = InverseKinematics.new()
		
		inv_kinematics.family_id = int(ik_data.get("family_id", -1))
		inv_kinematics.constraint = ik_data.get("constraint", "None")
		inv_kinematics.init_constraint = ik_data.get("init_constraint", inv_kinematics.constraint)
		inv_kinematics.mode = ik_data.get("mode", "FABRIK")
		inv_kinematics.init_mode = ik_data.get("init_mode", "FABRIK")
		
		inv_kinematics.target_id = int(ik_data.get("target_id", -1))
		
		inv_kinematics.bone_ids =  ik_data.get("bone_ids", [])
		inv_kinematics.mimic_target =  ik_data.get("mimic_target", false)
		inv_kinematics.init_mimic_target =  ik_data.get("init_mimic_target", inv_kinematics.mimic_target)
		

		arm.inverse_kinematics.append(inv_kinematics)
		if inv_kinematics.bone_ids.size() > 0:
			arm.ik_root_ids.append(inv_kinematics.bone_ids[0])

	var physics_array = data.get("physics", [])
	arm.physics = physics_array.duplicate(true)
	for i in range(bones.size()):
		var b = bones[i]
		if b.physics_id >= 0 and b.physics_id < physics_array.size():
			var phys = physics_array[b.physics_id]
			var gp = phys.get("global_pos", {"x": 0, "y": 0})
			var gs = phys.get("global_scale", {"x": 1, "y": 1})
			b.phys_global_pos = Vector2(float(gp.get("x", 0)), float(gp.get("y", 0)))
			b.phys_global_scale = Vector2(float(gs.get("x", 1)), float(gs.get("y", 1)))
			b.phys_global_rot = float(phys.get("global_rot", 0.0))
			b.phys_pos_damping = float(phys.get("pos_damping", 0.0))
			b.phys_scale_damping = float(phys.get("scale_damping", 0.0))
			b.phys_rot_damping = float(phys.get("rot_damping", 0.0))
			b.phys_pos_ratio = float(phys.get("pos_ratio", 0.0))
			b.phys_scale_ratio = float(phys.get("scale_ratio", 0.0))
			b.phys_global_orbit = float(phys.get("global_orbit", 0.0))
			b.phys_global_orbit_diff = float(phys.get("global_orbit_diff", 0.0))
			b.phys_global_orbit_vel = float(phys.get("global_orbit_vel", 0.0))
			b.phys_sway = float(phys.get("sway", 0.0))
			b.phys_rot_bounce = float(phys.get("rot_bounce", 0.0))

	for anim_data in data.get("animations", []):
		var anim : AnimationData = AnimationData.new()
		anim.name = anim_data.get("name", "")
		anim.fps = anim_data.get("fps", 60)
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
			kf.value_str = kf_data.get("value_str", "")
			kf.next_kf = kf_data.get("next_kf", -1)
			kf.value = kf_data.get("value", 0.0)
			anim.keyframes.append(kf)
			
		arm.animations.append(anim)
		
	for atlas_data in data.get("atlases", []):
		var a : Atlas = Atlas.new()
		a.filename = atlas_data.get("filename", "")
		var size = atlas_data.get("size", {"x": 0, "y": 0})
		a.size = Vector2(size.x, size.y)
		arm.atlases.append(a)
		
	for visual_data in data.get("visuals", []):
		var visual : Visual = Visual.new()
		
		var piv_pos = visual_data.get("pivot_pos", Vector2.ZERO)
		visual.pivot_pos = Vector2(piv_pos.x, piv_pos.y)
		
		var piv_scl = visual_data.get("pivot_scale", Vector2.ZERO)
		visual.pivot_scale = Vector2(piv_scl.x, piv_scl.y)
		
		visual.pivot_rot = visual_data.get("pivot_rot", 0.0)
		visual.zindex = visual_data.get("zindex", 0)
		visual.tex = visual_data.get("tex", "")
		visual.init_tex = visual_data.get("init_tex", visual_data.get("tex", ""))
		
		visual.vertices = []

		for v_data in visual_data.get("vertices", []):
			var px = float(v_data["pos"]["x"])
			var py = float(v_data["pos"]["y"])
			var ux = float(v_data["uv"]["x"])
			var uy = float(v_data["uv"]["y"])
			visual.vertices.append(Vertex.new(Vector2(px, py), Vector2(ux, uy)))
			
		visual.indices = PackedInt32Array()

		for idx in visual_data.get("indices", []):
			visual.indices.append(int(idx))
		visual.triangles = visual_data.get("triangles", [])
		visual.binds = []

		for bind_data in visual_data.get("binds", []):
			visual.binds.append({
				"bone_id": int(bind_data.get("bone_id", -1)),
				"is_path": bool(bind_data.get("is_path", false)),
				"verts": bind_data.get("verts", []).duplicate(true),
			})
		
		var tint = visual_data.get('tint', {'r' : 1.0,'g' : 1.0,'b' : 1.0,'a' : 1.0, })
		var r = tint.get('r', 1.0)
		var g = tint.get('g', 1.0)
		var bl = tint.get('b', 1.0)
		var a = tint.get('a', 1.0)
		
		visual.tint = Color(r, g, bl, a)
		var init_tint = visual_data.get('init_tint', tint)
		visual.init_tint = Color(init_tint.get('r', 1.0), init_tint.get('g', 1.0), init_tint.get('b', 1.0), init_tint.get('a', 1.0))
		
		arm.visuals.append(visual)

	arm.bones = bones.duplicate_deep(1)
	return arm
