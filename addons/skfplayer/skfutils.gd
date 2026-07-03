extends RefCounted
class_name SkelformUtils

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

static func check_bone_flip(bone: SkelformRuntime.Bone, scale: Vector2):
	var either : bool = scale.x < 0 or scale.y < 0
	var both : bool = scale.x < 0 and scale.y < 0
	if either && !both:
		bone.rot = -bone.rot

static func propagate_visibility(bones: Array):
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

static func point_bones(bones: Array, family) -> void:
	var end_bone: SkelformRuntime.Bone = bones[family.bone_ids[-1]]
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
