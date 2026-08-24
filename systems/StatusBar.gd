extends CanvasLayer
class_name StatusBar

## 顶部状态栏：天数 + 三值 + 数值飘字 + 菜单（3存档位）+ 历史回看

@onready var panel: Panel = $Panel
@onready var day_label: Label = $Panel/Margin/HBox/DayLabel
@onready var erosion_bar: ProgressBar = $Panel/Margin/HBox/ErosionBar
@onready var erosion_label: Label = $Panel/Margin/HBox/ErosionLabel
@onready var mood_label: Label = $Panel/Margin/HBox/MoodLabel
@onready var ability_label: Label = $Panel/Margin/HBox/AbilityLabel
@onready var menu_btn: Button = $Panel/Margin/HBox/MenuBtn
@onready var history_btn: Button = $Panel/Margin/HBox/HistoryBtn
@onready var menu_popup: PopupPanel = $MenuPopup
@onready var history_popup: PopupPanel = $HistoryPopup

var _sketch_lines: ErosionSketchLines
var _prev_erosion: int = -999
var _prev_mood: int = -999
var _prev_ability: int = -999
var _save_mode: bool = true   # true=存档模式, false=读档模式
var _delete_mode: bool = false


func _ready() -> void:
	_sketch_lines = ErosionSketchLines.new()
	panel.add_child(_sketch_lines)
	ErosionTheme.stage_changed.connect(_apply_theme)
	_apply_theme(ErosionTheme.stage)
	GameState.values_changed.connect(_on_values_changed)
	StoryManager.day_changed.connect(_on_day_changed)
	_prev_erosion = GameState.erosion
	_prev_mood = GameState.mood
	_prev_ability = GameState.ability
	_refresh()
	# 顶部按钮
	menu_btn.pressed.connect(_open_menu)
	history_btn.pressed.connect(_open_history)
	# 菜单按钮
	$MenuPopup/VBox/ModeBox/SaveModeBtn.pressed.connect(_on_mode.bind(true))
	$MenuPopup/VBox/ModeBox/LoadModeBtn.pressed.connect(_on_mode.bind(false))
	$MenuPopup/VBox/ModeBox/DeleteModeBtn.pressed.connect(_on_delete_mode)
	$MenuPopup/VBox/Slot1.pressed.connect(_on_slot.bind(1))
	$MenuPopup/VBox/Slot2.pressed.connect(_on_slot.bind(2))
	$MenuPopup/VBox/Slot3.pressed.connect(_on_slot.bind(3))
	$MenuPopup/VBox/TitleBtn.pressed.connect(_to_title)
	$MenuPopup/VBox/CloseBtn.pressed.connect(func(): AudioManager.play_sfx(AudioManager.SFX_CLICK); menu_popup.hide())
	# 历史回看
	$HistoryPopup/HVBox/CloseBtn2.pressed.connect(func(): AudioManager.play_sfx(AudioManager.SFX_CLICK); history_popup.hide())
	# 菜单/回看按钮加宽 10%（等首帧布局完成后再量实际宽度）
	call_deferred("_widen_top_buttons")


func _apply_theme(_stage: int) -> void:
	panel.add_theme_stylebox_override("panel", ErosionTheme.get_panel_stylebox("bar", "status_bg"))
	_sketch_lines.set_active(_stage == 4)
	var ink: Color = ErosionTheme.get_color("dialog_text")
	day_label.add_theme_color_override("font_color", ink)
	erosion_label.add_theme_color_override("font_color", ink)
	mood_label.add_theme_color_override("font_color", ink)
	ability_label.add_theme_color_override("font_color", ink)
	menu_btn.add_theme_color_override("font_color", ink)
	history_btn.add_theme_color_override("font_color", ink)
	_apply_button_theme(menu_btn)
	_apply_button_theme(history_btn)


func _apply_button_theme(btn: Button) -> void:
	# 顶部「菜单/回看」按钮跟随 5 档侵蚀主题，避免默认黑按钮在浅色档里突兀
	var bg: Color = ErosionTheme.get_color("option_bg")
	var border: Color = ErosionTheme.get_color("dialog_border")
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _widen_top_buttons() -> void:
	for btn in [menu_btn, history_btn]:
		var base: float = btn.size.x
		if base > 0.0:
			btn.custom_minimum_size.x = base * 1.2


func _on_day_changed(_day_id: String, countdown: int) -> void:
	day_label.text = "距离联考 %d 天" % countdown


func _on_values_changed(erosion: int, mood: int, ability: int) -> void:
	if _prev_erosion != -999 and erosion != _prev_erosion:
		_spawn_float("侵蚀 " + _signed(erosion - _prev_erosion), _erosion_color(erosion - _prev_erosion), erosion_label)
	if _prev_mood != -999 and mood != _prev_mood:
		_spawn_float("心情 " + _signed(mood - _prev_mood), _good_color(mood - _prev_mood), mood_label)
	if _prev_ability != -999 and ability != _prev_ability:
		_spawn_float("能力 " + _signed(ability - _prev_ability), _good_color(ability - _prev_ability), ability_label)
	_prev_erosion = erosion
	_prev_mood = mood
	_prev_ability = ability
	_refresh()


func _refresh() -> void:
	erosion_bar.value = GameState.erosion
	erosion_label.text = "侵蚀 %d/100" % GameState.erosion
	var mood_text: String = ("+" if GameState.mood >= 0 else "") + str(GameState.mood)
	mood_label.text = "心情 " + mood_text
	ability_label.text = "能力 %d" % GameState.ability


func _signed(d: int) -> String:
	return ("+" if d >= 0 else "") + str(d)


func _good_color(delta: int) -> Color:
	return Color(0.45, 0.95, 0.45) if delta > 0 else Color(1, 0.4, 0.4)


func _erosion_color(delta: int) -> Color:
	return Color(1, 0.4, 0.4) if delta > 0 else Color(0.45, 0.95, 0.45)


func _spawn_float(text: String, color: Color, anchor: Control) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.z_index = 20
	add_child(lbl)
	lbl.position = anchor.global_position + Vector2(0, 30)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 46.0, 0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(lbl.queue_free)


# ===== 菜单（3 存档位） =====

func _open_menu() -> void:
	AudioManager.play_sfx(AudioManager.SFX_CLICK)
	_refresh_slots()
	menu_popup.popup_centered()


func _on_mode(save_mode: bool) -> void:
	AudioManager.play_sfx(AudioManager.SFX_CLICK)
	_save_mode = save_mode
	_delete_mode = false
	$MenuPopup/VBox/ModeBox/SaveModeBtn.button_pressed = save_mode
	$MenuPopup/VBox/ModeBox/LoadModeBtn.button_pressed = not save_mode
	$MenuPopup/VBox/ModeBox/DeleteModeBtn.button_pressed = false
	_refresh_slots()


func _on_delete_mode() -> void:
	AudioManager.play_sfx(AudioManager.SFX_CLICK)
	_save_mode = false
	_delete_mode = true
	$MenuPopup/VBox/ModeBox/SaveModeBtn.button_pressed = false
	$MenuPopup/VBox/ModeBox/LoadModeBtn.button_pressed = false
	$MenuPopup/VBox/ModeBox/DeleteModeBtn.button_pressed = true
	_refresh_slots()


func _refresh_slots() -> void:
	for i in range(1, 4):
		var btn: Button = $MenuPopup/VBox.get_node("Slot" + str(i))
		btn.text = SaveManager.get_slot_label(i)


func _on_slot(slot: int) -> void:
	AudioManager.play_sfx(AudioManager.SFX_CLICK)
	if _delete_mode:
		SaveManager.delete_save(slot)
		print("已删除 位%d" % slot)
		_refresh_slots()
	elif _save_mode:
		SaveManager.save_game(slot, StoryManager.get_current_event_id())
		print("已存档到 位%d" % slot)
		_refresh_slots()
	else:
		var data := SaveManager.load_game(slot)
		if data.is_empty():
			return
		menu_popup.hide()
		SaveManager.apply_loaded(data)
		StoryManager.resume(SaveManager.resume_day, SaveManager.resume_event_id)
		SaveManager.clear_resume()


func _to_title() -> void:
	AudioManager.play_sfx(AudioManager.SFX_CLICK)
	menu_popup.hide()
	get_tree().change_scene_to_file("res://menu/MainMenu.tscn")


# ===== 历史回看 =====

func _open_history() -> void:
	AudioManager.play_sfx(AudioManager.SFX_CLICK)
	var body: RichTextLabel = $HistoryPopup/HVBox/Scroll/Body
	body.add_theme_color_override("default_color", Color(0.95, 0.95, 0.95))
	body.text = _build_history_text()
	history_popup.popup_centered()


func _build_history_text() -> String:
	var sb: String = ""
	for entry in GameState.dialogue_history:
		var nm: String = entry.get("name", "")
		var tx: String = entry.get("text", "")
		var is_os: bool = entry.get("os", false)
		if is_os:
			sb += "[i][color=#9fb6d0]内心：" + tx + "[/color][/i]\n"
		else:
			sb += "[b][color=#ffffff]" + nm + "[/color][/b]：" + tx + "\n"
	return sb
