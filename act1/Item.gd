extends Area2D
class_name Item

## 场景中的物品：图片开场就存在，拾取 UI 需背包拾取后才解锁。
## 点击 UI 后物品消失。

signal player_entered(item: Item)
signal player_exited(item: Item)
signal picked_up(item: Item)

var is_picked: bool = false
var unlocked: bool = false


@onready var pickup_ui: PickupUI = _find_pickup_ui()


func _find_pickup_ui() -> PickupUI:
	var node := get_node_or_null("PickupUI")
	if node == null:
		node = get_node_or_null("PickupUI_2")
	if node == null:
		for child in get_children():
			if child is PickupUI:
				return child
	return node


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if pickup_ui:
		pickup_ui.clicked.connect(_on_ui_clicked)


func _on_body_entered(body: Node2D) -> void:
	if is_picked or not unlocked:
		return
	if body is Player:
		player_entered.emit(self)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_exited.emit(self)


func show_ui() -> void:
	if pickup_ui:
		pickup_ui.show_ui()


func hide_ui() -> void:
	if pickup_ui:
		pickup_ui.hide_ui()


func _on_ui_clicked() -> void:
	pick_up()


func pick_up() -> void:
	if is_picked:
		return
	is_picked = true
	picked_up.emit(self)
	queue_free()


func unlock() -> void:
	unlocked = true


## 返回所有 Sprite2D 子节点的 texture（用于背包显示）
func get_sprite_textures() -> Array:
	var textures: Array = []
	for child in get_children():
		if child is Sprite2D and child.texture != null:
			textures.append(child.texture)
	return textures
