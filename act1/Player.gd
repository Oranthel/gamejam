@tool
extends CharacterBody2D
class_name Player

## 玩家：点击切换造型 + 激活移动 + 瞬移到预设位置
## 逐个点击切换皮肤，切到最后一个皮肤时自动激活移动。
## 点击屏幕任意位置换肤，人物跳到 teleport_positions 数组中对应的预设位置。

@export var skins: Array[Texture2D] = []
@export var walk_frames: Array[Texture2D] = []
@export var teleport_positions: Array[Vector2] = []
@export var move_speed: float = 220.0
@export var walk_fps: float = 10.0
@export var sprite_scale: float = 0.3

signal activated

var current_skin_index: int = -1
var can_move: bool = false
var click_count: int = 0
var walk_frame_index: int = 0
var walk_timer: float = 0.0
var is_walking: bool = false
var facing_right: bool = true

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	if sprite and sprite.scale == Vector2(1, 1):
		sprite.scale = Vector2(sprite_scale, sprite_scale)
	# 不在 ready 时加载皮肤，等首次点击再加载
	# 这样保证点击次数和皮肤一一对应


func _unhandled_input(event: InputEvent) -> void:
	# 鼠标左键 或 空格键 都可以切换造型
	var is_left_click: bool = event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT
	var is_space: bool = event is InputEventKey \
			and event.pressed \
			and event.keycode == KEY_SPACE
	if not (is_left_click or is_space):
		return
	if not can_move:
		# 激活前：逐个切换皮肤 + 跳到预设位置
		if skins.size() == 0:
			return
		if current_skin_index < 0:
			click_count = 1
			_apply_skin(0)
			_teleport_to_index(0)
		elif click_count < skins.size():
			click_count += 1
			_apply_skin(click_count - 1)
			_teleport_to_index(click_count - 1)
			if click_count >= skins.size():
				can_move = true
				activated.emit()
	else:
		# 已激活：皮肤锁定，点击无效
		pass


func _teleport_to_index(index: int) -> void:
	if teleport_positions.is_empty():
		return
	var pos := teleport_positions[min(index, teleport_positions.size() - 1)]
	# 跳过零坐标（说明用户没填这个位置）
	if pos == Vector2.ZERO:
		return
	position = pos


func _apply_skin(index: int) -> void:
	# 换肤只换贴图，不做 flip（换肤阶段不涉及朝向）
	current_skin_index = index % max(skins.size(), 1)
	if sprite:
		sprite.texture = skins[current_skin_index]


func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if can_move:
		velocity = dir * move_speed
		move_and_slide()

		if dir.x < -0.1:
			facing_right = false
		elif dir.x > 0.1:
			facing_right = true

		is_walking = dir.length() > 0.01

		var target_flip := facing_right

		if is_walking and walk_frames.size() > 0 and sprite:
			walk_timer += delta
			var frame_duration := 1.0 / walk_fps
			if walk_timer >= frame_duration:
				walk_timer -= frame_duration
				walk_frame_index = (walk_frame_index + 1) % walk_frames.size()
				sprite.texture = walk_frames[walk_frame_index]
			sprite.flip_h = target_flip
		elif not is_walking and sprite:
			if walk_frames.size() > 0:
				sprite.texture = walk_frames[0]
			elif current_skin_index >= 0:
				sprite.texture = skins[current_skin_index]
			sprite.flip_h = target_flip
	else:
		is_walking = false


func set_walk_frames(frames: Array[Texture2D]) -> void:
	# 拾取背包后替换行走帧，后续剧情保留
	walk_frames = frames
