extends HBEditorModule

const EDITOR_TEMPLATES_PATH := "user://editor_templates"
const DOWN_ICON = preload("res://tools/icons/icon_GUI_tree_arrow_down.svg")
const RIGHT_ICON = preload("res://tools/icons/icon_GUI_tree_arrow_right.svg")

@onready var path_preview: HBEditorPathPreview = get_node("PathPreview")
@onready var path_edit_tree: Tree = get_node("%PathEditTree")

var paths := {}
var open_path: HBEditorPath = HBEditorPath.new()
var selected_path: HBPaths.HBPath = null
var selected_segment: HBPaths.HBSpline = null

func _ready():
	super._ready()
	
	add_shortcut("editor_apply_path", "_toggle_path_preview")
	
	var path = HBPaths.HBPath.new()
	
	var segment = HBPaths.HBBezierSpline.new()
	segment.start_position = Vector2(990, 540)
	segment.end_position = Vector2(1200, 790)
	segment.control_a = Vector2(1100, 600)
	segment.control_b = Vector2(1150, 700)
	path.segments.append(segment)
	segment = HBPaths.HBContinuousBezierSpline.new()
	segment.start_position = Vector2(1200, 790)
	segment.end_position = Vector2(1500, 900)
	#segment.control_a = Vector2(1300, 900)
	segment.control_b = Vector2(1400, 900)
	path.segments.append(segment)
	
	open_path.paths.append(path)
	
	var path_b = HBPaths.HBPath.new()
	
	segment = HBPaths.HBSpline.new()
	segment.start_position = Vector2(990, 540)
	segment.end_position = Vector2(1200, 790)
	path_b.segments.append(segment)
	segment = HBPaths.HBSpline.new()
	segment.start_position = Vector2(111, 90)
	segment.end_position = Vector2(1500, 900)
	path_b.segments.append(segment)
	
	open_path.paths.append(path_b)
	
	rebuild_tree()
	
	remove_child(path_preview)

func set_editor(p_editor):
	super.set_editor(p_editor)
	
	path_preview.set_editor(p_editor)
	path_preview.set_paths_module(self)
	
	add_preview_tool(path_preview)

func _input(event: InputEvent):
	super._input(event)
	
	var selected = get_selected()
	
	if shortcuts_blocked():
		return
	
	pass

func _toggle_path_preview():
	if path_preview.visible:
		path_preview.clear_preview()
		path_preview.hide()
	else:
		path_preview.set_path(self.selected_path, self.selected_segment, self.open_path.paths)
		path_preview.show()

func rebuild_tree():
	path_edit_tree.clear()
	
	if not self.open_path:
		return
	
	var root := path_edit_tree.create_item()
	root.set_text(0, self.open_path.name)
	
	for path in self.open_path.paths:
		var path_item := root.create_child()
		path_item.set_text(0, path.name)
		
		path_item.set_meta("path", path)
		
		var last_segment = null
		for segment in path.segments:
			var segment_item := path_item.create_child()
			segment_item.set_text(0, segment.name)
			
			segment_item.set_meta("path", path)
			segment_item.set_meta("segment", segment)
			
			var create_control_node_item = func(name: StringName, control_property: StringName):
				var control_node_item := segment_item.create_child()
				control_node_item.set_text(0, name)
			
				control_node_item.set_meta("path", path)
				control_node_item.set_meta("segment", segment)
				control_node_item.set_meta("control_property", control_property)
				
				segment.set_meta(control_property, control_node_item)
			
			if not last_segment:
				create_control_node_item.call("Start position", "start_position")
			
			if segment is HBPaths.HBBezierSpline:
				if not segment is HBPaths.HBContinuousBezierSpline:
					create_control_node_item.call("First control node", "control_a")
				
				create_control_node_item.call("Second control node", "control_b")
			
			create_control_node_item.call("End position", "end_position")
			
			segment.set_meta("paths_module", self)
			last_segment = segment

func _on_path_edit_tree_cell_selected() -> void:
	var selected_item = path_edit_tree.get_selected()
	
	if selected_item.has_meta("path"):
		selected_path = selected_item.get_meta("path")
		selected_segment = null
	
	if selected_item.has_meta("segment"):
		selected_segment = selected_item.get_meta("segment")
	
	path_preview.set_path(self.selected_path, self.selected_segment, self.open_path.paths)
	
	if selected_item.has_meta("control_property"):
		var widget = selected_item.get_meta("widget", null)
		
		if widget:
			path_preview.selected_widget = widget
			widget.select()
	
	path_preview.update_widgets()
