@tool

extends HBEditorWidget

class_name HBEditorPathControlWidget

signal position_changed(new_position: Vector2)
signal position_changed_delta(new_position_delta: Vector2)
signal update_preview
signal created

@onready var movement_gizmo = get_node("ControlPointGizmo")
@onready var texture_rect = get_node("TextureRect")

var internal_pos : Vector2
var drag_origin: Vector2

var spline: HBPaths.HBSpline : set = set_spline

var control_property := "start_position"

var connected_widget: HBEditorWidget = null
var connected_widgets: Array[HBEditorWidget] = []
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
	self.connected_widget.position_changed_delta.connect(_on_connected_widget_dragged)
	
	widget.connected_widgets.append(self)
	
	arrange_gizmo()

func _on_connected_widget_dragged(relative_movement: Vector2):
	_on_dragged(relative_movement)

func arrange_gizmo():
	var note_scale := 1.0
	if editor:
		note_scale = editor.rhythm_game.get_note_scale()
	
	var new_size = texture_rect.texture.get_size() * note_scale
	
	movement_gizmo.set_deferred("size", new_size)
	movement_gizmo.size = texture_rect.texture.get_size() * note_scale
	movement_gizmo.position = size / 2 - new_size / 2
	texture_rect.position = movement_gizmo.position
	texture_rect.set_deferred("size", new_size)
	internal_pos = position

func select():
	movement_gizmo.selected = true
	
	movement_gizmo.queue_redraw()
	queue_redraw()

func disable():
	line_color = UserSettings.user_settings.editor_disabled_spline_color
	
	movement_gizmo.disabled = true
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func deselect():
	movement_gizmo.selected = false
	
	movement_gizmo.queue_redraw()
	queue_redraw()

func _on_resized():
	if is_inside_tree():
		await get_tree().process_frame
		call_deferred("arrange_gizmo")

func _on_dragged(movement: Vector2):
	if not spline or get_meta("creating", false):
		return
	
	internal_pos += movement
	
	var original_position = position + size / 2
	var snapped_pos = editor.snap_position_to_grid(
		editor.rhythm_game.inv_map_coords(internal_pos + size / 2),
		editor.rhythm_game.inv_map_coords(drag_origin + size / 2),
		Input.is_key_pressed(KEY_SHIFT)
	)
	
	position = editor.rhythm_game.remap_coords(snapped_pos) - size / 2
	
	position_changed.emit(snapped_pos)
	position_changed_delta.emit((position + size / 2) - original_position)

func _widget_area_input(event: InputEvent):
	if not get_meta("creating", false) or control_property != "end_position":
		return
	
	if Input.is_action_pressed("editor_select", true):
		set_meta("creating", false)
		
		created.emit()
		
		return
	
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var mouse_pos = get_parent().get_local_mouse_position()
		
		var original_position = position
		var snapped_pos = editor.snap_position_to_grid(
			editor.rhythm_game.inv_map_coords(mouse_pos),
			spline.start_position,
			Input.is_key_pressed(KEY_SHIFT)
		)
		
		var new_pos = editor.rhythm_game.remap_coords(snapped_pos) - size / 2
		position = new_pos
		
		position_changed.emit(snapped_pos)
		position_changed_delta.emit(position - original_position)
		
		update_preview.emit()

func _draw():
	if connected_widget:
		var width = UserSettings.user_settings.editor_spline_control_node_width
		
		if fmod(width, 2) == 0:
			draw_line(size / 2, connected_widget.global_position - global_position + connected_widget.size / 2, line_color.darkened(0.2), width)
		else:
			var correction := Vector2(0.5, 0.5)
			draw_line(size / 2 + correction, (connected_widget.global_position - global_position) + connected_widget.size / 2 + correction, line_color.darkened(0.2), width)

func _on_start_dragging():
	drag_origin = position
	internal_pos = position
	
	select()
	
	for widget in self.connected_widgets:
		if widget:
			widget.drag_origin = widget.position
			widget.internal_pos = widget.position
	
	if spline and spline.has_meta("paths_module"):
		var paths_module = spline.get_meta("paths_module", null)
		if paths_module:
			paths_module.path_preview.selected_widget = self
			
			var control_node_item = get_tree_item()
			if control_node_item:
				paths_module.path_edit_tree.set_selected(control_node_item, 0)
				paths_module.path_edit_tree.queue_redraw()

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
	
	for widget in self.connected_widgets:
		undo_redo.add_do_property(widget.spline, widget.control_property, editor.rhythm_game.inv_map_coords(widget.position + size/2))
		undo_redo.add_undo_property(widget.spline, widget.control_property, editor.rhythm_game.inv_map_coords(widget.drag_origin + size/2))
		
		if widget.spline is HBPaths.HBContinuousBezierSpline and control_property == "control_a":
			undo_redo.add_do_method(Callable(spline.update_control_node).bind(widget.spline))
			undo_redo.add_undo_method(Callable(spline.update_control_node).bind(widget.spline))
	
	undo_redo.add_do_method(_update_preview)
	undo_redo.add_undo_method(_update_preview)
	
	undo_redo.commit_action()

func _update_preview():
	update_preview.emit()

func get_tree_item() -> TreeItem:
	if spline.has_meta(control_property):
		var control_node_item = spline.get_meta(control_property, null)
		if control_node_item:
			control_node_item.set_meta("widget", self)
			
			return control_node_item
	
	return null
