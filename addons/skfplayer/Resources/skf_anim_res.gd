extends Resource
class_name SkelformAnimationRes

@export var anim_name: String
@export_range(1, 120) var fps: int = 24
@export var playing : bool = false
@export var one_shot : bool = false
@export var next_animation : String = ""
