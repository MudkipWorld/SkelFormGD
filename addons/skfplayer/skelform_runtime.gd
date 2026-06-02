@tool
extends Resource
class_name SkelformRuntime

# ---------- Classes

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
	
	var ik_bone_ids: Array
	var ik_mode: String
	var ik_constraint: String
	var ik_family_id: int
	var ik_target_id: int
	var init_rot: float
	var init_scale: Vector2
	var init_pos: Vector2
	
	var init_hidden : float
	
	var zindex: int = 0
	var tint : Color = Color.WHITE
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

func animate(bones: Array, anims: Array, frames: Array, smooth_frames: Array) -> void:
	for a in range(anims.size()):
		var frame = frames[a]
		var smooth = smooth_frames[a]

		for k in range(anims[a].keyframes.size()):
			var kf = anims[a].keyframes[k]

			if kf.frame > frame:
				break

			if kf.next_kf == -1:
				kf.next_kf = k

			var next_kf = anims[a].keyframes[kf.next_kf]

			var is_last = kf.next_kf == k
			var is_before_frame = next_kf.frame < frame

			if is_before_frame and !is_last:
				continue
			
			
			var bone = bones[kf.bone_id]
			interpolate_bone(bone, kf, next_kf, frame, smooth)

	reset_bones(bones, anims, frames[0], smooth_frames[0])

func interpolate_bone(bone: Bone, keyframe: Keyframe, nextKf: Keyframe ,frame: int, smooth_frame: int) -> void:
	if (keyframe.element == "PositionX"):
		bone.pos.x = interpolate_keyframes(bone.pos.x, keyframe, nextKf, frame, smooth_frame)
	if (keyframe.element == "PositionY"):
		bone.pos.y = interpolate_keyframes( bone.pos.y, keyframe, nextKf, frame, smooth_frame)
	if (keyframe.element == "Rotation"):
		bone.rot = interpolate_keyframes(bone.rot, keyframe, nextKf, frame, smooth_frame)
	if (keyframe.element == "ScaleX"):
		bone.scale.x = interpolate_keyframes( bone.scale.x, keyframe, nextKf, frame, smooth_frame)
	if (keyframe.element == "ScaleY"):
		bone.scale.y = interpolate_keyframes( bone.scale.y, keyframe, nextKf, frame, smooth_frame)
	if (keyframe.element == "TintR"):
		bone.tint.r = interpolate_keyframes( bone.tint.r, keyframe, nextKf, frame, smooth_frame)
	if (keyframe.element == "TintG"):
		bone.tint.g = interpolate_keyframes( bone.tint.g, keyframe, nextKf, frame, smooth_frame)
	if (keyframe.element == "TintB"):
		bone.tint.b = interpolate_keyframes(bone.tint.b, keyframe, nextKf, frame, smooth_frame)
	if (keyframe.element == "TintA"):
		bone.tint.a = interpolate_keyframes( bone.tint.a, keyframe, nextKf, frame, smooth_frame)
	
	# Will come back to later
	#bone.hidden = get_prev_keyframe_value(keyframes, bone_id, "Hidden", frame, bone.hidden)
	#bone.tex = get_prev_keyframe_value(keyframes, bone_id, "Texture", frame, bone.tex)
	#bone.ik_constraint = get_prev_keyframe_value(keyframes, bone_id, "IkConstraint", frame, bone.ik_constraint)

func interpolate_keyframes(field: float, prevKf: Keyframe, nextKf: Keyframe, frame: int, smoothFrame: int) -> float:
	var totalFrames = nextKf.frame - prevKf.frame
	var currentFrame = frame - prevKf.frame
	var result = interpolate( currentFrame, totalFrames,  prevKf.value,  nextKf.value,  nextKf.start_handle,  nextKf.end_handle )
	var z = Vector2(0,0)
	return interpolate(currentFrame, smoothFrame, field, result, z, z)

func reset_bones(bones, animations, frame, smoothFrame):
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
				bone.pos.x = lerp(bone.pos.x, bone.init_pos.x, 1.0)
			if "PositionY" not in reset:
				bone.pos.y = lerp(bone.pos.y, bone.init_pos.y, 1.0)
			if "Rotation" not in reset:
				bone.rot = lerp(bone.rot, bone.init_rot, 1.0)
			if "ScaleX" not in reset:
				bone.scale.x = lerp(bone.scale.x, bone.init_scale.x, 1.0)
			if "ScaleY" not in reset:
				bone.scale.y = lerp(bone.scale.y, bone.init_scale.y, 1.0)
			if "Hidden" not in reset:
				bone.hidden = bone.init_hidden
		
		else:
			bone.pos = bone.pos.lerp(bone.init_pos, 1.0)
			bone.rot = lerp(bone.rot, bone.init_rot, 1.0)
			bone.scale = bone.scale.lerp(bone.init_scale, 1.0)
			bone.hidden = bone.init_hidden

func construct(options: ConstructOptions, armature : Armature) -> Array:
	
	var constructed_bones : Array = []
	if armature.constructed_by_id.has(get_instance_id()):
		constructed_bones = armature.constructed_by_id[get_instance_id()]
	else:
		for bone in armature.bones:
			constructed_bones.append(bone.copy())
		armature.constructed_by_id[get_instance_id()] = constructed_bones
		
	constructed_bones.sort_custom(func(a: Bone, b: Bone) -> bool:return a.id < b.id)
		
	reset_inheritance(constructed_bones, armature.bones)
	inheritance(constructed_bones, {}, [])
	var ik_rots: Dictionary = inverse_kinematics(constructed_bones,armature.ik_root_ids,options)
	reset_inheritance(constructed_bones, armature.bones)
	inheritance(constructed_bones, ik_rots, [])

	simulate_physics(armature.bones,constructed_bones)

	reset_inheritance(constructed_bones, armature.bones)
	inheritance(constructed_bones,ik_rots,armature.bones)

	construct_verts(constructed_bones)

	for b in constructed_bones:
		b.pos.y = -b.pos.y
		b.rot = -b.rot

		b.scale *= options.scale
		b.pos *= options.scale
		b.pos += options.position

		check_bone_flip(b, options.scale)
		
		for v in b.vertices:
			v.pos.y = -v.pos.y
			v.pos *= options.scale
	
	if options.propagate_visibility:
		check_hidden(constructed_bones)

	return constructed_bones

func reset_inheritance(constructed_bones : Array, bones : Array):
	for b in range(bones.size()):
		constructed_bones[b].pos = bones[b].pos
		constructed_bones[b].rot = bones[b].rot
		constructed_bones[b].scale = bones[b].scale

func inheritance(bones: Array, ik_rots, armature_bones: Array) -> Array:
	for b in range(bones.size()):
		var bone = bones[b]
		if bone.parent_id != -1:
			var parent : Bone = null
			for l in bones:
				if l.id == bone.parent_id:
					parent = l
					break
					
			var orbit_rot = parent.rot
			if armature_bones.size() > 0 and armature_bones[b].phys_sway > 0.0:
				orbit_rot -= armature_bones[b].phys_global_orbit_diff

			bone.rot += orbit_rot
			bone.scale *= parent.scale
			bone.pos *= parent.scale
			bone.pos = bone.pos.rotated(parent.rot)
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
	
	return bones

# ---------- Mesh

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

func inherit_vert(pos : Vector2, bone : Bone):
	pos = pos.rotated(bone.rot)
	pos += bone.pos
	return pos

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

# ---------- Physics

func simulate_physics(armature_bones : Array, constructed_bones: Array):
	var parent_map: Dictionary = {}
	for b in constructed_bones:
		parent_map[b.id] = b
	
	for b in range(armature_bones.size()):
		var s : Vector2 = Vector2(0.3, 0.3)
		var e : Vector2 = Vector2(0.6, 0.6)
		var arm_bone: Bone = armature_bones[b]
		var const_bone: Bone = constructed_bones[b]
		var prev_pos := arm_bone.phys_global_pos

		#interpolate position
		if(arm_bone.phys_pos_damping > 0 || arm_bone.phys_sway > 0):
			var phys_pos : Vector2 = arm_bone.phys_global_pos
			var damping : Vector2 = Vector2(arm_bone.phys_pos_damping, arm_bone.phys_pos_damping)

			#ratio
			if(arm_bone.phys_pos_ratio < 0):
				damping.y *= 1.0 - abs(arm_bone.phys_pos_ratio)
			elif (arm_bone.phys_pos_ratio > 0):
				damping.x *= 1.0 - arm_bone.phys_pos_ratio
			
			var cb_scale := const_bone.scale
			phys_pos.x = interpolate(2, damping.x, phys_pos.x, const_bone.pos.x, s, e)
			phys_pos.y = interpolate(2, damping.y, phys_pos.y, const_bone.pos.y, s, e)

		#interpolate scale
		if(arm_bone.phys_scale_damping > 0):
			var phys_scale := arm_bone.phys_global_scale
			var damping : Vector2 = Vector2(arm_bone.phys_scale_damping, arm_bone.phys_scale_damping)

			#ratio
			if(arm_bone.phys_scale_ratio < 0):
				damping.y *= 1.0 - abs(arm_bone.phys_scale_ratio)
			elif(arm_bone.phys_pos_ratio > 0):
				damping.x *= 1.0 - arm_bone.phys_scale_ratio

			var cb_scale : Vector2 = const_bone.scale
			phys_scale.x = interpolate(2, damping.x, phys_scale.x, cb_scale.x, s, e)
			phys_scale.y = interpolate(2, damping.y, phys_scale.y, cb_scale.y, s, e)

		#interpolate rotation
		if(arm_bone.phys_rot_damping > 0):
			var rot : float = shortest_angle_delta(arm_bone.phys_global_rot, const_bone.rot)
			arm_bone.phys_global_rot += rot / arm_bone.phys_rot_damping

		#interpolate parent orbit (rot res, bounce, etc)
		var parent: Bone = parent_map.get(const_bone.parent_id)
				
		if(arm_bone.phys_sway > 0 && parent != null):
		   #1. get the raw orbit angle between this bone and its parent
			var diff := (const_bone.pos - parent.pos).normalized()
			var diff_angle := atan2(diff.y, diff.x)

			#2. interpolate current orbit angle to raw angle
			var orbit_buffer := shortest_angle_delta(arm_bone.phys_global_orbit, diff_angle)

			#3. apply bounce to orbit angle
			if(arm_bone.phys_rot_bounce > 0.0 && arm_bone.phys_rot_bounce <= 1.0):
				orbit_buffer += arm_bone.phys_global_orbit_vel / (2.0 - arm_bone.phys_rot_bounce)
				arm_bone.phys_global_orbit_vel = orbit_buffer
			

			#4. apply orbit buffer
			arm_bone.phys_global_orbit += orbit_buffer / 10.0

			#5. swing orbit based on position momentum
			var vel := (arm_bone.phys_global_pos - prev_pos).normalized()
			var angle := atan2(-vel.y, -vel.x)
			var vel_rot := shortest_angle_delta(arm_bone.phys_global_orbit, angle)
			var strength := (arm_bone.phys_global_pos - prev_pos).length() / 1000.0
			arm_bone.phys_global_orbit += vel_rot * strength * arm_bone.phys_sway

			#6. apply difference in raw angle and orbit
			arm_bone.phys_global_orbit_diff = diff_angle - arm_bone.phys_global_orbit

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

# ---------- Getters

func get_prev_keyframe_value(keyframes: Array, bone_id: int, element: String, frame: int, default_val) -> Variant:
	var prev = null
	for kf in keyframes:
		if kf.bone_id == bone_id and kf.element == element and kf.frame <= frame:
			prev = kf
			
	if element == "Texture":
		return prev.value_str if prev != null else default_val
	return prev.value if prev != null else default_val

# ---------- Interpolation

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

func interpolate(current: int,  max: int,  start_val: float, end_val: float,  start_handle: Vector2, end_handle: Vector2) -> float:
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

func cubic_bezier(t: float, p1: float, p2: float) -> float:
	var u = 1. - t
	return 3. * u * u * t * p1 + 3. * u * t * t * p2 + t * t * t

func cubic_bezier_derivative(t: float, p1: float, p2: float) -> float:
	var u = 1. - t
	return 3. * u * u * p1 + 6. * u * t * (p2 - p1) + 3. * t * t * (1. - p2)

# ---------- Helpers

func shortest_angle_delta(from: float, to: float) -> float:
	var delta : float = to - from
	while delta > PI:
		delta -= TAU
	while delta < -PI:
		delta += TAU
	return delta

func check_bone_flip(bone: Bone, scale: Vector2):
	var either : bool = scale.x < 0 or scale.y < 0
	var both : bool = scale.x < 0 and scale.y < 0
	if either && !both:
		bone.rot = -bone.rot

func check_hidden(bones: Array):
	var map : Dictionary[int, Bone] = {}
	for i in range(bones.size()):
		if bones[i].hidden == 1.0:
			map[bones[i].id] = bones[i]

	for i in range(bones.size()):
		if bones[i].parent_id != -1 && map.get(bones[i].parent_id, null) != null:
			bones[i].hidden = map[bones[i].parent_id].hidden

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
		
		var visib = bone_data.get('hidden', 0.0)
		b.hidden = visib

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
		
	arm.bones = bones.duplicate_deep(1)
	return arm
