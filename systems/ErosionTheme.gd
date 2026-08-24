extends Node

## 侵蚀 UI 主题：侵蚀值 + 天数 取更高档 → 5 档调色板
## 档位：0 正常 / 1 褪色 / 2 黑白 / 3 蓝晒 / 4 线稿/几何

signal stage_changed(stage: int)

const STAGES := 5

var stage: int = 0

# 每档调色板（基础版，用 modulate 近似滤镜，后续可换 shader）
var _palettes: Array = [
	# 0 正常
	{ "dialog_bg": Color(0, 0, 0, 0.78), "dialog_text": Color(1, 1, 1), "dialog_name": Color(1, 0.85, 0.5), "dialog_border": Color(0.7, 0.7, 0.75, 1), "status_bg": Color(0.05, 0.05, 0.08, 0.85), "option_bg": Color(0.15, 0.15, 0.18, 0.9), "option_text": Color(1, 1, 1), "bg_modulate": Color(1, 1, 1) },
	# 1 褪色
	{ "dialog_bg": Color(0.18, 0.17, 0.16, 0.85), "dialog_text": Color(0.9, 0.88, 0.86), "dialog_name": Color(0.8, 0.75, 0.68), "dialog_border": Color(0.55, 0.53, 0.5, 1), "status_bg": Color(0.13, 0.12, 0.12, 0.9), "option_bg": Color(0.28, 0.27, 0.26, 0.92), "option_text": Color(0.9, 0.9, 0.88), "bg_modulate": Color(0.78, 0.76, 0.72) },
	# 2 黑白
	{ "dialog_bg": Color(0.04, 0.04, 0.04, 0.88), "dialog_text": Color(0.97, 0.97, 0.97), "dialog_name": Color(0.92, 0.92, 0.92), "dialog_border": Color(0.65, 0.65, 0.65, 1), "status_bg": Color(0.03, 0.03, 0.03, 0.92), "option_bg": Color(0.16, 0.16, 0.16, 0.94), "option_text": Color(0.95, 0.95, 0.95), "bg_modulate": Color(0.62, 0.62, 0.64) },
	# 3 蓝晒 · 美术考试纸（普鲁士蓝底 + 旧纸白字 + 灰蓝边框）
	{ "dialog_bg": Color(0.05, 0.17, 0.29, 0.90), "dialog_text": Color(0.92, 0.90, 0.82), "dialog_name": Color(0.91, 0.88, 0.78), "dialog_border": Color(0.55, 0.68, 0.82, 1), "status_bg": Color(0.04, 0.14, 0.24, 0.94), "option_bg": Color(0.10, 0.24, 0.38, 0.92), "option_text": Color(0.90, 0.90, 0.83), "bg_modulate": Color(0.55, 0.65, 0.85) },
	# 4 残稿 · 铅笔草稿（黑白灰：深黑关键线 + 中灰消失线 + 浅灰残留）
	{ "dialog_bg": Color(0.94, 0.94, 0.92, 0.94), "dialog_text": Color(0.12, 0.12, 0.12), "dialog_name": Color(0.28, 0.28, 0.28), "dialog_border": Color(0.38, 0.38, 0.38, 1), "status_bg": Color(0.91, 0.91, 0.90, 0.92), "option_bg": Color(1, 1, 1, 0.90), "option_text": Color(0.15, 0.15, 0.15), "bg_modulate": Color(0.72, 0.72, 0.74) },
]


func _ready() -> void:
	GameState.values_changed.connect(_refresh)
	StoryManager.day_changed.connect(_on_day_changed)
	# 初始广播一次
	stage_changed.emit(stage)


func _on_day_changed(_day: String, _countdown: int) -> void:
	_refresh()


func _refresh(_e: int = 0, _m: int = 0, _a: int = 0) -> void:
	var s := compute_stage()
	if s != stage:
		stage = s
		stage_changed.emit(stage)


func compute_stage() -> int:
	var es: int = clampi(GameState.erosion / 20, 0, STAGES - 1)
	return max(es, _day_stage())


func _day_stage() -> int:
	var cd: int = GameState.exam_countdown
	if cd >= 70:
		return 0
	if cd >= 60:
		return 1
	if cd >= 50:
		return 2
	if cd >= 40:
		return 3
	return 4


func get_color(key: String) -> Color:
	return _palettes[stage].get(key, Color.WHITE)


## ===== 图片 UI 支持 =====
## 想用图片替换某档 UI：把图放进 art/ui/，按档位命名（0~4）：
##   对话框底板：dlg_3.png（蓝晒档）  顶部状态栏：bar_3.png
## 有图就用图（九宫格拉伸，边距 24px），没图自动退回颜色。

const UI_TEXTURE_DIR := "res://art/ui/"


func get_panel_stylebox(element: String, bg_key: String) -> StyleBox:
	# 残稿档的对话框不使用带固定破碎框线的旧贴图；
	# 由 ErosionSketchLines 动态生成边缘残线，避免与正文形成重复线框。
	var tex: Texture2D = null
	if not (stage >= 3 and element == "dlg"):
		tex = _load_ui_texture(element)
	if tex != null:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = 24.0
		sb.texture_margin_right = 24.0
		sb.texture_margin_top = 24.0
		sb.texture_margin_bottom = 24.0
		return sb
	var sb := StyleBoxFlat.new()
	sb.bg_color = get_color(bg_key)
	sb.border_color = get_color("dialog_border")
	if stage >= 3 and element == "dlg":
		# 静态底板不再画边框，只保留动态铅笔残线。
		sb.set_border_width_all(0)
		sb.set_corner_radius_all(0)
	else:
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
	return sb


func _load_ui_texture(element: String) -> Texture2D:
	var base := UI_TEXTURE_DIR + element + "_" + str(stage)
	for ext in [".png", ".jpg", ".jpeg"]:
		if ResourceLoader.exists(base + ext):
			return load(base + ext)
	return null
