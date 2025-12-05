@tool

extends HBEditorWidget

class_name HBEditorPathControlWidget

signal position_changed(new_position: Vector2)
signal update_preview

@onready var movement_gizmo = get_node("ControlPointGizmo")
@onready var texture_rect = get_node("TextureRect")

var internal_pos : Vector2
var starting_pos
var drag_origin: Vector2

var spline: HBPaths.HBSpline : set = set_spline

var control_property := "start_position"

var connected_widget: HBEditorWidget = null
var line_color: Color : set = set_line_color

func _ready():
	super._ready()
	
	get_viewport().connect("size_changed", Callable(self, "_on_resized"))
	_on_resized()
	deselect()

func set_spline(val):
	spline = val
	
	arrange_gizmo()

func set_line_color(val):
	line_color = val
	
	texture_rect.modulate = line_color
	
	queue_redraw()

func connect_to_widget(widget: HBEditorWidget):
	self.connected_widget = widget
	
	arrange_gizmo()

func arrange_gizmo():
	if spline:
		var note_scale = editor.rhythm_game.get_note_scale()
		movement_gizmo.size = texture_rect.texture.get_size() * note_scale
		movement_gizmo.position = size / 2 - movement_gizmo.size/2
		texture_rect.position = movement_gizmo.position
		texture_rect.size = movement_gizmo.size
		internal_pos = position

func select():
	movement_gizmo.selected = true
	
	movement_gizmo.queue_redraw()
	queue_redraw()

func disable():
	line_color = UserSettings.user_settings.editor_disabled_spline_color
	
	movement_gizmo.disabled = true

func deselect():
	movement_gizmo.selected = false
	
	movement_gizmo.queue_redraw()
	queue_redraw()

func _on_resized():
	if is_inside_tree():
		await get_tree().process_frame
		call_deferred("arrange_gizmo")

func _on_dragged(movement: Vector2):
	if not spline:
		return
	
	internal_pos += movement
	
	var snapped_pos = editor.snap_position_to_grid(
		editor.rhythm_game.inv_map_coords(internal_pos + size/2),
		editor.rhythm_game.inv_map_coords(drag_origin + size/2),
		Input.is_key_pressed(KEY_SHIFT)
	)
	
	position_changed.emit(snapped_pos)
	position = editor.rhythm_game.remap_coords(snapped_pos) - size / 2

func _widget_area_input(event: InputEvent):
	if not get_viewport().is_input_handled():
		if event is InputEventMouseButton:
			if event.is_action_released("editor_select"):
				pass
				#get_viewport().set_input_as_handled()
		
		if event is InputEventMouseMotion:
			if Input.is_action_pressed("editor_select"):
				pass

func _draw():
	if connected_widget:
		var width = UserSettings.user_settings.editor_spline_control_node_width
		
		if fmod(width, 2) == 0:
			draw_line(size / 2, connected_widget.global_position - global_position + connected_widget.size / 2, line_color, width)
		else:
			var correction := Vector2(0.5, 0.5)
			draw_line(size / 2 + correction, (connected_widget.global_position - global_position) + connected_widget.size / 2 + correction, line_color, width)

func _on_start_dragging():
	drag_origin = position
	internal_pos = position
	
	select()
	
	var paths_module = spline.get_meta("paths_module", null)
	if paths_module:
		paths_module.path_preview.selected_widget = self
		
		var control_node_item = get_tree_item()
		if control_node_item:
			paths_module.path_edit_tree.set_selected(control_node_item, 0)
			paths_module.path_edit_tree.queue_redraw()

func get_tree_item() -> TreeItem:
	var control_node_item = spline.get_meta(control_property, null)
	if control_node_item:
		control_node_item.set_meta("widget", self)
		
		return control_node_item
	
	return null

func _on_finish_dragging():
	var snapped_pos = editor.snap_position_to_grid(
		editor.rhythm_game.inv_map_coords(internal_pos + size/2),
		editor.rhythm_game.inv_map_coords(drag_origin + size/2),
		Input.is_key_pressed(KEY_SHIFT)
	)
	
	position = editor.rhythm_game.remap_coords(snapped_pos) - size / 2
	
	var undo_redo = editor.undo_redo
	undo_redo.create_action("Move Path control point")
	
	undo_redo.add_do_property(spline, control_property, snapped_pos)
	undo_redo.add_undo_property(spline, control_property, editor.rhythm_game.inv_map_coords(drag_origin + size/2))
	
	undo_redo.add_do_method(_update_preview)
	undo_redo.add_undo_method(_update_preview)
	
	undo_redo.commit_action()

func _update_preview():
	update_preview.emit()
