extends Control

## 主界面：开始 / 继续 / 剧情树 / 退出


func _ready() -> void:
	# 开头 BGM（跨场景持续播放）
	AudioManager.play_bgm(AudioManager.BGM_OPENING)
	_apply_cover()
	_add_sketch_frame($VBox/StartBtn, 0.0, 11)
	_add_sketch_frame($VBox/ContinueBtn, 1.04, 22)
	_add_sketch_frame($VBox/TreeBtn, 2.08, 33)
	_add_sketch_frame($VBox/QuitBtn, 3.12, 44)
	$VBox/StartBtn.pressed.connect(_on_start)
	$VBox/ContinueBtn.pressed.connect(_on_continue)
	$VBox/TreeBtn.pressed.connect(_on_tree)
	$VBox/QuitBtn.pressed.connect(_on_quit)
	# 无存档时禁用「继续」
	$VBox/ContinueBtn.disabled = SaveManager.most_recent_slot() < 1
	# 读档弹窗
	$LoadPopup/LVBox/Slot1.pressed.connect(_on_load_slot.bind(1))
	$LoadPopup/LVBox/Slot2.pressed.connect(_on_load_slot.bind(2))
	$LoadPopup/LVBox/Slot3.pressed.connect(_on_load_slot.bind(3))
	$LoadPopup/LVBox/BackBtn.pressed.connect(_on_close_load)
	# 悬停音效
	$VBox/StartBtn.mouse_entered.connect(_play_hover)
	$VBox/ContinueBtn.mouse_entered.connect(_play_hover)
	$VBox/TreeBtn.mouse_entered.connect(_play_hover)
	$VBox/QuitBtn.mouse_entered.connect(_play_hover)
	$LoadPopup/LVBox/Slot1.mouse_entered.connect(_play_hover)
	$LoadPopup/LVBox/Slot2.mouse_entered.connect(_play_hover)
	$LoadPopup/LVBox/Slot3.mouse_entered.connect(_play_hover)
	$LoadPopup/LVBox/BackBtn.mouse_entered.connect(_play_hover)


func _apply_cover() -> void:
	var tex: Texture2D = null
	for ext in [".png", ".jpg", ".jpeg", ".webp"]:
		if ResourceLoader.exists("res://art/封面" + ext):
			tex = load("res://art/封面" + ext)
			break
	if tex == null:
		return
	var cover := TextureRect.new()
	cover.texture = tex
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_child(cover, 1)


func _add_sketch_frame(node: Control, phase: float, seed: int) -> void:
	var sl := ErosionSketchLines.new()
	# 按钮不是容器，直接加为子节点即可铺满该按钮区域
	node.add_child(sl)
	sl.shade_override = 0.62   # 按钮框色变白约 30%（越小越深，可调）
	sl.width_scale = 0.81      # 线再细 10%
	sl.phase_offset = phase    # 各按钮错开相位，节奏不同
	sl.rng_seed = seed         # 各按钮不同随机种子，样式不同
	sl.cycle_seconds = 4.16    # 节奏放慢 30%（原 3.2s）
	sl.set_active.call_deferred(true)


func _on_start() -> void:
	AudioManager.play_sfx(AudioManager.SFX_CLICK)
	GameState.reset()
	SaveManager.clear_resume()
	get_tree().change_scene_to_file("res://intro/Intro.tscn")


func _on_continue() -> void:
	AudioManager.play_sfx(AudioManager.SFX_CLICK)
	_refresh_load_slots()
	$LoadPopup.popup_centered()


func _refresh_load_slots() -> void:
	for i in range(1, 4):
		var btn: Button = $LoadPopup/LVBox.get_node("Slot" + str(i))
		btn.text = SaveManager.get_slot_label(i)
		btn.disabled = not SaveManager.has_save(i)


func _on_load_slot(slot: int) -> void:
	AudioManager.play_sfx(AudioManager.SFX_CLICK)
	var data := SaveManager.load_game(slot)
	if data.is_empty():
		return
	$LoadPopup.hide()
	SaveManager.apply_loaded(data)
	get_tree().change_scene_to_file("res://act2/Act2.tscn")


func _on_close_load() -> void:
	AudioManager.play_sfx(AudioManager.SFX_CLICK)
	$LoadPopup.hide()


func _on_tree() -> void:
	AudioManager.play_sfx(AudioManager.SFX_CLICK)
	get_tree().change_scene_to_file("res://menu/StoryTree.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _play_hover() -> void:
	AudioManager.play_sfx(AudioManager.SFX_HOVER)
