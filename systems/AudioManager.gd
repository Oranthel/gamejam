extends Node

## 全局音频管理器（autoload，跨场景持续播放）
## 用法：
##   AudioManager.play_bgm(AudioManager.BGM_OPENING)   # 循环背景音乐（带淡入）
##   AudioManager.play_sfx(AudioManager.SFX_CLICK)     # 点击音效
##   AudioManager.play_sfx(AudioManager.SFX_HOVER)     # 悬停音效
## 换曲时交叉过渡：新曲淡入 3s，旧曲淡出 5s 后停止；同名 BGM 自动跳过（不重播）。

# ===== BGM 曲目 =====
const BGM_OPENING := "res://audio/bgm_opening.mp3"      # 开头：Watercolor Dreams（菜单 + 开场动画 + Act1）
const BGM_DAILY := "res://audio/bgm_daily.mp3"          # 日常：Late Night Sketches（Act2 对话）
const BGM_END_UP := "res://audio/bgm_end_up.mp3"        # 金榜题名：Hope Returns
const BGM_END_DOWN := "res://audio/bgm_end_down.mp3"    # 芸芸众生 / 黄粱一梦：Hope Returns

# ===== SFX 音效（Kenney UI Audio）=====
const SFX_CLICK := "res://audio/sfx_click.ogg"          # 按钮/对话推进点击
const SFX_HOVER := "res://audio/sfx_hover.ogg"          # 按钮鼠标悬停

@export_range(-60.0, 0.0, 0.5) var bgm_volume_db: float = -8.0
@export_range(-60.0, 0.0, 0.5) var sfx_volume_db: float = -6.0
@export_range(-60.0, 0.0, 0.5) var sfx_hover_volume_db: float = -8.0  # 悬停比点击低约 20%
@export var fade_in_duration: float = 3.0    # 新曲淡入时长
@export var fade_out_duration: float = 5.0   # 旧曲淡出时长（换曲时）

const SILENT_DB := -60.0

var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _sfx_hover: AudioStreamPlayer


func _ready() -> void:
	_bgm_a = _make_bgm_player()
	_bgm_b = _make_bgm_player()
	_active = _bgm_a
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "Master"
	_sfx.volume_db = sfx_volume_db
	add_child(_sfx)
	_sfx_hover = AudioStreamPlayer.new()
	_sfx_hover.bus = "Master"
	_sfx_hover.volume_db = sfx_hover_volume_db
	add_child(_sfx_hover)


func _make_bgm_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.volume_db = SILENT_DB
	add_child(p)
	# BGM 循环（自然播完就重播，不涉及淡出）
	p.finished.connect(func(): p.play())
	return p


## 播放背景音乐（交叉淡入淡出；同名且正在播则跳过）
func play_bgm(path: String) -> void:
	if _active.stream != null \
			and _active.stream.resource_path == path \
			and _active.playing:
		return
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: 无法加载 BGM " + path)
		return

	# 首次播放（没有旧曲在放）→ 直接淡入
	if _active.stream == null or not _active.playing:
		_active.stop()
		_active.stream = stream
		_active.volume_db = SILENT_DB
		_active.play()
		var t := create_tween()
		t.tween_property(_active, "volume_db", bgm_volume_db, fade_in_duration)
		return

	# 换曲：新曲淡入 3s，旧曲淡出 5s 后停止（交叉过渡）
	var incoming: AudioStreamPlayer = _bgm_b if _active == _bgm_a else _bgm_a
	incoming.stop()
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	var tin := create_tween()
	tin.tween_property(incoming, "volume_db", bgm_volume_db, fade_in_duration)
	var outgoing := _active
	var tout := create_tween()
	tout.tween_property(outgoing, "volume_db", SILENT_DB, fade_out_duration)
	tout.tween_callback(func(): outgoing.stop())
	_active = incoming


## 播放一次短音效
func play_sfx(path: String) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: 无法加载 SFX " + path)
		return
	if path == SFX_HOVER:
		_sfx_hover.stream = stream
		_sfx_hover.play()
	else:
		_sfx.stream = stream
		_sfx.play()
