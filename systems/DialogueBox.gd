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


func _ready() -> void:
	visible = false
	_sketch_lines = ErosionSketchLines.new()
	panel.add_child(_sketch_lines)
	ErosionTheme.stage_changed.connect(_apply_theme)
	_apply_theme(ErosionTheme.stage)
	StoryManager.dialogue_requested.connect(_on_dialogue_requested)
	StoryManager.phone_call_requested.connect(_on_dialogue_requested)


func _apply_theme(_stage: int) -> void:
	panel.add_theme_stylebox_override("panel", ErosionTheme.get_panel_stylebox("dlg", "dialog_bg"))
	_sketch_lines.light_lines = (_stage == 3)
	_sketch_lines.set_active(_stage >= 3)
	_base_name_color = ErosionTheme.get_color("dialog_name")
	_base_text_color = ErosionTheme.get_color("dialog_text")


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
		_advance()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_advance()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()


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
	# 记录到历史（回看用）
	GameState.dialogue_history.append({"name": _speaker_name(speaker), "text": text, "os": is_os})
	# 内心独白(os)：名字与正文用偏灰蓝色，与"说出来的话"区分（打字机安全，无需 BBCode）
	if is_os:
		name_label.add_theme_color_override("font_color", _base_name_color.darkened(0.35))
		text_label.add_theme_color_override("default_color", _base_text_color.darkened(0.22))
	else:
		name_label.add_theme_color_override("font_color", _base_name_color)
		text_label.add_theme_color_override("default_color", _base_text_color)
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
		"CHAR_A": return "小A"
		"CHAR_B": return "小B"
		"CHAR_TEACHER": return "老师"
		"CHAR_MOTHER": return "妈妈"
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
	StoryManager.on_dialogue_finished()
