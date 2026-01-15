extends HBoxContainer

signal choice_selected(idx: int)

@export var selected_idx: int = 0

@onready var selected = self.get_child(self.selected_idx)

func _ready() -> void:
	var children := get_children()
	
	for i in range(children.size()):
		var child = children[i]
		
		if child is Button:
			child.pressed.connect(Callable(_on_pressed).bind(child))
			
			child.add_theme_color_override("icon_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
			child.set_meta("idx", i)
	
	update_selection()

func _on_pressed(button: Button):
	self.selected = button
	self.selected_idx = button.get_meta("idx")
	
	update_selection()
	
	choice_selected.emit(self.selected_idx)
	
	button.release_focus()

func select(idx: int):
	var children := get_children()
	if idx < 0 or idx >= children.size():
		print("ERROR: Invalid index selected for HBEditorChoiceButtonGroup")
		return
	
	var child = children[idx]
	
	self.selected = child
	self.selected_idx = idx
	
	update_selection()

func update_selection():
	for child in get_children():
		if child is Button:
			if child == selected:
				child.flat = false
			else:
				child.flat = true
