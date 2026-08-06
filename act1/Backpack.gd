extends Area2D
class_name Backpack

## 地上的背包：玩家靠近时显示子节点 PickupUI。
## 点击 UI 或按 E 拾取，拾取后自销毁。

signal player_entered(backpack: Backpack)
signal player_exited(backpack: Backpack)
signal picked_up(backpack: Backpack)

## 拾取后替换玩家的行走帧
@export var walk_frames: Array[Texture2D] = []

var is_picked: bool = false

@onready var pickup_ui: PickupUI = $PickupUI


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if pickup_ui:
		pickup_ui.clicked.connect(_on_ui_clicked)


func _on_body_entered(body: Node2D) -> void:
	if is_picked:
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
