extends RefCounted
class_name SkelformPhysics

# ---------- Mesh

static func construct_verts(bones: Array, visuals: Array) -> void:
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
				var rotated = SkelformUtils.rotate_vec2(base, norm_angle)
				var target = bind_bone.pos + rotated * vert_info.weight
				vert.pos = target

static func inherit_vert(pos : Vector2, bone : SkelformRuntime.Bone):
	pos = SkelformUtils.rotate_vec2(pos, bone.rot)
	pos += bone.pos
	return pos

static func apply_constraints(chain: Array, family: SkelformRuntime.InverseKinematics, root: Vector2, target: Vector2) -> void:
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

static func simulate_physics(armature_bones : Array, constructed_bones: Array):
	var s = Vector2(0.3, 0.3)
	var e = Vector2(0.6, 0.6)
	
	for b in range(armature_bones.size()):
		var arm_bone: SkelformRuntime.Bone = armature_bones[b]
		var const_bone: SkelformRuntime.Bone = constructed_bones[b]
		
		if arm_bone.physics_id == -1:
			continue

		var prev_pos := arm_bone.phys_global_pos

		if arm_bone.phys_pos_damping > 0 || arm_bone.phys_sway > 0:
			var damping : Vector2 = Vector2(arm_bone.phys_pos_damping, arm_bone.phys_pos_damping)
			if arm_bone.phys_pos_ratio < 0:
				damping.y *= 1.0 - abs(arm_bone.phys_pos_ratio)
			elif arm_bone.phys_pos_ratio > 0:
				damping.x *= 1.0 - arm_bone.phys_pos_ratio
			
			arm_bone.phys_global_pos.x = SkelformUtils.interpolate(2, damping.x, arm_bone.phys_global_pos.x, const_bone.pos.x, s, e)
			arm_bone.phys_global_pos.y = SkelformUtils.interpolate(2, damping.y, arm_bone.phys_global_pos.y, const_bone.pos.y, s, e)

		if arm_bone.phys_scale_damping > 0:
			var damping : Vector2 = Vector2(arm_bone.phys_scale_damping, arm_bone.phys_scale_damping)
			if arm_bone.phys_scale_ratio < 0:
				damping.y *= 1.0 - abs(arm_bone.phys_scale_ratio)
			elif arm_bone.phys_scale_ratio > 0:
				damping.x *= 1.0 - arm_bone.phys_scale_ratio

			arm_bone.phys_global_scale.x = SkelformUtils.interpolate(2, damping.x, arm_bone.phys_global_scale.x, const_bone.scale.x, s, e)
			arm_bone.phys_global_scale.y = SkelformUtils.interpolate(2, damping.y, arm_bone.phys_global_scale.y, const_bone.scale.y, s, e)

		if arm_bone.phys_rot_damping > 0:
			var rot : float = SkelformUtils.shortest_angle_delta(arm_bone.phys_global_rot, const_bone.rot)
			arm_bone.phys_global_rot += rot / arm_bone.phys_rot_damping

		if arm_bone.phys_sway > 0 && const_bone.parent_id != -1:
			var parent: SkelformRuntime.Bone = null
			for cb in constructed_bones:
				if cb.id == const_bone.parent_id:
					parent = cb
					break
					
			if parent != null:
				var diff : Vector2 = (const_bone.pos - parent.pos).normalized()
				var diff_angle : float = atan2(diff.y, diff.x)

				var orbit_buffer : float = SkelformUtils.shortest_angle_delta(arm_bone.phys_global_orbit, diff_angle)

				if arm_bone.phys_rot_bounce > 0.0 && arm_bone.phys_rot_bounce <= 1.0:
					orbit_buffer += arm_bone.phys_global_orbit_vel / (2.0 - arm_bone.phys_rot_bounce)
					arm_bone.phys_global_orbit_vel = orbit_buffer

				arm_bone.phys_global_orbit += orbit_buffer / 10.0

				var vel : Vector2 = (arm_bone.phys_global_pos - prev_pos)
				var angle : float = atan2(-vel.y, -vel.x)
				var vel_rot : float = SkelformUtils.shortest_angle_delta(arm_bone.phys_global_orbit, angle)
				var strength : float = (arm_bone.phys_global_pos - prev_pos).length() / 1000.0
				arm_bone.phys_global_orbit += vel_rot * strength * arm_bone.phys_sway

				arm_bone.phys_global_orbit_diff = diff_angle - arm_bone.phys_global_orbit

static func inverse_kinematics(bones: Array, ik_families: Array, options: SkelformRuntime.ConstructOptions) -> Dictionary:
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

		SkelformUtils.point_bones(bones, family)
		apply_constraints(family_bones, family, root_pos, target_pos)

		for i in range(family_bones.size()):
			if i == family_bones.size() - 1:
				continue
			var bone = family_bones[i]
			ik_rots[bone.id] = bone.rot

	return ik_rots

static func fabrik(chain: Array, root: Vector2, target: Vector2) -> void:
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

static func arc_ik(chain: Array, root: Vector2, target: Vector2) -> void:
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
