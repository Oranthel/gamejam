@tool
extends Node2D
class_name PickupUI

## 背包旁的拾取 UI。
## 选中子节点 Sprite2D，把 UI 图片拖到它的 Texture 上。
## 加了 @tool，编辑器里可直接预览图片位置。

signal clicked

## 点击范围倍数（1.0 = 图片实际大小，1.5 = 1.5 倍点击范围，方便点中小图标）
@export var click_scale: float = 3.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# 编辑器里不隐藏，方便预览
	if not Engine.is_editor_hint():
		hide_ui()


func show_ui() -> void:
	if sprite:
		sprite.visible = true


func hide_ui() -> void:
	if sprite:
		sprite.visible = false


func is_visible_now() -> bool:
	return sprite != null and sprite.visible


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if sprite == null or not sprite.visible or sprite.texture == null:
		return
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# 用事件 position（视口坐标），转换为 sprite 本地坐标
		var local_pos := sprite.to_local(event.position)
		var half := sprite.texture.get_size() * sprite.scale * 0.5 * click_scale
		if abs(local_pos.x) <= half.x and abs(local_pos.y) <= half.y:
			clicked.emit()
			var vp := get_viewport()
			if vp:
				vp.set_input_as_handled()
