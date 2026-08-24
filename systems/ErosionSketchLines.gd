extends Control
class_name ErosionSketchLines

## 残稿档的动态铅笔残线：生成、碎裂、淡出后重新出现。
## 只画在容器边缘，避免与正文区域发生视觉重叠。

class SketchLine:
	var start: Vector2
	var end: Vector2
	var shade: float
	var width: float
	var phase: float


var cycle_seconds: float = 3.2   # 循环周期（秒），可调
const LINE_COUNT: int = 34

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lines: Array[SketchLine] = []
var _elapsed: float = 0.0
var _active: bool = false
var light_lines: bool = false   # 蓝晒档用浅色线（深底可见）
var shade_override: float = -1.0   # >0 时覆盖明度（封面按钮框用）
var width_scale: float = 1.0       # 线宽缩放
var phase_offset: float = 0.0      # 周期相位偏移（让不同实例节奏错开）
var rng_seed: int = 0              # 随机种子（0 = 随机）


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_regenerate()


func set_active(active: bool) -> void:
	_active = active
	visible = active
	set_process(active)
	if active:
		_elapsed = phase_offset
		_regenerate()
		queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= cycle_seconds:
		_elapsed = 0.0
		_regenerate()
	queue_redraw()


func _draw() -> void:
	if not _active or size.x < 48.0 or size.y < 48.0:
		return
	var progress: float = _elapsed / cycle_seconds
	var fade: float = _fade_amount(progress)
	for line: SketchLine in _lines:
		var local_progress: float = fmod(progress + line.phase, 1.0)
		if local_progress > 0.74:
			continue
		var alpha: float = fade * (1.0 - maxf(0.0, local_progress - 0.52) / 0.22)
		var graphite: Color = Color(line.shade, line.shade, line.shade, alpha)
		var jitter: Vector2 = Vector2(sin(_elapsed * 7.0 + line.phase * 19.0), cos(_elapsed * 5.0 + line.phase * 13.0))
		draw_line(line.start + jitter, line.end + jitter, graphite, line.width, true)


func _fade_amount(progress: float) -> float:
	if progress < 0.16:
		return progress / 0.16
	if progress < 0.68:
		return 1.0
	return 1.0 - (progress - 0.68) / 0.32


func _regenerate() -> void:
	_lines.clear()
	if size.x < 48.0 or size.y < 48.0:
		return
	var inset: float = 10.0
	for _index: int in LINE_COUNT:
		var horizontal: bool = _rng.randi_range(0, 1) == 0
		var length: float = _rng.randf_range(18.0, 92.0)
		var offset: float = _rng.randf_range(0.0, 1.0)
		var line: SketchLine = SketchLine.new()
		if shade_override >= 0.0:
			line.shade = clampf(shade_override + _rng.randf_range(-0.05, 0.05), 0.05, 1.0)
		else:
			line.shade = _rng.randf_range(0.72, 0.95) if light_lines else _rng.randf_range(0.12, 0.48)
		line.width = _rng.randf_range(0.7, 2.2) * width_scale
		line.phase = _rng.randf_range(0.0, 0.32)
		if horizontal:
			var y: float = inset if _rng.randi_range(0, 1) == 0 else size.y - inset
			var x: float = lerpf(inset, maxf(inset, size.x - inset - length), offset)
			line.start = Vector2(x, y)
			line.end = Vector2(minf(size.x - inset, x + length), y + _rng.randf_range(-1.6, 1.6))
		else:
			var x_vertical: float = inset if _rng.randi_range(0, 1) == 0 else size.x - inset
			var y_vertical: float = lerpf(inset, maxf(inset, size.y - inset - length), offset)
			line.start = Vector2(x_vertical, y_vertical)
			line.end = Vector2(x_vertical + _rng.randf_range(-1.6, 1.6), minf(size.y - inset, y_vertical + length))
		_lines.append(line)
