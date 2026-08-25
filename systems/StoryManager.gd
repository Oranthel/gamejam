extends Node

## 故事管理器：加载 JSON、驱动事件流程
## 新增（v2）：结局判定 / 侵蚀满值坏结局 / 心情结算 / 内心独白(os)
## 信号由 UI 层（DialogueBox/OptionBox/Act2 等）接收并展示

signal dialogue_requested(dialogues: Array)
signal option_requested(options: Array, event_id: String)
signal scene_change_requested(backgrounds: Array)
signal transition_requested(ui_elements: Array)
signal explore_started(notes: String)
signal minigame_requested(minigame_id: String, event: Dictionary)
signal item_get_requested(items: Array)
signal sleep_requested()
signal time_skip_requested(notes: String)
signal result_requested(data: Dictionary)
signal phone_call_requested(dialogues: Array)
signal interaction_requested(desc: String)
signal conditional_result_requested(condition: String, results: Array, player_choice: String)
signal day_changed(day_id: String, countdown: int)
signal meal_requested()
signal game_ended(ending_id: String)
signal ending_started(ending_id: String)

const STORY_PATH := "res://剧情JSON_主线版.json"
const BAD_ENDING_EVENT := "EV_END_BAD"

var story_data: Dictionary = {}
var event_map: Dictionary = {}  # event_id -> {event, day_idx, scene_idx}
var _current_event: Dictionary = {}

# 对话+选项复合事件支持
var _pending_options: Array = []
var _pending_option_event_id: String = ""
var _waiting_for_options: bool = false

# 结局流程状态
var _ending_locked: bool = false   # 一旦锁定（坏结局触发），不再推进任何事件
var _in_ending: bool = false


func _ready() -> void:
	GameState.erosion_maxed.connect(_on_erosion_maxed)
	_load_story()


func _load_story() -> void:
	var file := FileAccess.open(STORY_PATH, FileAccess.READ)
	if file == null:
		push_error("StoryManager: 无法加载剧情JSON: " + STORY_PATH)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("StoryManager: JSON解析失败 - " + json.get_error_message())
		return
	story_data = json.data
	_build_event_map()
	print("StoryManager: 剧情加载完成，共 %d 天" % story_data.get("days", []).size())


func _build_event_map() -> void:
	event_map.clear()
	for day_idx in range(story_data.get("days", []).size()):
		var day = story_data["days"][day_idx]
		for scene_idx in range(day.get("scenes", []).size()):
			var scene = day["scenes"][scene_idx]
			for event in scene.get("events", []):
				event_map[event["event_id"]] = {
					"event": event,
					"day_idx": day_idx,
					"scene_idx": scene_idx,
				}


## 侵蚀值满 → 立即触发坏结局（无视当前位置）
func _on_erosion_maxed() -> void:
	if _ending_locked:
		return
	_ending_locked = true
	_force_event(BAD_ENDING_EVENT)


func _force_event(event_id: String) -> void:
	if event_map.has(event_id):
		_process_event(event_map[event_id]["event"])


func start_day(day_id: String) -> void:
	for i in range(story_data.get("days", []).size()):
		var day = story_data["days"][i]
		if day.get("chapter_id") == day_id:
			GameState.current_day = day_id
			var countdown = day.get("exam_countdown", 0)
			GameState.exam_countdown = countdown
			day_changed.emit(day_id, countdown)
			var first_scene = day["scenes"][0]
			scene_change_requested.emit(first_scene.get("backgrounds", []))
			if first_scene.get("events", []).size() > 0:
				_process_event(first_scene["events"][0])
			return


func goto_event(event_id: String) -> void:
	if _ending_locked:
		return
	# 跨天跳转（如 "DAY_02"）
	if event_id.begins_with("DAY_"):
		start_day(event_id)
		return
	if event_map.has(event_id):
		var info = event_map[event_id]
		var event = info["event"]
		var current_info = event_map.get(_current_event.get("event_id", ""), {})
		if current_info.is_empty() or info["scene_idx"] != current_info.get("scene_idx", -1) or info["day_idx"] != current_info.get("day_idx", -1):
			var day = story_data["days"][info["day_idx"]]
			var scene = day["scenes"][info["scene_idx"]]
			scene_change_requested.emit(scene.get("backgrounds", []))
		_process_event(event)
	else:
		push_warning("StoryManager: 找不到事件 " + event_id)


func _process_event(event: Dictionary) -> void:
	_current_event = event
	var type = event.get("type", "")
	var event_id = event.get("event_id", "")
	print("StoryManager: 处理事件 %s (类型: %s)" % [event_id, type])

	# 事件级背景切换：事件带 background 字段时，先切背景再展示
	if event.has("background"):
		scene_change_requested.emit([str(event.get("background", ""))])

	# 处理"对话+选项"复合事件：先对话，后选项
	if event.has("dialogue") and event.has("options") and type == "dialogue":
		dialogue_requested.emit(event.get("dialogue", []))
		_pending_options = event.get("options", [])
		_pending_option_event_id = event_id
		_waiting_for_options = true
		return

	match type:
		"dialogue", "dialogue_ui", "interactive_prompt":
			dialogue_requested.emit(event.get("dialogue", []))

		"option":
			GameState.mark_option_seen(event_id)
			option_requested.emit(event.get("options", []), event_id)

		"transition":
			transition_requested.emit(event.get("ui", []))

		"explore":
			explore_started.emit(event.get("notes", ""))

		"minigame":
			minigame_requested.emit(event.get("minigame", ""), event)

		"item_get":
			item_get_requested.emit(event.get("items", []))

		"sleep":
			# 一天结束：先结算心情 → 再进入睡觉演出
			GameState.settle_mood()
			sleep_requested.emit()

		"sleep_time_skip":
			sleep_requested.emit()

		"time_skip":
			time_skip_requested.emit(event.get("notes", ""))

		"result":
			result_requested.emit(event.get("scoreboard", {}))

		"conditional_result":
			var condition = event.get("condition", "")
			var results = event.get("results", [])
			var player_choice = GameState.get_choice_by_condition(condition)
			conditional_result_requested.emit(condition, results, player_choice)

		"phone_call":
			phone_call_requested.emit(event.get("dialogue", []))

		"interaction":
			interaction_requested.emit(event.get("interaction", ""))

		"conditional_event":
			var condition_name = event.get("condition", "")
			var condition_met = GameState.get_flag(condition_name)
			if not condition_met:
				var choice = GameState.get_choice_by_condition(condition_name)
				if choice != "":
					condition_met = true
			GameState.set_flag(condition_name + "_checked", condition_met)
			advance()

		"choice_goto":
			# 按玩家之前的选项跳转到对应事件（branches: option_id -> event_id）
			var cond: String = event.get("condition", "")
			var branches: Dictionary = event.get("branches", {})
			var choice: String = GameState.get_choice_by_condition(cond)
			var target: String = branches.get(choice, event.get("default", ""))
			if target != "":
				goto_event(target)
			else:
				advance()

		"meal":
			meal_requested.emit()

		"bg":
			# 显式背景切换事件：切背景后立即继续（等价于给事件加 background 字段）
			scene_change_requested.emit([str(event.get("background", ""))])
			advance()

		"ending_check":
			_do_ending_check()

		"ending":
			_in_ending = true
			ending_started.emit(event_id)
			dialogue_requested.emit(event.get("dialogue", []))

		_:
			advance()


## 结局分岔：坏结局优先，然后按能力值二分好结局
func _do_ending_check() -> void:
	var target := "EV_END_SELF"
	if GameState.erosion >= GameState.EROSION_MAX:
		target = "EV_END_BAD"
	elif GameState.ability >= GameState.ABILITY_UP_THRESHOLD:
		target = "EV_END_UP"
	goto_event(target)


## UI 层调用：当前事件完成，进入 next
func advance(next_id: String = "") -> void:
	if _ending_locked:
		return
	var target = next_id if next_id != "" else _current_event.get("next", "")
	if target != "":
		goto_event(target)
	else:
		_goto_next_in_scene()


func _goto_next_in_scene() -> void:
	var event_id = _current_event.get("event_id", "")
	if event_id == "" or not event_map.has(event_id):
		return
	var info = event_map[event_id]
	var day = story_data["days"][info["day_idx"]]
	var scene = day["scenes"][info["scene_idx"]]
	var events = scene.get("events", [])
	for i in range(events.size()):
		if events[i].get("event_id") == event_id and i + 1 < events.size():
			_process_event(events[i + 1])
			return
	if info["scene_idx"] + 1 < day["scenes"].size():
		var next_scene = day["scenes"][info["scene_idx"] + 1]
		scene_change_requested.emit(next_scene.get("backgrounds", []))
		if next_scene.get("events", []).size() > 0:
			_process_event(next_scene["events"][0])
	else:
		if info["day_idx"] + 1 < story_data["days"].size():
			var next_day_id = story_data["days"][info["day_idx"] + 1]["chapter_id"]
			start_day(next_day_id)


## 选项被选中后调用
func on_option_selected(option: Dictionary) -> void:
	GameState.apply_effects(option.get("effects", {}))
	if _ending_locked:
		return
	GameState.record_choice(_current_event.get("event_id", ""), option.get("option_id", ""))
	var next = option.get("next", "")
	if next != "":
		goto_event(next)
	else:
		advance()


## 对话完成后调用（检查是否有待显示的选项）
func on_dialogue_finished() -> void:
	if _waiting_for_options and _pending_options.size() > 0:
		_waiting_for_options = false
		var options = _pending_options
		var event_id = _pending_option_event_id
		_pending_options = []
		_pending_option_event_id = ""
		GameState.mark_option_seen(event_id)
		option_requested.emit(options, event_id)
		return
	if _in_ending:
		_in_ending = false
		game_ended.emit(_current_event.get("event_id", ""))
		return
	advance()


func get_current_event_id() -> String:
	return _current_event.get("event_id", "")


## 读档续玩：恢复天数 + 跳转到指定事件
func resume(day_id: String, event_id: String) -> void:
	if day_id != "":
		GameState.current_day = day_id
		GameState.exam_countdown = _countdown_of(day_id)
		day_changed.emit(day_id, GameState.exam_countdown)
	if event_id != "":
		goto_event(event_id)


func _countdown_of(day_id: String) -> int:
	for i in range(story_data.get("days", []).size()):
		var day = story_data["days"][i]
		if day.get("chapter_id") == day_id:
			return int(day.get("exam_countdown", 0))
	return 70
