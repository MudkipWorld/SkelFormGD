extends Node2D
class_name SkelFormPlayer

var backend := SkelformBackend.new()
var armature : SkelformBackend.Armature
var solved_bones: Array = []
var current_frame: int = 0
var anim_length: int = 0
var img_atlas : Image = null
var text_atlases : Array = []
var time_accum : float = 0.0
var prev_frame : int = 0
var frame_skip_count : int = 0

@export var file: String
@export var fps: int = 24
@export var frame_skip: int = 2
@export var animation_index : int = 0
@export var model_scale : Vector2 = Vector2(0.1, 0.1)
@export var model_style: int = 0:
	set(new_style):
		if armature == null:
			return
		if new_style < 0 or new_style >= armature.styles.size():
			return
		model_style = new_style
		bone_texture_results = setup_bone_textures(solved_bones, armature.styles)
@export var debug : bool = false

var bone_texture_results : Dictionary = {}

func _ready():
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	if file.is_empty():
		return
	var dict = SkelformBackend.load_armature_from_file(file)
	armature = dict.arm
	img_atlas = dict.img_at
	if img_atlas:
		text_atlases.append(ImageTexture.create_from_image(img_atlas))
	
	if not armature:
		return
	if armature.animations.size() > animation_index:
		var anim = armature.animations[animation_index]
		if anim.keyframes.size() > 0:
			anim_length = anim.keyframes[-1].frame + 1
		else:
			anim_length = 0
	else:
		anim_length = 0
	
	bone_texture_results = setup_bone_textures(armature.bones, armature.styles)

func _physics_process(delta: float) -> void:
	frame_skip_count += 1
	if not armature or armature.animations.is_empty():
		return
	if animation_index < 0 or animation_index >= armature.animations.size(): 
		return
	var anim = armature.animations[animation_index]
	anim_length = anim.keyframes[-1].frame + 1
	if anim_length == 0:
		return
	time_accum += delta
	var frame = int(time_accum * fps) % anim_length
	if prev_frame == frame:
		return
		
	prev_frame = frame
	if frame_skip_count < frame_skip:
		return
	var opts = SkelformBackend.ConstructOptions.new(Vector2(0, 0), model_scale, true)
	backend.animate(armature.bones, [anim], [frame], [1])
	solved_bones = backend.construct(armature, opts)
	queue_redraw()
	frame_skip_count = 0

func _draw() -> void:
	if solved_bones.is_empty():
		return
	draw_skeleton(solved_bones,armature.styles,text_atlases )

func draw_skeleton(bones: Array, styles: Array, atlases: Array) -> void:
	if bones.is_empty():
		return
	bones.sort_custom(func(a, b): return a.zindex < b.zindex)
	if bone_texture_results.is_empty():
		bone_texture_results = setup_bone_textures(solved_bones, armature.styles)
		
	var final_textures = bone_texture_results
	
	for b in bones:
		if not final_textures.has(b.id):
			continue
		var tex: SkelformBackend.TextureData = final_textures[b.id]
		var atlas: Texture2D = atlases[tex.atlas_idx]
		if atlas == null:
			continue
		if !b.vertices.is_empty():
			var region : Rect2 = Rect2(tex.offset, tex.size)
			_draw_bone_mesh(b, atlas, region)
		else:
			var region : Rect2 = Rect2(tex.offset, tex.size)
			var size = tex.size * b.scale
			var push_center = abs(size) * 0.5
			draw_set_transform(b.pos, b.rot, Vector2.ONE)
			draw_texture_rect_region(atlas, Rect2(-push_center, size), region)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_bone_mesh(bone, atlas: Texture2D, region: Rect2) -> void:
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
	RenderingServer.canvas_item_add_triangle_array(
		get_canvas_item(),
		indices_array,
		verts,
		colors,
		uvs,
		PackedInt32Array(),  
		PackedFloat32Array(), 
		atlas.get_rid()
	)

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
