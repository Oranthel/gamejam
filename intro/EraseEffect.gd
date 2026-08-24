extends Node2D

## 鼠标擦除效果（直接在目标Sprite的纹理上擦除）
## 擦除部分变透明，露出下面的内容（不是黑色遮罩）

@export var brush_radius: int = 70
@export var progress_check_interval: float = 0.3
@export var erase_center_x: float = 0.5
@export var erase_center_y: float = 0.5
@export var erase_area_w: float = 0.6
@export var erase_area_h: float = 0.6

var _target_sprite: Sprite2D
var _mask_image: Image
var _mask_texture: ImageTexture
var _is_erasing: bool = false
var _threshold: float = 0.7
var _complete_callback: Callable
var _last_mouse_pos: Vector2i
var _progress_timer: float = 0.0

const BLOCK_SIZE: int = 16
var _blocks_w: int = 0
var _blocks_h: int = 0
var _erased_in_area_bits: PackedByteArray
var _area_block_x0: int = 0
var _area_block_y0: int = 0
var _area_block_x1: int = 0
var _area_block_y1: int = 0
var _erased_blocks: int = 0
var _total_area_blocks: int = 0
var _dirty: bool = false


## 启动擦除：直接在目标精灵的纹理上操作
func start_erase_on_sprite(target_sprite: Sprite2D, image_path: String, threshold: float, on_complete: Callable) -> void:
	_threshold = clamp(threshold, 0.1, 0.99)
	_complete_callback = on_complete
	_target_sprite = target_sprite
	# 通过资源系统加载（导出后 res:// 是打包的，不能用 Image.load_from_file 直接读）
	var tex: Texture2D = load(image_path) as Texture2D
	if tex == null:
		push_warning("无法加载图片用于擦除: " + image_path)
		return
	_mask_image = tex.get_image()
	# ===== 关键：强制转换成 RGBA8 才有 alpha 通道，才能擦透明 =====
	# JPG 本身是不带 alpha 的，不转换的话 fill_rect 写 a=0 无效
	# 注意 Godot 4 Image.convert() 是原地转换，返回 void
	if _mask_image.get_format() != Image.FORMAT_RGBA8:
		_mask_image.convert(Image.FORMAT_RGBA8)
	# 创建 ImageTexture 替换目标精灵的纹理
	_mask_texture = ImageTexture.create_from_image(_mask_image)
	_target_sprite.texture = _mask_texture
	_init_stats()
	_is_erasing = true


# ================================================================
# 初始化进度统计
# ================================================================

func _init_stats() -> void:
	var w: int = _mask_image.get_width()
	var h: int = _mask_image.get_height()
	var area_pix_w: int = int(w * erase_area_w)
	var area_pix_h: int = int(h * erase_area_h)
	var area_cx: int = int(w * erase_center_x)
	var area_cy: int = int(h * erase_center_y)
	var area_x0: int = clampi(area_cx - area_pix_w / 2, 0, w)
	var area_y0: int = clampi(area_cy - area_pix_h / 2, 0, h)
	var area_x1: int = clampi(area_cx + area_pix_w / 2, 0, w)
	var area_y1: int = clampi(area_cy + area_pix_h / 2, 0, h)
	_blocks_w = int(ceil(float(w) / float(BLOCK_SIZE)))
	_blocks_h = int(ceil(float(h) / float(BLOCK_SIZE)))
	_erased_in_area_bits = PackedByteArray()
	_erased_in_area_bits.resize(_blocks_w * _blocks_h)
	_erased_in_area_bits.fill(0)
	_area_block_x0 = clampi(int(floor(float(area_x0) / float(BLOCK_SIZE))), 0, _blocks_w)
	_area_block_y0 = clampi(int(floor(float(area_y0) / float(BLOCK_SIZE))), 0, _blocks_h)
	_area_block_x1 = clampi(int(ceil(float(area_x1) / float(BLOCK_SIZE))), 0, _blocks_w)
	_area_block_y1 = clampi(int(ceil(float(area_y1) / float(BLOCK_SIZE))), 0, _blocks_h)
	_total_area_blocks = max(1, (_area_block_x1 - _area_block_x0) * (_area_block_y1 - _area_block_y0))
	_erased_blocks = 0
	_progress_timer = 0.0
	_dirty = false


# ================================================================
# 输入
# ================================================================

func _input(event: InputEvent) -> void:
	if not _is_erasing:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var pos: Vector2i = Vector2i(event.position)
			if event.pressed:
				_last_mouse_pos = pos
				_erase_at(pos)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var pos: Vector2i = Vector2i(event.position)
		_erase_line(_last_mouse_pos, pos)
		_last_mouse_pos = pos
		get_viewport().set_input_as_handled()


# ================================================================
# 擦除绘制
# ================================================================

func _erase_line(from: Vector2i, to: Vector2i) -> void:
	var dist: float = from.distance_to(to)
	var steps: int = max(1, int(dist / max(1.0, float(brush_radius) / 3.0)))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2i = Vector2i(Vector2(from).lerp(Vector2(to), t))
		_erase_at(p)


func _erase_at(screen_pos: Vector2i) -> void:
	if not _mask_image or not _target_sprite:
		return
	var spr_scale: Vector2 = _target_sprite.scale
	var tex_pos: Vector2i = Vector2i(
		int(screen_pos.x / spr_scale.x),
		int(screen_pos.y / spr_scale.y)
	)
	var tex_r: int = max(1, int(brush_radius / spr_scale.x))
	var tex_r_sq: int = tex_r * tex_r
	var w: int = _mask_image.get_width()
	var h: int = _mask_image.get_height()
	var x0: int = clampi(tex_pos.x - tex_r, 0, w - 1)
	var x1: int = clampi(tex_pos.x + tex_r, 0, w - 1)
	var y0: int = clampi(tex_pos.y - tex_r, 0, h - 1)
	var y1: int = clampi(tex_pos.y + tex_r, 0, h - 1)

	for y in range(y0, y1 + 1):
		var dy: int = y - tex_pos.y
		var x_off_max_sq: int = tex_r_sq - dy * dy
		if x_off_max_sq < 0:
			continue
		var x_off_max: int = int(sqrt(float(x_off_max_sq)))
		var lx0: int = clampi(tex_pos.x - x_off_max, x0, x1)
		var lx1: int = clampi(tex_pos.x + x_off_max, x0, x1)
		_mask_image.fill_rect(Rect2i(lx0, y, lx1 - lx0 + 1, 1), Color(0, 0, 0, 0))

	_mark_blocks(x0, y0, x1, y1)
	_dirty = true


func _mark_blocks(x0: int, y0: int, x1: int, y1: int) -> void:
	var bx0: int = clampi(int(floor(float(x0) / float(BLOCK_SIZE))), _area_block_x0, _area_block_x1)
	var by0: int = clampi(int(floor(float(y0) / float(BLOCK_SIZE))), _area_block_y0, _area_block_y1)
	var bx1: int = clampi(int(ceil(float(x1 + 1) / float(BLOCK_SIZE))), _area_block_x0, _area_block_x1)
	var by1: int = clampi(int(ceil(float(y1 + 1) / float(BLOCK_SIZE))), _area_block_y0, _area_block_y1)
	for by in range(by0, by1):
		var row_off: int = by * _blocks_w
		for bx in range(bx0, bx1):
			var idx: int = row_off + bx
			if idx >= 0 and idx < _erased_in_area_bits.size():
				if _erased_in_area_bits[idx] == 0:
					_erased_in_area_bits[idx] = 1
					_erased_blocks += 1


# ================================================================
# 每帧：更新纹理 + 检测进度
# ================================================================

func _process(delta: float) -> void:
	if _dirty and _mask_texture and _mask_image:
		_mask_texture.update(_mask_image)
		_dirty = false
	if not _is_erasing:
		return
	_progress_timer += delta
	if _progress_timer >= progress_check_interval:
		_progress_timer = 0.0
		_check_progress()


func _check_progress() -> void:
	if _total_area_blocks <= 0:
		return
	var ratio: float = float(_erased_blocks) / float(_total_area_blocks)
	if ratio >= _threshold:
		_is_erasing = false
		var tween := create_tween()
		tween.tween_interval(0.1)
		tween.tween_callback(func():
			if _complete_callback.is_valid():
				_complete_callback.call()
		)


func cleanup() -> void:
	_is_erasing = false
	_target_sprite = null
	_mask_image = null
	_mask_texture = null
	_erased_in_area_bits = PackedByteArray()
