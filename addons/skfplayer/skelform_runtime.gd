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
	
	var ik_bone_ids: Array
	var ik_mode: String
	var ik_constraint: String
	var ik_family_id: int
	var ik_target_id: int
	
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
		ik_bone_ids = []
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
		
		b.ik_bone_ids = ik_bone_ids.duplicate(true)
		b.ik_mode = ik_mode
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

class Armature:
	var bones: Array
	
	var constructed_by_id : Dictionary[int, Array]
	var physics : Array
	var inverse_kinematics : Array
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
	var result = interpolate( currentFrame, totalFrames,  prevKf.value,  nextKf.value,  nextKf.start_handle,  nextKf.end_handle )
	var z = Vector2(0,0)
	return interpolate(currentFrame, smoothFrame, field, result, z, z)

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
				bone.pos.x = interpolate(frame, smoothFrame, bone.pos.x, bone.init_pos.x, z, z)
			if "PositionY" not in reset:
				bone.pos.y = interpolate(frame, smoothFrame, bone.pos.y, bone.init_pos.y, z, z)
			if "Rotation" not in reset:
				bone.rot = interpolate(frame, smoothFrame, bone.rot, bone.init_rot, z, z)
			if "ScaleX" not in reset:
				bone.scale.x = interpolate(frame, smoothFrame, bone.scale.x, bone.init_scale.x, z, z)
			if "ScaleY" not in reset:
				bone.scale.y = interpolate(frame, smoothFrame, bone.scale.y, bone.init_scale.y, z, z)
			if "Hidden" not in reset:
				bone.hidden = bone.init_hidden
		
			if bone.visuals_id != -1:
				var visuals = armature.visuals[bone.visuals_id]
				if "Texture" not in reset:
					visuals.tex = visuals.init_tex;
				if "TintR" not in reset:
					visuals.tint.r = interpolate(frame, smoothFrame, visuals.tint.r, visuals.init_tint.r, z, z)
				if "TintG" not in reset:
					visuals.tint.g = interpolate(frame, smoothFrame, visuals.tint.g, visuals.init_tint.g, z, z)
				if "TintB" not in reset:
					visuals.tint.b = interpolate(frame, smoothFrame, visuals.tint.b, visuals.init_tint.b, z, z)
				if "TintA" not in reset:
					visuals.tint.a = interpolate(frame, smoothFrame, visuals.tint.a, visuals.init_tint.a, z, z)

			if (bone.ik_family_id != -1):
				var ik = armature.inverse_kinematics[bone.ik_family_id]
				if "IkConstraint"not in reset:
					ik.constraint = ik.init_constraint;
				if "MimicTarget"not in reset:
					ik.mimic_target = ik.init_mimic_target;

		else:
			bone.pos.x = interpolate(frame, smoothFrame, bone.pos.x, bone.init_pos.x, z, z)
			bone.pos.y = interpolate(frame, smoothFrame, bone.pos.y, bone.init_pos.y, z, z)
			bone.rot = interpolate(frame, smoothFrame, bone.rot, bone.init_rot, z, z)
			bone.scale.x = interpolate(frame, smoothFrame, bone.scale.x, bone.init_scale.x, z, z)
			bone.scale.y = interpolate(frame, smoothFrame, bone.scale.y, bone.init_scale.y, z, z)
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
		ik_rots = inverse_kinematics(constructed_bones, armature.inverse_kinematics, options)
		reset_inheritance(constructed_bones, armature.bones)
		inheritance(constructed_bones, ik_rots, [])

	if armature.physics.size() > 0:
		simulate_physics(armature.bones, constructed_bones)
		reset_inheritance(constructed_bones, armature.bones)
		inheritance(constructed_bones, ik_rots, armature.bones)

	construct_verts(constructed_bones, armature.visuals)

	for i in range(constructed_bones.size()):
		var b : Bone = constructed_bones[i]
		var ab : Bone = armature.bones[i]
		b.hidden = ab.hidden
		b.pos.y = -b.pos.y
		b.rot = -b.rot

		b.scale *= options.scale
		b.pos *= options.scale
		b.pos += options.position

		check_bone_flip(b, options.scale)
		

	for visual in armature.visuals:
		var vis : Visual = visual
		for v in vis.vertices:
			v.pos.y = -v.pos.y;
			v.pos   *= options.scale;
			v.pos   += options.position;
	
	if options.propagate_visibility:
		propagate_visibility(constructed_bones)

	return constructed_bones

func reset_inheritance(constructed_bones : Array, bones : Array):
	for b in range(bones.size()):
		constructed_bones[b].pos = bones[b].pos
		constructed_bones[b].rot = bones[b].rot
		constructed_bones[b].scale = bones[b].scale

func inheritance(bones: Array, ik_rots, armature_bones: Array):
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

# ---------- Mesh

func construct_verts(bones: Array, visuals: Array) -> void:
	var bone_map := {}
	for bone in bones:
		bone_map[bone.id] = bone

	for bone in bones:
		if bone.visuals_id == -1:
			continue

		var visual = visuals[bone.visuals_id]
		if visual.vertices.is_empty():
			continue

		for i in range(visual.vertices.size()):
			var v = visual.vertices[i]
			v.pos = v.initPos
			v.pos = inherit_vert(v.pos, bone)

		for bi in range(visual.binds.size()):
			var bind = visual.binds[bi]
			if bind.bone_id == -1:
				continue

			var bind_bone = bone_map.get(bind.bone_id)
			if bind_bone == null:
				continue

			for vert_info in bind.verts:
				if vert_info.id >= visual.vertices.size():
					continue

				var vert = visual.vertices[vert_info.id]
				if !bind.is_path:
					var end_pos = inherit_vert(vert.initPos, bind_bone)
					vert.pos += (end_pos - vert.pos) * vert_info.weight
					continue

				var prev = max(0, bi - 1)
				var next = min(visual.binds.size() - 1, bi + 1)
				var prev_bone = bone_map.get(visual.binds[prev].bone_id)
				var next_bone = bone_map.get(visual.binds[next].bone_id)

				if prev_bone == null or next_bone == null:
					continue

				var prev_dir = (bind_bone.pos - prev_bone.pos).normalized()
				var next_dir = (next_bone.pos - bind_bone.pos).normalized()
				var prev_norm = Vector2(-prev_dir.y, prev_dir.x)
				var next_norm = Vector2(-next_dir.y, next_dir.x)
				var avg = prev_norm + next_norm
				var norm_angle = atan2(avg.y, avg.x)
				var base = vert.initPos
				var rotated = rotate_vec2(base, norm_angle)
				var target = bind_bone.pos + rotated * vert_info.weight
				vert.pos = target

func inherit_vert(pos : Vector2, bone : Bone):
	pos = rotate_vec2(pos, bone.rot)
	pos += bone.pos
	return pos

func apply_constraints(chain: Array, family: Dictionary, root: Vector2, target: Vector2) -> void:
	if chain.size() < 2:
		return

	var joint_dir : Vector2 = (chain[1].pos - root).normalized()
	var base_dir : Vector2 = (target - root).normalized()
	var dir : float = joint_dir.x * base_dir.y - base_dir.x * joint_dir.y
	var base_angle := atan2(base_dir.y, base_dir.x)
	var cw: bool = family.constraint == "Clockwise" && dir > 0;
	var ccw: bool = family.constraint == "CounterClockwise" && dir < 0;

	if cw or ccw:
		for bone in chain:
			bone.rot = -bone.rot + base_angle * 2.0

# ---------- Physics

func simulate_physics(armature_bones : Array, constructed_bones: Array):
	var s = Vector2(0.3, 0.3)
	var e = Vector2(0.6, 0.6)
	
	for b in range(armature_bones.size()):
		var arm_bone: Bone = armature_bones[b]
		var const_bone: Bone = constructed_bones[b]
		
		if arm_bone.physics_id == -1:
			continue

		var prev_pos := arm_bone.phys_global_pos

		if arm_bone.phys_pos_damping > 0 || arm_bone.phys_sway > 0:
			var damping : Vector2 = Vector2(arm_bone.phys_pos_damping, arm_bone.phys_pos_damping)
			if arm_bone.phys_pos_ratio < 0:
				damping.y *= 1.0 - abs(arm_bone.phys_pos_ratio)
			elif arm_bone.phys_pos_ratio > 0:
				damping.x *= 1.0 - arm_bone.phys_pos_ratio
			
			arm_bone.phys_global_pos.x = interpolate(2, damping.x, arm_bone.phys_global_pos.x, const_bone.pos.x, s, e)
			arm_bone.phys_global_pos.y = interpolate(2, damping.y, arm_bone.phys_global_pos.y, const_bone.pos.y, s, e)

		if arm_bone.phys_scale_damping > 0:
			var damping : Vector2 = Vector2(arm_bone.phys_scale_damping, arm_bone.phys_scale_damping)
			if arm_bone.phys_scale_ratio < 0:
				damping.y *= 1.0 - abs(arm_bone.phys_scale_ratio)
			elif arm_bone.phys_scale_ratio > 0:
				damping.x *= 1.0 - arm_bone.phys_scale_ratio

			arm_bone.phys_global_scale.x = interpolate(2, damping.x, arm_bone.phys_global_scale.x, const_bone.scale.x, s, e)
			arm_bone.phys_global_scale.y = interpolate(2, damping.y, arm_bone.phys_global_scale.y, const_bone.scale.y, s, e)

		if arm_bone.phys_rot_damping > 0:
			var rot : float = shortest_angle_delta(arm_bone.phys_global_rot, const_bone.rot)
			arm_bone.phys_global_rot += rot / arm_bone.phys_rot_damping

		if arm_bone.phys_sway > 0 && const_bone.parent_id != -1:
			var parent: Bone = null
			for cb in constructed_bones:
				if cb.id == const_bone.parent_id:
					parent = cb
					break
					
			if parent != null:
				var diff : Vector2 = (const_bone.pos - parent.pos).normalized()
				var diff_angle : float = atan2(diff.y, diff.x)

				var orbit_buffer : float = shortest_angle_delta(arm_bone.phys_global_orbit, diff_angle)

				if arm_bone.phys_rot_bounce > 0.0 && arm_bone.phys_rot_bounce <= 1.0:
					orbit_buffer += arm_bone.phys_global_orbit_vel / (2.0 - arm_bone.phys_rot_bounce)
					arm_bone.phys_global_orbit_vel = orbit_buffer

				arm_bone.phys_global_orbit += orbit_buffer / 10.0

				var vel : Vector2 = (arm_bone.phys_global_pos - prev_pos)
				var angle : float = atan2(-vel.y, -vel.x)
				var vel_rot : float = shortest_angle_delta(arm_bone.phys_global_orbit, angle)
				var strength : float = (arm_bone.phys_global_pos - prev_pos).length() / 1000.0
				arm_bone.phys_global_orbit += vel_rot * strength * arm_bone.phys_sway

				arm_bone.phys_global_orbit_diff = diff_angle - arm_bone.phys_global_orbit

func inverse_kinematics(bones: Array, ik_families: Array, options: ConstructOptions) -> Dictionary:
	var ik_rots : Dictionary = {}

	var bone_map := {}
	for b in bones:
		bone_map[b.id] = b

	for family in ik_families:
		if family.target_id == -1:
			continue

		var root_bone = bone_map.get(int(family.bone_ids[0]))
		var target_bone = bone_map.get(family.target_id)

		if root_bone == null or target_bone == null:
			continue

		var family_bones: Array = []
		for id in family.bone_ids:
			var b = bone_map.get(int(id))
			if b != null:
				family_bones.append(b)

		if family_bones.is_empty():
			continue

		var root_pos: Vector2 = root_bone.pos
		var target_pos: Vector2 = target_bone.pos

		match family.mode:
			"FABRIK":
				if options != null:
					for i in range(options.fabrik_iterations):
							fabrik(family_bones, root_pos, target_pos)
				else:
					for i in range(10):
						fabrik(family_bones, root_pos, target_pos)
				
			"Arc":
				arc_ik(family_bones, root_pos, target_pos)

		point_bones(bones, family)
		apply_constraints(family_bones, family, root_pos, target_pos)

		for i in range(family_bones.size()):
			if i == family_bones.size() - 1:
				continue
			var bone = family_bones[i]
			ik_rots[bone.id] = bone.rot

	return ik_rots

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

# ---------- Interpolation

static func interpolate_value(current: int, max: int,start_val: float,end_val: float,start_handle: Vector2,end_handle: Vector2) -> float:
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

static func interpolate(current: int,  max: int,  start_val: float, end_val: float,  start_handle: Vector2, end_handle: Vector2) -> float:
	if(start_handle.y == 999.0 && end_handle.y == 999.0):
		return start_val;
	if(max == 0 || current >= max):
		return end_val;

	var initial := current / float(max)
	var t := initial
	for i in range(5):
		var x := cubic_bezier(t, start_handle.x, end_handle.x)
		var dx := cubic_bezier_derivative(t, start_handle.x, end_handle.x)
		if(abs(dx) < 1e-5):
			break
		t -= (x - initial) / dx
		t = clampf(t, 0.0, 1.0)

	var progress := cubic_bezier(t, start_handle.y, end_handle.y)
	return start_val + (end_val - start_val) * progress

static func cubic_bezier(t: float, p1: float, p2: float) -> float:
	var u = 1. - t
	return 3. * u * u * t * p1 + 3. * u * t * t * p2 + t * t * t

static func cubic_bezier_derivative(t: float, p1: float, p2: float) -> float:
	var u = 1. - t
	return 3. * u * u * p1 + 6. * u * t * (p2 - p1) + 3. * t * t * (1. - p2)

# ---------- Helpers

func check_bone_flip(bone: Bone, scale: Vector2):
	var either : bool = scale.x < 0 or scale.y < 0
	var both : bool = scale.x < 0 and scale.y < 0
	if either && !both:
		bone.rot = -bone.rot

func propagate_visibility(bones: Array):
	var by_id : Dictionary = {}

	for bone in bones:
		by_id[bone.id] = bone

	for bone in bones:
		var parent_id = bone.parent_id

		while parent_id != -1:
			var parent = by_id.get(parent_id)

			if parent == null:
				break

			if parent.hidden == 1.0:
				bone.hidden = 1.0
				break

			parent_id = parent.parent_id

func point_bones(bones: Array, family) -> void:
	var end_bone: Bone = bones[family.bone_ids[-1]]
	var tip_pos: Vector2 = end_bone.pos
	
	for i in range(family.bone_ids.size() - 1, -1, -1):
		var bone = bones[family.bone_ids[i]]
		if i == family.bone_ids.size() - 1:
			if family.mimic_target:
				bone.rot = bones[family.target_id].rot
			continue
		var dir: Vector2 = tip_pos - bone.pos
		bone.rot = atan2(dir.y, dir.x)
		tip_pos = bone.pos

static func rotate_vec2(point: Vector2, rot: float) -> Vector2:
	var c := cos(rot)
	var s := sin(rot)
	return Vector2(point.x * c - point.y * s,point.x * s + point.y * c)

static func shortest_angle_delta(from: float, to: float) -> float:
	var delta : float = to - from
	while delta > PI:
		delta -= TAU
	while delta < -PI:
		delta += TAU
	return delta

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

		var visib_init = bone_data.get('init_hidden', 0.0)
		b.init_hidden = visib_init

		b.ik_family_id = int(bone_data.get("family_id", -1))
		b.ik_mode = bone_data.get("mode", "FABRIK")
		b.ik_target_id = int(bone_data.get("target_id", -1))
		b.ik_constraint = bone_data.get("constraint", "None")

		b.ik_bone_ids = bone_data.get("bone_ids", []).duplicate(true)
		
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
		var ik = {
			"family_id": int(ik_data.get("family_id", -1)),
			"constraint": ik_data.get("constraint", "None"),
			"init_constraint": ik_data.get("init_constraint", ik_data.get("constraint", "None")),
			"mode": ik_data.get("mode", "FABRIK"),
			"init_mode": ik_data.get("init_mode", ik_data.get("mode", "FABRIK")),
			"target_id": int(ik_data.get("target_id", -1)),
			"bone_ids": ik_data.get("bone_ids", []).duplicate(true),
			"mimic_target": ik_data.get("mimic_target", false),
			"init_mimic_target": ik_data.get("init_mimic_target", ik_data.get("mimic_target", false)),
		}
		arm.inverse_kinematics.append(ik)
		if ik["bone_ids"].size() > 0:
			arm.ik_root_ids.append(ik["bone_ids"][0])

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

	if arm.inverse_kinematics.is_empty():
		var ik_idx := 0
		for b in bones:
			if b.ik_bone_ids.size() > 0:
				b.ik_family_id = ik_idx
				arm.inverse_kinematics.append({
					"constraint": b.ik_constraint,
					"init_constraint": b.ik_constraint,
					"mode": b.ik_mode,
					"init_mode": b.ik_mode,
					"target_id": b.ik_target_id,
					"bone_ids": b.ik_bone_ids.duplicate(true),
					"mimic_target": b.mimic_target,
					"init_mimic_target": b.init_mimic_target,
				})
				ik_idx += 1
	else:
		for b in bones:
			if b.inverse_kinematics_id != -1:
				b.ik_family_id = b.inverse_kinematics_id

	if arm.inverse_kinematics.is_empty():
		var ik_idx := 0
		for b in bones:
			if b.ik_bone_ids.size() > 0:
				b.ik_family_id = ik_idx
				arm.inverse_kinematics.append({
					"constraint": b.ik_constraint,
					"init_constraint": b.ik_constraint,
					"mode": b.ik_mode,
					"init_mode": b.ik_mode,
					"target_id": b.ik_target_id,
					"bone_ids": b.ik_bone_ids.duplicate(true),
					"mimic_target": b.mimic_target,
					"init_mimic_target": b.init_mimic_target,
				})
				ik_idx += 1

	arm.bones = bones.duplicate_deep(1)
	return arm
