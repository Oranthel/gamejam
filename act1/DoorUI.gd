@tool
extends Node2D
class_name DoorUI

## 门旁边的 UI：所有物品拾取后出现，点击跳转下一个场景。

signal clicked

@export var next_scene: String = ""
@export var click_scale: float = 3.0

@onready var sprite: Sprite2D = _find_sprite()


func _find_sprite() -> Sprite2D:
	# 优先找有 texture 的 Sprite2D 子节点
	for child in get_children():
		if child is Sprite2D and child.texture != null:
			return child
	# 兜底：找任意 Sprite2D 子节点
	for child in get_children():
		if child is Sprite2D:
			return child
	return null


func show_ui() -> void:
	if sprite:
		sprite.visible = true


func hide_ui() -> void:
	if sprite:
		sprite.visible = false


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if sprite == null or not sprite.visible or sprite.texture == null:
		return
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos := sprite.to_local(event.position)
		var half := sprite.texture.get_size() * sprite.scale * 0.5 * click_scale
		if abs(local_pos.x) <= half.x and abs(local_pos.y) <= half.y:
			clicked.emit()
			if next_scene != "":
				get_tree().change_scene_to_file(next_scene)
			var vp := get_viewport()
			if vp:
				vp.set_input_as_handled()
