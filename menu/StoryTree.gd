extends Control

## 剧情树页面：文字树状（从剧情 JSON 自动生成章节 + 分支选项 + 结局）


func _ready() -> void:
	$BackBtn.pressed.connect(_on_back)
	$ResetBtn.pressed.connect(_on_reset)
	$BackBtn.grab_focus()
	$Scroll/Body.text = _build_tree()


func _build_tree() -> String:
	var sb: String = ""
	sb += "[b][color=#e8d8a8]主线流程[/color][/b]\n"
	for day in StoryManager.story_data.get("days", []):
		var cid: String = day.get("chapter_id", "")
		if cid == "ENDINGS":
			continue
		var cd: int = int(day.get("exam_countdown", 0))
		sb += "   " + cid + " · 距离联考 " + str(cd) + " 天\n"
	sb += "   → 离开画室 → 结局\n\n"

	sb += "[b][color=#e8d8a8]分支选项[/color][/b]\n"
	for day in StoryManager.story_data.get("days", []):
		var cid: String = day.get("chapter_id", "")
		if cid == "ENDINGS":
			continue
		for scene in day.get("scenes", []):
			for ev in scene.get("events", []):
				if ev.get("type", "") != "option":
					continue
				var opts: Array = ev.get("options", [])
				if opts.size() <= 1:
					continue
				var eid: String = ev.get("event_id", "")
				if eid not in GameState.seen_options:
					sb += "   " + cid + "：？？？\n"
					continue
				var parts := ""
				for o in opts:
					if parts != "":
						parts += "  /  "
					parts += o.get("text", "")
				sb += "   " + cid + "：" + parts + "\n"

	sb += "\n[b][color=#e8d8a8]结局[/color][/b]\n"
	sb += "   [color=#ffd980]金榜题名[/color] · 能力 ≥ " + str(GameState.ABILITY_UP_THRESHOLD) + "\n"
	sb += "   [color=#c0d8ff]芸芸众生[/color] · 能力 < " + str(GameState.ABILITY_UP_THRESHOLD) + "\n"
	sb += "   [color=#ff8a8a]黄粱一梦[/color] · 侵蚀 = " + str(GameState.EROSION_MAX) + "\n"
	return sb


func _on_back() -> void:
	get_tree().change_scene_to_file("res://menu/MainMenu.tscn")


func _on_reset() -> void:
	GameState.seen_options.clear()
	$Scroll/Body.text = _build_tree()
