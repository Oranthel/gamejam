extends CanvasLayer
class_name Inventory

## 背包系统：按 Tab/B 键开关，拾取的物品 sprite 自动添加到网格中

@export var toggle_action: String = "inventory"
@export var grid_columns: int = 5
@export var icon_size: Vector2 = Vector2(120, 120)

@onready var background: Sprite2D = $Background
@onready var grid: GridContainer = $Grid


func _ready() -> void:
	visible = false
	if grid:
		grid.columns = grid_columns


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		toggle()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()


func toggle() -> void:
	visible = not visible


func add_item_textures(textures: Array) -> void:
	if grid == null:
		return
	for tex in textures:
		if tex == null:
			continue
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = icon_size
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		grid.add_child(rect)
