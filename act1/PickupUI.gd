@tool
extends Node2D
class_name PickupUI

## 背包旁的拾取 UI。
## 选中子节点 Sprite2D，把 UI 图片拖到它的 Texture 上。
## 加了 @tool，编辑器里可直接预览图片位置。

signal clicked

## 点击范围倍数（1.0 = 图片实际大小，3.0 = 3.0 倍点击范围）
@export var click_scale: float = 3.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
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


# Sprite2D 没有 get_global_rect()，自己算全局矩形
func _get_click_rect() -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2()
	var tex_size: Vector2 = sprite.texture.get_size()
	var spr_size: Vector2 = tex_size * sprite.scale * click_scale
	var global_pos: Vector2 = sprite.global_position
	if sprite.centered:
		# centered=true 时 global_position 是中心
		return Rect2(global_pos - spr_size * 0.5, spr_size)
	else:
		# centered=false 时 global_position 是左上角
		var offset: Vector2 = (tex_size * sprite.scale) * (1.0 - click_scale) * 0.5
		return Rect2(global_pos + offset, spr_size)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not is_visible_now():
		return
	# 鼠标左键：点击范围内拾取
	var is_left_click: bool = event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT
	# 空格键：直接拾取（无需判断位置）
	var is_space: bool = event is InputEventKey \
			and event.pressed \
			and event.keycode == KEY_SPACE
	if is_left_click:
		var mouse_pos: Vector2 = get_global_mouse_position()
		var click_rect: Rect2 = _get_click_rect()
		if click_rect.has_point(mouse_pos):
			clicked.emit()
			var vp := get_viewport()
			if vp:
				vp.set_input_as_handled()
	elif is_space:
		clicked.emit()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
