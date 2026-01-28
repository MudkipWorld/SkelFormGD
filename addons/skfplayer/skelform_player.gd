@tool
@icon("res://addons/skfplayer/Resources/node_icon.png")
extends Node2D
class_name SkelFormPlayer

var backend := SkelformBackend.new()
var armature : SkelformBackend.Armature
var solved_bones: Array = []
var current_frame: int = 0
var anim_length: int = 0
var img_atlas  : Array = []
var text_atlases : Array = []
var time_accum : float = 0.0
var prev_frame : int = 0
var frame_skip_count : int = 0

var opts : SkelformBackend.ConstructOptions = SkelformBackend.ConstructOptions.new()

@export var file: String : 
	set(new_file):
		load_model_from_file(new_file)
		file = new_file

@export var auto_play : bool = false
@export var playing : bool = false : 
	set(is_playing):
		set_physics_process(is_playing)
		playing = is_playing

@export var looping : bool
@export_range(1, 120) var fps: int = 24
@export var frame_skip: int = 2
@export var animation_index : int = 0 :
	set(index):
		if !looping:
			current_frame = 0
		animation_index = index
		queue_redraw()

@export var model_scale : Vector2 = Vector2(0.15, 0.15) : 
	set(new_scale):
		model_scale = new_scale
		opts.scale = new_scale
		init_animate()
 
@export var model_position : Vector2 = Vector2(0, 0) : 
	set(new_position):
		model_position = new_position
		opts.model_position = new_position
		init_animate()

@export_range(1, 50) var fabrik_iterations : int = 10 :
	set(new_it):
		fabrik_iterations = new_it
		opts.fabrik_iterations = new_it

@export var model_style: int = 0:
	set(new_style):
		if armature == null:
			return
		if new_style < 0 or new_style >= armature.styles.size():
			return
		model_style = new_style
		bone_texture_results = setup_bone_textures(solved_bones, armature.styles)
		queue_redraw()

@export var debug : bool = false : 
	set(is_debug):
		debug = is_debug
		queue_redraw()

@export var baked_model : bool :
	set(baked):
		if baked:
			if armature:
				backend.bake_animations(armature)
		else:
			if armature:
				for i in armature.animations:
					i.cached_frames.clear()
					i.cached_solved_frames.clear()
		
		baked_model = baked

var bone_texture_results : Dictionary = {}


func _ready():
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	if file.is_empty():
		return

	opts.scale = model_scale
	opts.position = model_position
	opts.fabrik_iterations = fabrik_iterations
	
	load_model_from_file(file)
	
	if !OS.has_feature("editor"):
		if auto_play: 
			playing = true
		else:
			playing = false
		set_physics_process(playing)

func load_model_from_file(filename : String = ""):
	if !FileAccess.file_exists(filename):
		printerr("File doesn't exist..")
		return
	var dict = backend.load_armature_from_file(filename, baked_model)
	armature = dict.arm
	img_atlas = dict.img_at
	
	if !img_atlas.is_empty():
		for img in img_atlas:
			text_atlases.append(ImageTexture.create_from_image(img))
	
	if !armature:
		return
		
	if armature.animations.size() > animation_index:
		var anim = armature.animations[animation_index]
		if anim.keyframes.size() > 0:
			anim_length = anim.keyframes[-1].frame + 1
		else:
			anim_length = 0
	else:
		anim_length = 0
	bone_texture_results.clear()
	bone_texture_results = setup_bone_textures(solved_bones, armature.styles)
	set_physics_process(playing)
	init_animate()

func _physics_process(delta: float) -> void:
	animate(delta)

func init_animate():
	frame_skip_count += 1
	var arm_exists : bool = !armature or armature.animations.is_empty()
	var animate_index_out_of_bounds : bool = animation_index < 0 or animation_index >= armature.animations.size()
	if arm_exists or animate_index_out_of_bounds: return
	var anim = armature.animations[animation_index]
	anim_length = anim.keyframes[-1].frame + 1
	if anim_length == 0: return
	current_frame = 0
	if baked_model:
		backend.animate_cached(armature.bones, [anim], [current_frame], [1])
		solved_bones = backend.construct_baked(anim, current_frame, opts)
	else:
		backend.animate(armature.bones, [anim], [current_frame], [1])
		solved_bones = backend.construct(armature, opts)
	queue_redraw()
	prev_frame = current_frame
	frame_skip_count = 0

func animate(delta : float = 0.1):
	frame_skip_count += 1
	var arm_exists : bool = !armature or armature.animations.is_empty()
	var animate_index_out_of_bounds : bool = animation_index < 0 or animation_index >= armature.animations.size()
	
	if arm_exists or animate_index_out_of_bounds: return

	var anim = armature.animations[animation_index]
	anim_length = anim.keyframes[-1].frame + 1
	time_accum += delta

	if anim_length == 0: return
	if (current_frame > (anim_length -frame_skip)) && !looping: return

	current_frame = int(time_accum * fps) % anim_length
	
	if prev_frame == current_frame: return
	if frame_skip_count < frame_skip: return

	if baked_model:
		backend.animate_cached(armature.bones, [anim], [current_frame], [1])
		solved_bones = backend.construct_baked(anim, current_frame, opts)
	else:
		backend.animate(armature.bones, [anim], [current_frame], [1])
		solved_bones = backend.construct(armature, opts)
	queue_redraw()
	prev_frame = current_frame
	frame_skip_count = 0

func _draw() -> void:
	if solved_bones.is_empty():
		return
	draw_skeleton(solved_bones,armature.styles,text_atlases )

func draw_skeleton(bones: Array, styles: Array, atlases: Array) -> void:
	if bones.is_empty():
		return
	
	var order : Dictionary = {}
	for i in bones.size():
		order[bones[i]] = i
	
	bones.sort_custom(func(a, b):
		if a.zindex != b.zindex:
			return a.zindex < b.zindex
		return order[a] < order[b])

	var final_textures = setup_bone_textures(solved_bones, armature.styles)
	
	for b in bones:
		if not final_textures.has(b.id):
			continue
		var tex: SkelformBackend.TextureData = final_textures[b.id]
		var atlas: Texture2D = atlases[tex.atlas_idx]
		if atlas == null:
			continue
		if !b.vertices.is_empty():
			var region : Rect2 = Rect2(tex.offset, tex.size)
			draw_bone_mesh(b, atlas, region)
		else:
			var region : Rect2 = Rect2(tex.offset, tex.size)
			var size = tex.size * b.scale
			var push_center = abs(size) * 0.5
			draw_set_transform(b.pos, b.rot, Vector2.ONE)
			draw_set_transform(b.pos, b.rot, Vector2.ONE)
			draw_texture_rect_region(atlas, Rect2(-push_center, size), region)

			if debug:
				var rect := Rect2(-push_center, size)

				var p0 = rect.position
				var p1 = rect.position + Vector2(rect.size.x, 0)
				var p2 = rect.position + rect.size
				var p3 = rect.position + Vector2(0, rect.size.y)

				draw_line(p0, p1, Color.BLUE, 2.0)
				draw_line(p1, p2, Color.BLUE, 2.0)
				draw_line(p2, p3, Color.BLUE, 2.0)
				draw_line(p3, p0, Color.BLUE, 2.0)

			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_bone_mesh(bone, atlas: Texture2D, region: Rect2) -> void:
	if atlas == null or bone.vertices.is_empty():
		return
	var indices_data = bone.indices if bone.indices.size() > 0 else bone.triangles
	if indices_data.is_empty():
		return
	var verts = PackedVector2Array()
	var uvs = PackedVector2Array()
	var colors = PackedColorArray()
	var atlas_size := Vector2(atlas.get_width(), atlas.get_height())
	var uv_offset : Vector2 = region.position / atlas_size
	var uv_scale : Vector2 = region.size / atlas_size
	for v in bone.vertices:
		verts.append(v.pos)
		var final_uv = uv_offset + (v.uv * uv_scale)
		uvs.append(final_uv)
		colors.append(Color.WHITE)
		if debug:
			draw_circle(v.pos, 2, Color.RED)
	var indices_array = PackedInt32Array(indices_data)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),indices_array,verts,colors,uvs,PackedInt32Array(),  PackedFloat32Array(), atlas.get_rid())
	
	if debug:
		var edges : Dictionary = {}
		for i in range(0, indices_array.size(), 3):
			var tri = [indices_array[i],indices_array[i + 1],indices_array[i + 2]]
			for j in 3:
				var a = min(tri[j], tri[(j + 1) % 3])
				var b = max(tri[j], tri[(j + 1) % 3])
				var key = Vector2i(a, b)
				edges[key] = edges.get(key, 0) + 1
		for key in edges:
			if edges[key] == 1:
				draw_line(verts[key.x],verts[key.y],Color(0, 1, 0, 0.5),2.0)

func setup_bone_textures(bones: Array, styles: Array) -> Dictionary:
	var result: Dictionary = {}
	if armature == null or styles.is_empty():
		return result
		
	var style = styles[model_style]
	for b in bones:
		for tex in style.textures:
			if tex.name == b.tex:
				result[b.id] = tex
				break
		if result.has(b.id):
			continue
		if !result.has(b.id):
			for s in styles:
				for tex in s.textures:
					if tex.name == b.tex:
						result[b.id] = tex
						break
	return result
