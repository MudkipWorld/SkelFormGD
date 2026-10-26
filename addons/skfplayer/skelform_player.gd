@tool
@icon("res://addons/skfplayer/Resources/node_icon.png")
extends Node2D
class_name SkelFormPlayer

signal animation_finished
var anim_finished_once : bool = false

var runtime : SkelformRuntime = SkelformRuntime.new()
var armature : SkelformRuntime.Armature
var constructed_bones: Array = []
var current_frame: int = 0
var anim_length: int = 0
var img_atlas  : Array = []
var text_atlases : Array = []
var time_accum : float = 0.0
var prev_frame : int = 0
var frame_skip_count : int = 0
var opts : SkelformRuntime.ConstructOptions = SkelformRuntime.ConstructOptions.new()

@export_category("Setup")

@export_tool_button("Reload Model") var reload_action = reload_model

@export var file: String : 
	set(new_file):
		if new_file != file:
			load_model_from_file(new_file)
			file = new_file

@export var model_scale : Vector2 = Vector2(0.15, 0.15) : 
	set(new_scale):
		model_scale = new_scale
		opts.scale = new_scale
		init_animate()
 
@export var model_position : Vector2 = Vector2(0, 0) : 
	set(new_position):
		model_position = new_position
		opts.position = new_position
		init_animate()

@export var model_styles : Dictionary[String, SKFStylesRes] 

@export_category("Animation")

@export var auto_play : bool = false

@export var playing : bool = false : 
	set(is_playing):
		set_physics_process(is_playing)
		playing = is_playing

@export var looping : bool

@export var animations : Dictionary[String, SkelformAnimationRes] 

@export var frame_skip: int = 2

@export_category("Debug")

@export var smoothing : int = 0

@export_range(1, 50) var fabrik_iterations : int = 10 :
	set(new_it):
		fabrik_iterations = new_it
		opts.fabrik_iterations = new_it

@export var propagate_visibility :  bool = false:
	set(new_pv):
		propagate_visibility = new_pv
		opts.propagate_visibility = new_pv

#--- Basic player setup

func _ready():
	if file.is_empty():
		return

	opts.scale = model_scale
	opts.position = model_position
	opts.fabrik_iterations = fabrik_iterations
	opts.propagate_visibility = propagate_visibility

	init_animate()
	
	set_physics_process(playing)

func reload_model():
	load_model_from_file(file)

func load_model_from_file(filename : String = ""):
	if !FileAccess.file_exists(filename):
		printerr("File doesn't exist..")
		return
	
	var dict = runtime.load_armature_from_file(filename, opts)
	armature = dict.arm
	img_atlas = dict.img_at
	
	if !img_atlas.is_empty():
		for img in img_atlas:
			text_atlases.append(ImageTexture.create_from_image(img))
	
	if !armature:
		return
	
	for i in armature.animations:
		var anim_res : SkelformAnimationRes = SkelformAnimationRes.new()
		anim_res.resource_local_to_scene = true
		anim_res.anim_name = i.name
		anim_res.fps = i.fps
		animations[i.name] = anim_res

	if file != filename:
		model_styles.clear()
		for st in armature.styles:
			var new_res : SKFStylesRes = SKFStylesRes.new()
			new_res.resource_local_to_scene = true
			new_res.style_name = st.name
			for i in st.textures:
				new_res.textures.append(i.name)
			model_styles[st.name] = new_res
	set_physics_process(playing)
	init_animate()

#--- Animating

func _physics_process(delta: float) -> void:
	animate(delta)

func init_animate():
	frame_skip_count += 1
	var arm_exists : bool = !armature or armature.animations.is_empty()
	var anim = get_animation_data(animations.values()[0].anim_name)
	anim_length = anim.keyframes[-1].frame + 1
	if anim_length == 0: return
	if auto_play && !OS.has_feature("editor_hint"):
		playing = true
	current_frame = 0
	runtime.animate(armature, [anim], [current_frame], [smoothing])
	constructed_bones = runtime.construct(opts, armature, 0.16)
	queue_redraw()
	prev_frame = current_frame
	frame_skip_count = 0

func animate(delta : float):
	if !is_visible_in_tree() : return
	frame_skip_count += 1
	var arm_exists : bool = armature != null && is_instance_valid(armature)

	if !arm_exists: return
	
	for an in animations.values():
		if an.playing:
			var anim = get_animation_data(an.anim_name)
			anim_length = anim.keyframes[-1].frame + 1
			time_accum += delta

			if anim_length == 0: return
			if (current_frame > (anim_length - frame_skip)):
				if !anim_finished_once:
					animation_finished.emit(an.anim_name)
					
				if !looping:
					return

			current_frame = int(time_accum * an.fps) % anim_length
			
			if prev_frame == current_frame: return
			if frame_skip_count < frame_skip: return

			runtime.animate(armature, [anim], [current_frame], [smoothing])
			constructed_bones = runtime.construct(opts, armature, delta)
			queue_redraw()
			prev_frame = current_frame
			frame_skip_count = 0

func get_animation_data(anim_name : String) -> SkelformRuntime.AnimationData:
	for i in armature.animations:
		if i.name == anim_name:
			return i
	return null

#--- Drawing functions

func _draw() -> void:
	if constructed_bones.is_empty():
		return
	draw_skeleton(constructed_bones, armature.visuals, text_atlases, armature.styles)

func draw_skeleton(bones: Array, visuals: Array, atlases: Array, styles: Array) -> void:
	if bones.is_empty():
		return

	var order : Dictionary = {}
	for i in bones.size():
		order[bones[i]] = i

	bones.sort_custom(func(a, b):
		var a_id: int = a.visuals_id
		var b_id: int = b.visuals_id
		var a_z : int = 0
		var b_z : int = 0
		if a_id >= 0 and a_id < visuals.size():
			a_z = visuals[a_id].zindex
		if b_id >= 0 and b_id < visuals.size():
			b_z = visuals[b_id].zindex
		if a_z != b_z:
			return a_z < b_z
		return order[a] < order[b]
	)

	var drawn_visuals : Dictionary = {}

	for bone : SkelformRuntime.Bone in bones:
		if bone.visuals_id == -1:
			continue
		if bone.hidden:
			continue

		var visual : SkelformRuntime.Visual = visuals[bone.visuals_id]
		var tex = get_bone_texture(visual.tex, styles)
		if tex == null:
			continue

		var atlas_idx = tex.atlas_idx
		if atlas_idx < 0 or atlas_idx >= atlases.size():
			continue

		var atlas = atlases[atlas_idx]
		if atlas == null:
			continue

		var key := Vector2i(visual.zindex, atlas_idx)
		if !drawn_visuals.has(key):
			drawn_visuals[key] = {
				verts = PackedVector2Array(),
				uvs = PackedVector2Array(),
				colors = PackedColorArray(),
				indices = PackedInt32Array(),
			}

		var drawn = drawn_visuals[key]
		if visual.vertices.is_empty():
			create_sprite(drawn, bone, visual, tex, atlas)
		else:
			create_mesh(drawn, bone, visual, tex, atlas)

	var keys = drawn_visuals.keys()
	keys.sort_custom(func(a, b):
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)

	for key in keys:
		var drawn = drawn_visuals[key]
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(),
			drawn.indices,
			drawn.verts,
			drawn.colors,
			drawn.uvs,
			PackedInt32Array(),
			PackedFloat32Array(),
			atlases[key.y].get_rid()
		)

func create_sprite(drawn: Dictionary, bone, visual, tex, atlas: Texture2D) -> void:
	var start = drawn.verts.size()

	var dir := -1.0 if bone.scale.x < 0.0 else 1.0

	var final_rot = bone.rot - visual.pivot_rot * dir
	var final_scale = bone.scale * visual.pivot_scale
	
	var pivot = visual.pivot_pos * tex.size
	pivot = SkelformUtils.rotate_vec2(pivot, -visual.pivot_rot * dir)
	pivot *= final_scale
	pivot.y = -pivot.y
	
	var center = bone.pos
	var half = tex.size * bone.scale * 0.5

	var c : float = cos(final_rot)
	var s : float = sin(final_rot)

	drawn.verts.append(transform_point(Vector2(-half.x, -half.y) + pivot, center, c, s))
	drawn.verts.append(transform_point(Vector2( half.x, -half.y) + pivot, center, c, s))
	drawn.verts.append(transform_point(Vector2( half.x,  half.y) + pivot, center, c, s))
	drawn.verts.append(transform_point(Vector2(-half.x,  half.y) + pivot, center, c, s))

	drawn.colors.append_array([
		visual.tint,
		visual.tint,
		visual.tint,
		visual.tint,
	])

	var atlas_size := Vector2(atlas.get_width(), atlas.get_height())

	drawn.uvs.append(tex.offset / atlas_size)
	drawn.uvs.append((tex.offset + Vector2(tex.size.x, 0.0)) / atlas_size)
	drawn.uvs.append((tex.offset + tex.size) / atlas_size)
	drawn.uvs.append((tex.offset + Vector2(0.0, tex.size.y)) / atlas_size)

	drawn.indices.append_array([
		start + 0, start + 1, start + 2,
		start + 0, start + 2, start + 3,
	])

func create_mesh(drawn: Dictionary, bone, visual, tex, atlas: Texture2D) -> void:
	var start = drawn.verts.size()

	var atlas_size := Vector2(atlas.get_width(), atlas.get_height())
	var uv_offset = tex.offset / atlas_size
	var uv_scale = tex.size / atlas_size

	for vert in visual.vertices:
		drawn.verts.append(vert.pos)
		drawn.uvs.append(uv_offset + vert.uv * uv_scale)
		drawn.colors.append(visual.tint)

	var src: PackedInt32Array = visual.indices
	if src.is_empty():
		src = PackedInt32Array(visual.triangles)

	for idx in src:
		drawn.indices.append(start + idx)

func transform_point(p: Vector2, pos: Vector2, cos_r: float, sin_r: float) -> Vector2:
	return Vector2(p.x * cos_r - p.y * sin_r, p.x * sin_r + p.y * cos_r) + pos

func get_bone_texture(tex_name: String, styles: Array):
	var visible_style_names = []

	for style_name in model_styles:
		var res: SKFStylesRes = model_styles[style_name]
		if res and res.visible:
			visible_style_names.append(res.style_name)

	for style in styles:
		if style.name not in visible_style_names:
			continue

		for tex in style.textures:
			if tex.name == tex_name:
				return tex

	return null

#--- Sets and gets for bones and animations for more control

func get_animation_names(working_only : bool = false) -> PackedStringArray:
	var arr : PackedStringArray = []
	for i in animations.keys():
		if working_only :
			if animations[i].playing:
				arr.append(i)
		else:
			arr.append(i)
	return arr

func disable_all_animation():
	anim_finished_once = false
	current_frame = 0
	prev_frame = 0
	time_accum = 0
	for i in animations.keys():
		animations[i].playing = false

func set_animation(anim : String, play : bool):
	anim_finished_once = false
	current_frame = 0
	prev_frame = 0
	time_accum = 0
	animations[anim].playing = play

func set_animations(anims : PackedStringArray, play : bool):
	anim_finished_once = false
	current_frame = 0
	prev_frame = 0
	time_accum = 0
	for i in anims:
		animations[i].playing = play

func get_bone_names() -> PackedStringArray:
	var arr : PackedStringArray = []
	for i in armature.bones:
		arr.append(i.name)
	return arr

func set_bones_data(bones : PackedStringArray, data_anme : String, data : Variant):
	if armature.constructed_by_id.has(runtime.get_instance_id()):
		var c_b = armature.constructed_by_id[runtime.get_instance_id()]
		for i in bones:
			for l in c_b:
				if i == l.name:
					l.set(data_anme, data)
					continue

func get_bone(bone : String) -> SkelformRuntime.Bone:
	for l in armature.bones:
		if bone == l.name:
			return l
	return null

func get_bone_data(bone : SkelformRuntime.Bone, data_name : String) -> Variant:
	return bone.get(data_name)

func get_all_bone_data(bone : SkelformRuntime.Bone) -> Dictionary:
	var data : Dictionary = {}
	data['name'] = bone.name
	data['id'] = bone.id
	data['ik_family'] = bone.ik_family_id
	data['ik_ids'] = bone.ik_bone_ids
	data['binds'] = bone.binds
	data['tint'] = bone.tint
	data['visible'] = bone.visible
	data['parent_id'] = bone.parent_id
	data['texture'] = bone.tex
	data['z_index'] = bone.zindex
	return data
