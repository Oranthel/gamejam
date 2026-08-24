extends Node2D

## 游戏开头10个场景管理器
## 不变式（标准状态）：
##   _bottom(z=0, a=1, texture=当前场景)  ← 用户看到的画面
##   _top   (z=10, a=0, texture=null)     ← 留给过渡用的「上层空槽」
##
## 过渡规则（不黑屏）：
##   scene1 → scene2：先特殊布局，擦除scene1（上层）露出scene2（下层）；完成后回到标准
##   scene2→3 ... 8→9：标准状态 → 新场景写 top 淡入 → 清空 bottom 并 swap → 标准
##   scene9 → scene10：scene9 在 bottom 先大大放大；scene10 写 top(同样大尺寸) 淡入+缩小；清空 bottom swap → 标准
##   scene10 → Act1：标准状态下 bottom(scene10) 渐隐 a→0 → 切场景

const SCENE_TEXTURES := [
	"res://art/scene1.jpg",
	"res://art/scene2.jpg",
	"res://art/scene3.jpg",
	"res://art/scene4.jpg",
	"res://art/scene5.jpg",
	"res://art/scene6.jpg",
	"res://art/scene7.jpg",
	"res://art/scene8.jpg",
	"res://art/scene9.jpg",
	"res://art/scene10.jpg",
]

const ACT1_SCENE := "res://act1/Act1.tscn"
const TOTAL_SCENES := 10

# ========== 可调参数 ==========
@export var fade_duration: float = 1.4
@export var zoom_target_scale: float = 100.0    # 放大倍数（放大 100 倍）
@export var zoom_duration: float = 4.8          # 放大总时长（放慢一倍）
@export var erase_threshold: float = 0.65

# ========== 节点引用 ==========
@onready var sprite_a: Sprite2D = $SceneSpriteA
@onready var sprite_b: Sprite2D = $SceneSpriteB
@onready var erase_effect: Node2D = $EraseEffect
## scene9 放大中心点（Marker2D）——在编辑器里拖动这个十字标记，放到你想放大的位置
@onready var zoom_center_marker: Marker2D = get_node_or_null("ZoomCenterMarker")

# ========== 状态 ==========
var current_scene_index: int = 0
var is_transitioning: bool = false
var _bottom: Sprite2D   # z=0，标准状态下就是当前显示的场景
var _top: Sprite2D      # z=10，标准状态下是空的、透明的，用作过渡写入层
var _base_scale: Vector2 = Vector2.ONE


# ================================================================
# 生命周期：开头先从黑屏渐入 scene1
# ================================================================

func _ready() -> void:
	# 开头 BGM（菜单已播则自动跳过，不重播）
	AudioManager.play_bgm(AudioManager.BGM_OPENING)
	_bottom = sprite_b
	_top = sprite_a
	_bottom.z_index = 0
	_top.z_index = 10
	# 标准状态初始化：两个都清空
	_bottom.texture = null
	_bottom.modulate.a = 0.0
	_top.texture = null
	_top.modulate.a = 0.0
	#
	# ===== 擦除阶段特殊布局 =====
	# scene2 先放到 _bottom（下层），先透明（避免闪现）
	_set_texture_only(_bottom, 1)
	_bottom.scale = _base_scale
	_bottom.modulate.a = 0.0
	_bottom.z_index = 0
	# scene1 放到 _top（上层，因为要被擦除），从透明渐入
	_set_texture_only(_top, 0)
	_top.scale = _base_scale
	_top.modulate.a = 0.0
	_top.z_index = 10
	current_scene_index = 0
	# 渐入 scene1（2秒，慢一倍）
	is_transitioning = true
	var tween := create_tween()
	tween.tween_property(_top, "modulate:a", 1.0, 2.0)
	tween.tween_callback(func():
		# scene1 完全盖住，这时才把 scene2 显示出来（在底下被挡住，不会闪）
		_bottom.modulate.a = 1.0
		is_transitioning = false
		# 在 _top（scene1）上启动擦除，擦透明就直接露出下面 _bottom 的 scene2
		erase_effect.call("start_erase_on_sprite", _top, SCENE_TEXTURES[0], erase_threshold, Callable(self, "_on_erase_complete"))
	)


# ================================================================
# 点击推进
# ================================================================

func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning:
		return
	if current_scene_index == 0:
		return
	# 鼠标左键 或 空格键 都可以推进
	var is_left_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var is_space: bool = event is InputEventKey and event.pressed and event.keycode == KEY_SPACE
	if is_left_click or is_space:
		_advance()


func _advance() -> void:
	match current_scene_index:
		8:   # 当前是 scene9（index=8），点击放大切 scene10
			_transition_zoom_to_10()
		9:   # 当前是 scene10（index=9），点击渐隐进入 Act1
			_transition_final_to_act1()
		_:   # scene2→3 ... scene8→9  标准淡入
			_fade_in_next()


# ================================================================
# 工具：只设置纹理+缩放（不改动 modulate、不改变 index）
# ================================================================

func _set_texture_only(spr: Sprite2D, index: int) -> void:
	assert(index >= 0 and index < TOTAL_SCENES)
	var texture: Texture2D = load(SCENE_TEXTURES[index])
	if texture == null:
		push_warning("找不到场景图片: " + SCENE_TEXTURES[index])
		return
	spr.texture = texture
	spr.centered = false
	spr.position = Vector2.ZERO
	var tex_size: Vector2 = texture.get_size()
	var vs: Vector2 = get_viewport_rect().size
	var s: float = max(vs.x / tex_size.x, vs.y / tex_size.y)
	_base_scale = Vector2(s, s)
	spr.scale = _base_scale


func _restore_top_bottom() -> void:
	# swap 之后把两个精灵的 z_index 复位到标准状态
	_bottom.z_index = 0
	_top.z_index = 10


# ================================================================
# 过渡 1：新场景在 _top（上层空槽）淡入；完成后清空旧 _bottom 并 swap → 标准
# ================================================================

func _fade_in_next() -> void:
	var next_idx: int = current_scene_index + 1
	_fade_in_to(next_idx, fade_duration)


func _fade_in_to(index: int, dur: float) -> void:
	is_transitioning = true
	# 标准状态：_bottom 显示当前场景（a=1），_top 是空
	# 把新场景写到 _top，从透明淡入 → 下面旧场景保持完全可见，不黑屏
	_set_texture_only(_top, index)
	_top.scale = _base_scale
	_top.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_top, "modulate:a", 1.0, dur)
	tween.tween_callback(func():
		# 新场景完全显示在 _top 上 → 隐藏并清空旧 _bottom → swap → 标准
		_bottom.modulate.a = 0.0
		_bottom.texture = null
		_bottom.scale = _base_scale
		var tmp: Sprite2D = _bottom
		_bottom = _top
		_top = tmp
		_restore_top_bottom()
		current_scene_index = index
		is_transitioning = false
	)


# ================================================================
# 过渡 2：擦除完成 → scene1（_top）快速淡出，scene2（_bottom）就是当前画面
# 擦除完成后 scene2 已经可见，把状态收拢为标准状态（bottom=scene2）
# ================================================================

func _on_erase_complete() -> void:
	if current_scene_index != 0 or is_transitioning:
		return
	is_transitioning = true
	# top(scene1) 快速淡出；底下 scene2 已可见
	var tween := create_tween()
	tween.tween_property(_top, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		# 现在：_bottom=scene2 a=1（当前画面），_top=scene1 a=0 没用了
		# 清空 _top 让它成为「上层空槽」，回到标准状态
		_top.texture = null
		_top.scale = _base_scale
		# 注意 _bottom 已经是 scene2 了，不用 swap
		current_scene_index = 1
		is_transitioning = false
	)


# ================================================================
# 过渡 3：scene9（_bottom）大大放大 → scene10（_top）淡入 + 缩小 → 标准
# ================================================================

func _transition_zoom_to_10() -> void:
	is_transitioning = true
	# 当前标准状态：_bottom = scene9（a=1, centered=false, position=0, scale=_base_scale），_top 是空
	var vs: Vector2 = get_viewport_rect().size
	# 放大中心点：优先用 Marker2D 的位置，没有就退回屏幕中心
	var zoom_anchor: Vector2
	if zoom_center_marker != null and is_instance_valid(zoom_center_marker):
		zoom_anchor = zoom_center_marker.global_position
	else:
		zoom_anchor = vs * 0.5

	# ---- 数学原理 ----
	# centered=false 时：图上像素点 P 在屏幕上的位置 = position + P * scale
	# 要让锚点 P 始终在 zoom_anchor：position = zoom_anchor - P * scale
	# 锚点像素坐标 P = zoom_anchor / base_scale（标准状态下 position=0，所以 P*base_scale=zoom_anchor）
	# 当 scale 和 position 都线性插值时，锚点自动保持在 zoom_anchor（数学已验证）

	var base_9: Vector2 = _bottom.scale  # = _base_scale
	var anchor_tex_9: Vector2 = zoom_anchor / base_9
	var zoomed_9: Vector2 = base_9 * zoom_target_scale
	# scene9 放大终点：position = zoom_anchor - anchor_tex_9 * zoomed_9
	var end_pos_9: Vector2 = zoom_anchor - anchor_tex_9 * zoomed_9

	var tween := create_tween()

	# ---- Phase 1: scene9 围绕 zoom_anchor 放大 100 倍 ----
	# scale: base_9 → zoomed_9, position: (0,0) → end_pos_9，同时插值锚点不动
	_bottom.centered = false
	tween.set_parallel(true)
	tween.tween_property(_bottom, "scale", zoomed_9, zoom_duration * 0.5)
	tween.tween_property(_bottom, "position", end_pos_9, zoom_duration * 0.5)
	tween.set_parallel(false)

	# ---- Phase 2: scene10 渐显（大小不变，只改透明度）----
	tween.tween_callback(func():
		# 加载 scene10，直接以正常尺寸铺满全屏，只从透明渐入
		_set_texture_only(_top, 9)
		_top.centered = false
		_top.position = Vector2.ZERO
		_top.scale = _base_scale
		_top.modulate.a = 0.0
		var t2 := create_tween()
		var phase2_dur: float = zoom_duration * 0.5
		t2.tween_property(_top, "modulate:a", 1.0, phase2_dur)
		t2.chain().tween_callback(func():
			# scene10 就位，清空 scene9 → swap → 标准
			_bottom.modulate.a = 0.0
			_bottom.texture = null
			_bottom.position = Vector2.ZERO
			_bottom.scale = _base_scale
			var tmp: Sprite2D = _bottom
			_bottom = _top
			_top = tmp
			_restore_top_bottom()
			current_scene_index = 9
			is_transitioning = false
		)
	)


# ================================================================
# 过渡 4：scene10（_bottom）渐隐 → 进入 Act1
# ================================================================

func _transition_final_to_act1() -> void:
	is_transitioning = true
	var tween := create_tween()
	tween.tween_property(_bottom, "modulate:a", 0.0, fade_duration * 1.4)
	tween.tween_callback(func():
		if erase_effect:
			erase_effect.call("cleanup")
		var err := get_tree().change_scene_to_file(ACT1_SCENE)
		if err != OK:
			push_warning("切换到Act1失败: " + str(err))
	)
