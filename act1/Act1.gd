extends Node2D

## 第一幕主控：
## 1. 玩家点击屏幕 → 逐个换皮肤（瞬移到点击位置）→ 最后一个皮肤自动激活移动
## 2. 玩家靠近某个背包 → 该背包的 PickupUI 出现
## 3. 拾取其中一个后，另一个背包不再显示 UI（互斥）

var picked_any: bool = false
var current_backpack: int = 0  # 0=未拾取, 1=Backpack1, 2=Backpack2
var backpacks: Array = []
var items: Array = []
var total_items: int = 0
var picked_items: int = 0
var door_ui_shown: bool = false

@onready var player: Player = $Player
@onready var hint: Label = get_node_or_null("Hint")
@onready var door_ui: DoorUI = get_node_or_null("DoorUI")
@onready var inventory: Inventory = get_node_or_null("Inventory")


func _ready() -> void:
	# 开头 BGM（延续自菜单/开场）
	AudioManager.play_bgm(AudioManager.BGM_OPENING)
	backpacks = $Backpacks.get_children()
	player.activated.connect(_on_player_activated)
	for bp in backpacks:
		if bp is Backpack:
			bp.player_entered.connect(_on_backpack_player_entered)
			bp.player_exited.connect(_on_backpack_player_exited)
			bp.picked_up.connect(_on_backpack_picked)
	# 收集所有物品
	if $Items:
		items = $Items.get_children()
		for it in items:
			if it is Item:
				it.player_entered.connect(_on_item_player_entered)
				it.player_exited.connect(_on_item_player_exited)
				it.picked_up.connect(_on_item_picked)
		# 只计算 Item 类型，排除非 Item 子节点
		total_items = 0
		for it in items:
			if it is Item:
				total_items += 1
	# 门 UI 初始隐藏
	if door_ui:
		door_ui.hide_ui()


func _on_player_activated() -> void:
	if hint:
		hint.visible = false


func _on_backpack_player_entered(bp: Backpack) -> void:
	if picked_any:
		return
	bp.show_ui()


func _on_backpack_player_exited(bp: Backpack) -> void:
	bp.hide_ui()


func _on_backpack_picked(bp: Backpack) -> void:
	if picked_any:
		return
	picked_any = true
	# 记录当前拾取的是哪个背包
	if bp.name == "Backpack1":
		current_backpack = 1
	elif bp.name == "Backpack2":
		current_backpack = 2
	bp.hide_ui()
	# 替换玩家行走帧
	player.set_walk_frames(bp.walk_frames)
	bp.pick_up()
	# 隐藏所有其他背包的 UI
	for other in backpacks:
		if other is Backpack and other != bp:
			other.hide_ui()
	# 解锁所有物品
	for it in items:
		if it is Item:
			it.unlock()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey \
			and event.pressed \
			and event.keycode == KEY_E:
		_try_pickup_nearby()


func _try_pickup_nearby() -> void:
	# 优先处理已解锁物品
	for it in items:
		if it is Item and it.unlocked and it.pickup_ui and it.pickup_ui.is_visible_now():
			it.pick_up()
			return
	# 再处理背包（互斥）
	if picked_any:
		return
	for bp in backpacks:
		if bp is Backpack and bp.pickup_ui and bp.pickup_ui.is_visible_now():
			_on_backpack_picked(bp)
			return


func _on_item_player_entered(it: Item) -> void:
	if not is_instance_valid(it) or it.is_picked:
		return
	it.show_ui()


func _on_item_player_exited(it: Item) -> void:
	if not is_instance_valid(it):
		return
	it.hide_ui()


func _on_item_picked(it: Item) -> void:
	# 收集物品所有 sprite texture 到背包
	var textures := it.get_sprite_textures()
	if inventory:
		inventory.add_item_textures(textures)
	picked_items += 1
	# 捡走一个物品后，检查剩余物品（跳过已被释放/已拾取的）
	_cleanup_items_array()
	for other in items:
		if not is_instance_valid(other):
			continue
		if other is Item and not other.is_picked and other.unlocked:
			var overlapping: Array = other.get_overlapping_bodies()
			for body in overlapping:
				if body is Player and is_instance_valid(body):
					other.show_ui()
					break
	# 全部拾取完，显示门 UI
	if picked_items >= total_items and not door_ui_shown:
		door_ui_shown = true
		if door_ui:
			door_ui.show_ui()


# 从 items 数组里移除已经被销毁（queue_free后）的节点，避免崩溃
func _cleanup_items_array() -> void:
	var alive: Array = []
	for node in items:
		if is_instance_valid(node):
			alive.append(node)
	items = alive
