extends Node2D

## Day1-Day3 剧情场景
## 接收 StoryManager 信号，控制背景切换、转场、探索等

## 背景图映射：background_id → 资源路径（用户自行填充）
@export var bg_map: Dictionary = {
	"BG_START_DESK": "res://art/场景/BG_START_DESK.png",
	"BG_DORM_DOOR": "res://art/场景/BG_DORM_DOOR.png",
	"BG_STUDIO_MAP": "res://art/场景/BG_STUDIO_MAP.png",
	"BG_STUDIO": "res://art/场景/BG_STUDIO.png",
	"BG_EASEL_VIEW": "res://art/场景/BG_EASEL_VIEW.png",
	"BG_DINING_TABLE": "res://art/场景/BG_DINING_TABLE.png",
	"BG_DORM_MAP": "res://art/场景/BG_DORM_MAP.png",
	"BG_STUDIO_CORRIDOR": "res://art/场景/BG_STUDIO_CORRIDOR.png",
	# 水房/超市暂无图：用画室图替代
	"BG_WATER_ROOM": "res://art/场景/BG_STUDIO.png",
	"BG_SUPERMARKET": "res://art/场景/BG_STUDIO.png",
	"BG_ELEVATOR": "res://art/场景/BG_ELEVATOR.png",
	"BG_END_BAD": "res://art/场景/BG_END_BAD.png",
	"BG_END_UP": "res://art/场景/BG_END_UP.png",
	"BG_END_SELF": "res://art/场景/BG_END_SELF.png",
}
const PLACEHOLDER_BG := "res://art/待定图.png"

@onready var background: Sprite2D = $Background
@onready var transition_label: Label = $TransitionLayer/TransitionLabel


func _ready() -> void:
	# 连接 StoryManager 信号
	StoryManager.scene_change_requested.connect(_on_scene_change)
	StoryManager.transition_requested.connect(_on_transition)
	StoryManager.explore_started.connect(_on_explore)
	StoryManager.minigame_requested.connect(_on_minigame)
	StoryManager.sleep_requested.connect(_on_sleep)
	StoryManager.time_skip_requested.connect(_on_time_skip)
	StoryManager.day_changed.connect(_on_day_changed)
	StoryManager.result_requested.connect(_on_result)
	StoryManager.item_get_requested.connect(_on_item_get)
	StoryManager.interaction_requested.connect(_on_interaction)
	StoryManager.conditional_result_requested.connect(_on_conditional_result)
	StoryManager.meal_requested.connect(_on_meal)
	StoryManager.ending_started.connect(_on_ending_started)
	StoryManager.game_ended.connect(_on_game_ended)
	$EndingLayer/Panel/VBox/ReturnBtn.pressed.connect(_on_return_title)

	transition_label.visible = false
	ErosionTheme.stage_changed.connect(_apply_erosion_theme)
	_apply_erosion_theme(ErosionTheme.stage)

	# 转场/公布文字的淡灰径向渐变底板
	_setup_transition_backdrop()

	# 日常 BGM（结局时在 _on_ending_started 里切换）
	AudioManager.play_bgm(AudioManager.BGM_DAILY)

	# 启动剧情：读档续玩 or 新游戏
	if SaveManager.resume_event_id != "":
		var ev: String = SaveManager.resume_event_id
		var day: String = SaveManager.resume_day
		SaveManager.clear_resume()
		StoryManager.resume(day, ev)
	else:
		StoryManager.start_day("DAY_01")


func _apply_erosion_theme(_stage: int) -> void:
	background.modulate = ErosionTheme.get_color("bg_modulate")


func _setup_transition_backdrop() -> void:
	# 淡灰径向渐变底板：中心不透明 → 边缘全透明，垫在转场/公布文字下方
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([
		Color(0.14, 0.14, 0.17, 0.72),
		Color(0.14, 0.14, 0.17, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)

	var backdrop := TextureRect.new()
	backdrop.texture = tex
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.show_behind_parent = true
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.offset_left = -120.0
	backdrop.offset_top = -80.0
	backdrop.offset_right = 120.0
	backdrop.offset_bottom = 80.0
	transition_label.add_child(backdrop)


func _on_game_ended(ending_id: String) -> void:
	var name: String = "未知"
	match ending_id:
		"EV_END_UP": name = "金榜题名"
		"EV_END_SELF": name = "芸芸众生"
		"EV_END_BAD": name = "黄粱一梦"
	$EndingLayer/Panel/VBox/EndingName.text = "你获得了「" + name + "」结局"
	$EndingLayer.visible = true


func _on_return_title() -> void:
	get_tree().change_scene_to_file("res://menu/MainMenu.tscn")


func _on_ending_started(ending_id: String) -> void:
	var p := get_node_or_null("Portrait")
	if p:
		p.visible = false
	# 结局音乐：金榜题名单独一首；芸芸众生/黄粱一梦共用一首
	match ending_id:
		"EV_END_UP":
			AudioManager.play_bgm(AudioManager.BGM_END_UP)
		"EV_END_SELF", "EV_END_BAD":
			AudioManager.play_bgm(AudioManager.BGM_END_DOWN)


func _on_scene_change(backgrounds: Array) -> void:
	if backgrounds.is_empty():
		return
	var tex := _load_bg(backgrounds[0])
	if tex:
		_apply_background(tex)


func _load_bg(bg_id: String) -> Texture2D:
	# 先取配置路径，去掉扩展名后按 png/jpg/jpeg/webp 自动匹配
	var base: String = bg_map.get(bg_id, "")
	if base == "":
		base = "res://art/场景/" + bg_id
	else:
		base = base.get_basename()
	for ext in [".png", ".jpg", ".jpeg", ".webp"]:
		if ResourceLoader.exists(base + ext):
			return load(base + ext)
	if ResourceLoader.exists(PLACEHOLDER_BG):
		print("Act2: 背景未配置 %s，使用待定图" % bg_id)
		return load(PLACEHOLDER_BG)
	return null


func _apply_background(tex: Texture2D) -> void:
	background.texture = tex
	background.centered = false
	background.position = Vector2.ZERO
	var ts := tex.get_size()
	var vs := get_viewport_rect().size
	if ts.x > 0 and ts.y > 0:
		var s: float = max(vs.x / ts.x, vs.y / ts.y)
		background.scale = Vector2(s, s)


func _on_transition(ui_elements: Array) -> void:
	# 显示转场文字
	if ui_elements.size() > 0:
		transition_label.text = "\n".join(ui_elements)
		transition_label.visible = true
		# 2秒后自动继续
		await get_tree().create_timer(2.0).timeout
		transition_label.visible = false
		StoryManager.advance()
	else:
		StoryManager.advance()


func _on_explore(notes: String) -> void:
	# 探索模式：显示提示，等待玩家点击继续
	transition_label.text = "探索模式\n" + notes + "\n\n（点击继续）"
	transition_label.visible = true
	await get_tree().create_timer(2.0).timeout
	transition_label.visible = false
	StoryManager.advance()


func _on_minigame(minigame_id: String, event: Dictionary) -> void:
	print("Act2: 小游戏 %s（待实现，自动跳过）" % minigame_id)
	StoryManager.advance()


func _on_sleep() -> void:
	transition_label.text = "……睡觉……"
	transition_label.visible = true
	await get_tree().create_timer(2.0).timeout
	transition_label.visible = false
	StoryManager.advance()


func _on_time_skip(notes: String) -> void:
	transition_label.text = "时间流逝……\n" + notes
	transition_label.visible = true
	await get_tree().create_timer(2.0).timeout
	transition_label.visible = false
	StoryManager.advance()


func _on_day_changed(day_id: String, countdown: int) -> void:
	print("Act2: 进入 %s，距离联考 %d 天" % [day_id, countdown])


func _on_result(data: Dictionary) -> void:
	var text = "成绩公布\n"
	if data.has("score"):
		text += "分数：%s\n" % str(int(data["score"]))
	if data.has("rank"):
		text += "排名：第 %s 名\n" % str(int(data["rank"]))
	transition_label.text = text
	transition_label.visible = true
	await get_tree().create_timer(3.0).timeout
	transition_label.visible = false
	StoryManager.advance()


func _on_item_get(items: Array) -> void:
	print("Act2: 获得物品 %s" % str(items))
	StoryManager.advance()


func _on_interaction(desc: String) -> void:
	transition_label.text = desc
	transition_label.visible = true
	await get_tree().create_timer(3.0).timeout
	transition_label.visible = false
	StoryManager.advance()


func _on_conditional_result(condition: String, results: Array, player_choice: String) -> void:
	# 条件结果：根据玩家之前的选择显示不同结果
	if results.is_empty():
		# 条件事件（conditional_event），没有结果要显示，直接跳过
		StoryManager.advance()
		return
	var text = ""
	for r in results:
		if r.get("if", "") == player_choice:
			text = r.get("result", "")
			break
	if text == "":
		# 未找到匹配结果，显示默认
		text = "（结果待定）"
	transition_label.text = text
	transition_label.visible = true
	await get_tree().create_timer(3.0).timeout
	transition_label.visible = false
	StoryManager.advance()


func _on_meal() -> void:
	# 吃饭/泡面流程
	transition_label.text = "吃饭中……"
	transition_label.visible = true
	await get_tree().create_timer(2.0).timeout
	transition_label.visible = false
	StoryManager.advance()
