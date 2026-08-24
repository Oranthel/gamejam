@tool
extends Node2D
class_name DoorUI

## 门旁边的 UI：所有物品拾取后出现，点击跳转下一个场景。

signal clicked

@export var next_scene: String = ""
@export var click_scale: float = 3.0

@onready var sprite: Sprite2D = _find_sprite()


func _find_sprite() -> Sprite2D:
	for child in get_children():
		if child is Sprite2D and child.texture != null:
			return child
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


func _get_click_rect() -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2()
	var tex_size: Vector2 = sprite.texture.get_size()
	var spr_size: Vector2 = tex_size * sprite.scale * click_scale
	var global_pos: Vector2 = sprite.global_position
	if sprite.centered:
		return Rect2(global_pos - spr_size * 0.5, spr_size)
	else:
		var offset: Vector2 = (tex_size * sprite.scale) * (1.0 - click_scale) * 0.5
		return Rect2(global_pos + offset, spr_size)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if sprite == null or not sprite.visible or sprite.texture == null:
		return
	# 鼠标左键：点击范围内开门
	var is_left_click: bool = event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT
	# 空格键：直接开门（无需判断位置）
	var is_space: bool = event is InputEventKey \
			and event.pressed \
			and event.keycode == KEY_SPACE
	if is_left_click:
		var mouse_pos: Vector2 = get_global_mouse_position()
		var click_rect: Rect2 = _get_click_rect()
		if click_rect.has_point(mouse_pos):
			clicked.emit()
			if next_scene != "":
				get_tree().change_scene_to_file(next_scene)
			var vp := get_viewport()
			if vp:
				vp.set_input_as_handled()
	elif is_space:
		clicked.emit()
		if next_scene != "":
			get_tree().change_scene_to_file(next_scene)
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
