extends CanvasLayer
class_name OptionBox

## 选项 UI：动态生成按钮，选择后通知 StoryManager

@onready var panel: Panel = $Panel
@onready var container: VBoxContainer = $Panel/VBoxContainer

var _options: Array = []
var _event_id: String = ""
var _option_bg := Color(0.15, 0.15, 0.18, 0.9)
var _option_text := Color(1, 1, 1)
var _stage: int = 0


func _ready() -> void:
	visible = false
	ErosionTheme.stage_changed.connect(_apply_theme)
	_apply_theme(ErosionTheme.stage)
	StoryManager.option_requested.connect(_on_option_requested)


func _apply_theme(_stage: int) -> void:
	_stage = _stage
	_option_bg = ErosionTheme.get_color("option_bg")
	_option_text = ErosionTheme.get_color("option_text")


func _on_option_requested(options: Array, event_id: String) -> void:
	_options = options
	_event_id = event_id
	# 清除旧按钮
	for child in container.get_children():
		child.queue_free()
	# 生成新按钮
	for opt in options:
		var btn = Button.new()
		btn.text = opt.get("text", "")
		btn.custom_minimum_size = Vector2(320, 44)
		# 按钮样式
		var normal_sb: StyleBoxFlat = StyleBoxFlat.new()
		normal_sb.bg_color = _option_bg
		normal_sb.border_color = ErosionTheme.get_color("dialog_border")
		normal_sb.set_border_width_all(1 if _stage >= 3 else 2)
		normal_sb.set_corner_radius_all(0 if _stage >= 3 else 8)
		if _stage == 3:
			# 蓝晒档：像粘在档案纸上的选择条，留出不均匀的纸边感。
			normal_sb.content_margin_left = 18.0
			normal_sb.content_margin_right = 12.0
			normal_sb.border_color = Color(0.88, 0.88, 0.78, 0.86)
		elif _stage == 4:
			# 残稿档：去掉实体按钮感，保留轻薄的铅笔轮廓。
			normal_sb.bg_color = Color(1.0, 1.0, 1.0, 0.18)
			normal_sb.border_color = Color(0.16, 0.16, 0.16, 0.74)
			normal_sb.content_margin_left = 16.0
			normal_sb.content_margin_right = 16.0
		btn.add_theme_stylebox_override("normal", normal_sb)
		var hover_sb: StyleBoxFlat = normal_sb.duplicate() as StyleBoxFlat
		hover_sb.bg_color = Color(0.25, 0.3, 0.45, 0.95) if _stage < 4 else Color(0.15, 0.15, 0.15, 0.12)
		btn.add_theme_stylebox_override("hover", hover_sb)
		var pressed_sb: StyleBoxFlat = normal_sb.duplicate() as StyleBoxFlat
		pressed_sb.bg_color = Color(0.35, 0.45, 0.65, 1) if _stage < 4 else Color(0.08, 0.08, 0.08, 0.24)
		pressed_sb.set_border_width_all(3 if _stage == 4 else 2)
		btn.add_theme_stylebox_override("pressed", pressed_sb)
		btn.add_theme_color_override("font_color", _option_text)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_button_pressed.bind(opt))
		btn.mouse_entered.connect(func(): AudioManager.play_sfx(AudioManager.SFX_HOVER))
		container.add_child(btn)
	visible = true


func _on_button_pressed(option: Dictionary) -> void:
	AudioManager.play_sfx(AudioManager.SFX_CLICK)
	visible = false
	StoryManager.on_option_selected(option)
