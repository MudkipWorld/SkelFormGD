@tool
@icon("res://addons/skfplayer/Resources/node_icon.png")
extends Node2D
class_name SkelFormPlayer

var draw_batches : Dictionary = {}

class DrawBatch:
	var verts : PackedVector2Array = PackedVector2Array()
	var uvs : PackedVector2Array = PackedVector2Array()
	var colors : PackedColorArray = PackedColorArray()
	var indices : PackedInt32Array = PackedInt32Array()

	func clear():
		verts.clear()
		uvs.clear()
		colors.clear()
		indices.clear()

var backend : SkelformBackend = SkelformBackend.new()
var armature : SkelformBackend.Armature
var cached_bones: Array = []
var current_frame: int = 0
var anim_length: int = 0
var img_atlas  : Array = []
var text_atlases : Array = []
var time_accum : float = 0.0
var prev_frame : int = 0
var frame_skip_count : int = 0
var opts : SkelformBackend.ConstructOptions = SkelformBackend.ConstructOptions.new()

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

@export var animation_index : int = 0 :
	set(index):
		if !looping:
			current_frame = 0
		animation_index = index
		#queue_redraw()

@export_range(1, 120) var fps: int = 24

@export var frame_skip: int = 2

@export_category("Debug")

@export var debug : bool = false : 
	set(is_debug):
		debug = is_debug
		queue_redraw()

@export var smoothing : int = 1

@export_range(1, 50) var fabrik_iterations : int = 10 :
	set(new_it):
		fabrik_iterations = new_it
		opts.fabrik_iterations = new_it

func _ready():
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	if file.is_empty():
		return

	opts.scale = model_scale
	opts.position = model_position
	opts.fabrik_iterations = fabrik_iterations

	if !OS.has_feature("editor"):
		if auto_play: 
			playing = true
		else:
			playing = false
	
	set_physics_process(playing)

func reload_model():
	load_model_from_file(file)

func load_model_from_file(filename : String = ""):
	if !FileAccess.file_exists(filename):
		printerr("File doesn't exist..")
		return
	var dict = backend.load_armature_from_file(filename, true, opts)
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
	
	if file != filename:
		model_styles.clear()
		for st in armature.styles:
			var new_res : SKFStylesRes = SKFStylesRes.new()
			new_res.style_name = st.name
			for i in st.textures:
				new_res.textures.append(i.name)
			model_styles[st.name] = new_res
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
	if auto_play && !OS.has_feature("editor_hint"):
		playing = true
	current_frame = 0
	backend.animate_cached(armature.bones, [anim], [current_frame], [smoothing])
	cached_bones = backend.construct_cached(anim, current_frame, opts)
	queue_redraw()
	prev_frame = current_frame
	frame_skip_count = 0

func animate(delta : float = 0.1):
	if !is_visible_in_tree() : return
	frame_skip_count += 1
	var arm_exists : bool = !armature or armature.animations.is_empty()

	if arm_exists: return

	var anim = armature.animations[animation_index]
	anim_length = anim.keyframes[-1].frame + 1
	time_accum += delta

	if anim_length == 0: return
	if (current_frame > (anim_length -frame_skip)) && !looping: return

	current_frame = int(time_accum * fps) % anim_length
	
	if prev_frame == current_frame: return
	if frame_skip_count < frame_skip: return

	backend.animate_cached(armature.bones, [anim], [current_frame], [smoothing])
	cached_bones = backend.construct_cached(anim, current_frame, opts)
	queue_redraw()
	prev_frame = current_frame
	frame_skip_count = 0

func _draw() -> void:
	if cached_bones.is_empty():
		return
		
	draw_batches.clear()
	draw_skeleton(cached_bones, armature.styles, text_atlases)
	
	for rid in draw_batches:
		var batch : DrawBatch = draw_batches[rid]
		if batch.indices.size() == 0:
			continue
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),batch.indices,batch.verts,batch.colors,batch.uvs,PackedInt32Array(),PackedFloat32Array(),rid)

func draw_skeleton(bones: Array, styles: Array, atlases: Array) -> void:
	if bones.is_empty():
		return
		
	var order : Dictionary = {}
	for i in bones.size():
		order[bones[i]] = i

	bones.sort_custom(func(a,b):
		if a.zindex != b.zindex:
			return a.zindex < b.zindex
		return order[a] < order[b]
	)
	var final_textures : Dictionary = setup_bone_textures(bones, styles)
	
	for b in bones:
		if !final_textures.has(b.id):
			continue
			
		var tex: SkelformBackend.TextureData = final_textures[b.id]
		var atlas: Texture2D = atlases[tex.atlas_idx]
		if atlas == null:
			continue
			
		if b.visible == 1.0:
			continue
			
		if !b.vertices.is_empty():
			var region : Rect2 = Rect2(tex.offset, tex.size)
			batch_mesh(b, atlas, region)
		else:
			batch_sprite(b, atlas, tex)

func batch_mesh(bone, atlas: Texture2D, region: Rect2):
	var batch = get_batch(atlas.get_rid())
	var base = batch.verts.size()
	var atlas_size = Vector2(atlas.get_width(), atlas.get_height())
	var uv_offset = region.position / atlas_size
	var uv_scale = region.size / atlas_size

	for v in bone.vertices:
		batch.verts.append(v.pos)
		batch.uvs.append(uv_offset + v.uv * uv_scale)
		batch.colors.append(bone.tint)

	var indices = bone.indices if bone.indices.size() > 0 else bone.triangles
	for i in indices:
		batch.indices.append(base + i)

func batch_sprite(bone, atlas: Texture2D, tex):
	var batch = get_batch(atlas.get_rid())
	var size = tex.size * bone.scale
	var half = abs(size) * 0.5
	var transform = Transform2D(bone.rot, bone.pos)

	var p0 = transform * Vector2(-half.x, -half.y)
	var p1 = transform * Vector2( half.x, -half.y)
	var p2 = transform * Vector2( half.x,  half.y)
	var p3 = transform * Vector2(-half.x,  half.y)

	var base = batch.verts.size()
	batch.verts.append_array([p0,p1,p2,p3])
	batch.colors.append_array([bone.tint,bone.tint,bone.tint,bone.tint])

	var atlas_size = Vector2(atlas.get_width(), atlas.get_height())
	var uv0 = tex.offset / atlas_size
	var uv1 = (tex.offset + tex.size) / atlas_size

	batch.uvs.append_array([
		Vector2(uv0.x,uv0.y),
		Vector2(uv1.x,uv0.y),
		Vector2(uv1.x,uv1.y),
		Vector2(uv0.x,uv1.y)
	])

	batch.indices.append_array([
		base, base+1, base+2,
		base, base+2, base+3
	])

func setup_bone_textures(bones: Array, styles: Array) -> Dictionary:
	var result := {}
	if bones.is_empty() or styles.is_empty():
		return result

	var visible_style_names := []
	for st_name in model_styles.keys():
		var res = model_styles[st_name] as SKFStylesRes
		if res && res.visible:
			visible_style_names.append(res.style_name)

	for b in bones:
		var tex_assigned := false
		for st in styles:
			if st.name not in visible_style_names:
				continue 

			for tex in st.textures:
				if tex.name == b.tex:
					result[b.id] = tex 
					tex_assigned = true
					break
			if tex_assigned:
				break

	return result

func get_batch(rid: RID) -> DrawBatch:
	if !draw_batches.has(rid):
		draw_batches[rid] = DrawBatch.new()
	return draw_batches[rid]
