extends Node

## 全局游戏状态：侵蚀值 / 心情值 / 能力值
## ============================================================
## 决策（已锁定，改数值改这里）：
##   侵蚀值 == 压力值：压力类选项直接增加侵蚀值
##   满值 100，初始 10；达到 100 立即触发坏结局（erosion_maxed 信号）
##   心情值 初始 0，范围 -10 ~ 10；每天结束结算：
##       心情为正 → 减少侵蚀；心情为负 → 增加侵蚀
##   能力值 初始 5，范围 0 ~ 30；结局判定「上岸」用
## ============================================================

signal erosion_maxed                     # 侵蚀值达到满值，立即触发坏结局
signal values_changed(erosion: int, mood: int, ability: int)

const EROSION_START := 10
const EROSION_MAX := 70
const MOOD_MIN := -10
const MOOD_MAX := 10
const ABILITY_START := 5
const ABILITY_MIN := 0
const ABILITY_MAX := 30
# 结局判定：能力值 >= 该值 → 「上岸」结局（否则「初心」结局）
const ABILITY_UP_THRESHOLD := 22

var erosion: int = EROSION_START
var mood: int = 0
var ability: int = ABILITY_START
var exam_countdown: int = 70   # 距离联考天数（驱动侵蚀 UI 档位）

var current_day: String = ""
var chosen_options: Dictionary = {}   # event_id -> option_id
var inventory_items: Array[String] = []
var flags: Dictionary = {}
var dialogue_history: Array = []   # 本局对话历史（回看用）
var seen_options: Array = []        # 已见过的选项组（剧情树解锁用）


func apply_effects(effects: Dictionary) -> void:
	var e := int(effects.get("erosion", 0))
	var m := int(effects.get("mood", 0))
	var a := int(effects.get("ability", 0))
	# 兼容旧字段：旧 JSON 里的 "stress" 视为侵蚀值
	if effects.has("stress"):
		e += int(effects["stress"])
	erosion = clampi(erosion + e, 0, EROSION_MAX)
	mood = clampi(mood + m, MOOD_MIN, MOOD_MAX)
	ability = clampi(ability + a, ABILITY_MIN, ABILITY_MAX)
	values_changed.emit(erosion, mood, ability)
	if erosion >= EROSION_MAX:
		erosion_maxed.emit()


## 每天/阶段结束时结算：心情正→减侵蚀，心情负→增侵蚀
func settle_mood() -> void:
	erosion = clampi(erosion - mood, 0, EROSION_MAX)
	mood = 0   # 心情每天归零，不跨天累计
	values_changed.emit(erosion, mood, ability)
	if erosion >= EROSION_MAX:
		erosion_maxed.emit()


func record_choice(event_id: String, option_id: String) -> void:
	chosen_options[event_id] = option_id


func get_choice(event_id: String) -> String:
	return chosen_options.get(event_id, "")


## 根据 condition 名查找对应选项（精确映射表）
var condition_map: Dictionary = {
	"rest_choice": {
		"DAY_01": "EV_D01_REST_CHOICE",
		"DAY_02": "EV_D02_REST_CHOICE",
	},
	"morning_choice": {
		"DAY_02": "EV_D02_MORNING_CHOICE",
	},
	"teacher_catches_phone": {
		"DAY_01": "EV_D01_WECHAT",
	},
	"phone_check": {
		"DAY_01": "EV_D01_WECHAT",
	},
	"move_choice": {
		"DAY_07": "EV_D07_MOVE_CHOICE",
	},
}


func get_choice_by_condition(condition: String) -> String:
	if chosen_options.has(condition):
		return chosen_options[condition]
	if condition_map.has(condition):
		var day_map = condition_map[condition]
		if day_map.has(current_day):
			var mapped_event = day_map[current_day]
			if chosen_options.has(mapped_event):
				return chosen_options[mapped_event]
		for day_key in day_map.keys():
			var mapped_event = day_map[day_key]
			if chosen_options.has(mapped_event):
				return chosen_options[mapped_event]
	var with_prefix = "EV_" + condition
	if chosen_options.has(with_prefix):
		return chosen_options[with_prefix]
	return ""


func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value


func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func add_item(item_id: String) -> void:
	if item_id not in inventory_items:
		inventory_items.append(item_id)


func mark_option_seen(event_id: String) -> void:
	if event_id != "" and event_id not in seen_options:
		seen_options.append(event_id)


func reset() -> void:
	erosion = EROSION_START
	mood = 0
	ability = ABILITY_START
	exam_countdown = 70
	current_day = ""
	chosen_options.clear()
	inventory_items.clear()
	flags.clear()
	dialogue_history.clear()
	seen_options.clear()
