extends CanvasLayer
class_name DialogueBox

## 对话框 UI：角色名 + 打字机文本 + 点击继续

@export var type_speed: float = 0.03  # 每字秒数

@onready var panel: Panel = $Panel
@onready var name_label: Label = $Panel/NameLabel
@onready var text_label: RichTextLabel = $Panel/TextLabel
@onready var continue_hint: Label = $Panel/ContinueHint

var _sketch_lines: ErosionSketchLines

var _dialogues: Array = []
var _index: int = 0
var _typing: bool = false
var _full_text: String = ""
var _char_index: float = 0.0
var _base_name_color := Color(1.0, 0.85, 0.5)
var _base_text_color := Color(1, 1, 1)
var _stage: int = 0


func _ready() -> void:
	visible = false
	_sketch_lines = ErosionSketchLines.new()
	_sketch_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_sketch_lines)
	ErosionTheme.stage_changed.connect(_apply_theme)
	_apply_theme(ErosionTheme.stage)
	StoryManager.dialogue_requested.connect(_on_dialogue_requested)
	StoryManager.phone_call_requested.connect(_on_dialogue_requested)


func _apply_theme(s: int) -> void:
	_stage = s
	panel.add_theme_stylebox_override("panel", ErosionTheme.get_panel_stylebox("dlg", "dialog_bg"))
	_sketch_lines.light_lines = (s == 3)
	_sketch_lines.set_active(s >= 3)
	_base_name_color = ErosionTheme.get_color("dialog_name")
	_base_text_color = ErosionTheme.get_color("dialog_text")
	# 浅色背景（残稿档）用浅色描边，深色背景用黑色描边
	if s >= 4:
		name_label.add_theme_color_override("font_outline_color", Color(0.9, 0.9, 0.88, 0.6))
		text_label.add_theme_color_override("font_outline_color", Color(0.9, 0.9, 0.88, 0.6))
		name_label.add_theme_constant_override("outline_size", 2)
		text_label.add_theme_constant_override("outline_size", 2)
	else:
		name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		name_label.add_theme_constant_override("outline_size", 4)
		text_label.add_theme_constant_override("outline_size", 4)


func _process(delta: float) -> void:
	if _typing:
		_char_index += delta / type_speed
		var shown = _full_text.substr(0, int(_char_index))
		text_label.text = shown
		if int(_char_index) >= _full_text.length():
			_typing = false
			continue_hint.visible = true


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		# 点击落在 UI 按钮上时不拦截，让按钮自己处理
		var pos: Vector2 = event.position
		if _is_on_ui_button(pos):
			return
		_advance()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_advance()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()


func _is_on_ui_button(pos: Vector2) -> bool:
	var status_bar := get_node_or_null("../StatusBar")
	if status_bar:
		# 弹窗可见时，任何点击都不推进对话（包括点关闭按钮和点外部关闭）
		var mp := status_bar.get_node_or_null("MenuPopup")
		if mp and mp.visible:
			return true
		var hp := status_bar.get_node_or_null("HistoryPopup")
		if hp and hp.visible:
			return true
		# 检查顶部菜单/回看按钮
		var menu_btn := status_bar.get_node_or_null("Panel/Margin/HBox/MenuBtn")
		if menu_btn and menu_btn.get_global_rect().has_point(pos):
			return true
		var hist_btn := status_bar.get_node_or_null("Panel/Margin/HBox/HistoryBtn")
		if hist_btn and hist_btn.get_global_rect().has_point(pos):
			return true
	# 选项面板可见时，任何点击都不推进对话
	var option_box := get_node_or_null("../OptionBox")
	if option_box and option_box.visible:
		return true
	return false


func _on_dialogue_requested(dialogues: Array) -> void:
	_dialogues = dialogues
	_index = 0
	visible = true
	_show_current()


func _show_current() -> void:
	if _index >= _dialogues.size():
		_finish()
		return
	var d = _dialogues[_index]
	var speaker = d.get("speaker", "")
	var text = d.get("text", "")
	var is_os: bool = speaker.ends_with("_OS")
	# 角色名映射
	name_label.text = _speaker_name(speaker)
	# 立绘只在主角说话/内心独白时显示
	var portrait := get_node_or_null("../Portrait")
	if portrait:
		portrait.visible = speaker.begins_with("CHAR_MAIN")
	# 记录到历史（回看用）
	GameState.dialogue_history.append({"name": _speaker_name(speaker), "text": text, "os": is_os})
	# 内心独白(os)：用青蓝色+斜体与"说出来的话"区分，但保持高亮度确保清晰
	if is_os:
		if _stage >= 4:
			name_label.add_theme_color_override("font_color", Color(0.25, 0.45, 0.6))
			text_label.add_theme_color_override("default_color", Color(0.2, 0.35, 0.5))
		else:
			name_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
			text_label.add_theme_color_override("default_color", Color(0.75, 0.88, 1.0))
		name_label.add_theme_font_size_override("font_size", 26)
		text_label.add_theme_font_size_override("normal_font_size", 24)
	else:
		name_label.add_theme_color_override("font_color", _base_name_color)
		text_label.add_theme_color_override("default_color", _base_text_color)
		name_label.add_theme_font_size_override("font_size", 28)
		text_label.add_theme_font_size_override("normal_font_size", 26)
	# 打字机
	_full_text = text
	_char_index = 0.0
	_typing = true
	continue_hint.visible = false


func _speaker_name(speaker: String) -> String:
	# 内心独白：任意 *_OS 后缀 → 显示「内心」
	if speaker.ends_with("_OS"):
		return "内心"
	match speaker:
		"CHAR_MAIN": return "主角"
		"CHAR_FRIEND": return "朋友"
		"CHAR_A": return "李安"
		"CHAR_B": return "赵北"
		"CHAR_TEACHER": return "老师"
		"CHAR_MOTHER": return "妈妈"
		"CHAR_CLASSMATE": return "同学"
		"CHAR_C": return "陈小草"
		"NARRATOR": return "旁白"
		"SYSTEM": return "系统"
		"SYSTEM_SHOPKEEPER": return "店员"
		_: return speaker


func _advance() -> void:
	AudioManager.play_sfx(AudioManager.SFX_CLICK)
	if _typing:
		# 跳过打字机，显示全文
		_typing = false
		text_label.text = _full_text
		continue_hint.visible = true
		return
	_index += 1
	_show_current()


func _finish() -> void:
	visible = false
	var portrait := get_node_or_null("../Portrait")
	if portrait:
		portrait.visible = false
	StoryManager.on_dialogue_finished()
