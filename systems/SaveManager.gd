extends Node

## 存档/读档：3 个存档位，每位保存 数值 + 天数 + 当前事件 + 选项 + flags + 时间戳

const SLOT_COUNT := 3

var resume_event_id: String = ""
var resume_day: String = ""


func _slot_path(slot: int) -> String:
	return "user://save_%d.json" % slot


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func save_game(slot: int, event_id: String) -> void:
	var data := {
		"erosion": GameState.erosion,
		"mood": GameState.mood,
		"ability": GameState.ability,
		"exam_countdown": GameState.exam_countdown,
		"current_day": GameState.current_day,
		"event_id": event_id,
		"chosen_options": GameState.chosen_options,
		"flags": GameState.flags,
		"seen_options": GameState.seen_options,
		"timestamp": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func load_game(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data


func get_slot_info(slot: int) -> Dictionary:
	var d := load_game(slot)
	if d.is_empty():
		return {}
	return {
		"countdown": int(d.get("exam_countdown", 0)),
		"day": d.get("current_day", ""),
	}


## 返回最近一次存档的档位号（1~3），无存档返回 -1
func most_recent_slot() -> int:
	var best := -1
	var best_ts := -1.0
	for i in range(1, SLOT_COUNT + 1):
		var d := load_game(i)
		if d.is_empty():
			continue
		var ts := float(d.get("timestamp", 0.0))
		if ts > best_ts:
			best_ts = ts
			best = i
	return best


func apply_loaded(data: Dictionary) -> void:
	GameState.erosion = int(data.get("erosion", GameState.EROSION_START))
	GameState.mood = int(data.get("mood", 0))
	GameState.ability = int(data.get("ability", GameState.ABILITY_START))
	GameState.exam_countdown = int(data.get("exam_countdown", 70))
	GameState.current_day = data.get("current_day", "")
	GameState.chosen_options = data.get("chosen_options", {})
	GameState.flags = data.get("flags", {})
	GameState.seen_options = data.get("seen_options", [])
	resume_event_id = data.get("event_id", "")
	resume_day = GameState.current_day
	GameState.values_changed.emit(GameState.erosion, GameState.mood, GameState.ability)


func clear_resume() -> void:
	resume_event_id = ""
	resume_day = ""


func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_slot_path(slot))


## 存档位显示文案（主界面「继续」弹窗 和 游戏内菜单共用）
func get_slot_label(slot: int) -> String:
	var info := get_slot_info(slot)
	if info.is_empty():
		return "存档位 %d · 空" % slot
	return "存档位 %d · 距离联考 %d 天%s" % [slot, info.get("countdown", 0), _day_suffix(info.get("day", ""))]


func _day_suffix(day: String) -> String:
	if day == "":
		return ""
	var n := 0
	match day:
		"DAY_01": n = 1
		"DAY_02": n = 2
		"DAY_03": n = 3
		"DAY_04": n = 4
		"DAY_05": n = 5
		"DAY_06": n = 6
		"ENDINGS": return " · 结局"
	if n > 0:
		return " · 第%d天" % n
	return ""
