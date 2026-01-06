extends HBEditorModule

const EDITOR_PATHS_PATH := "user://editor_paths"

@onready var load_icon = preload("res://tools/icons/icon_load.svg")
@onready var copy_icon = preload("res://tools/icons/icon_action_copy.svg")
@onready var delete_icon = preload("res://tools/icons/icon_remove.svg")

@onready var path_preview: HBEditorPathPreview = get_node("PathPreview")
@onready var path_edit_tree: Tree = get_node("%PathEditTree")

@onready var path_type_control_group = get_node("%PathTypeControlGroup")
@onready var lock_distance_control_group = get_node("%LockDistanceControlGroup")

var paths := {}
var open_path: HBEditorPath = HBEditorPath.new()
var selected_path: HBPaths.HBPath = null
var selected_segment: HBPaths.HBSpline = null

func _ready():
	super._ready()
	
	add_shortcut("editor_apply_path", "_toggle_path_preview")

	path_type_control_group.choice_selected.connect(_on_path_type_selected)
	lock_distance_control_group.choice_selected.connect(_on_lock_distance_selected)

	path_type_control_group.select(UserSettings.user_settings.editor_last_spline_type)
	lock_distance_control_group.select(UserSettings.user_settings.editor_lock_spline_distance)
	
	var path = HBPaths.HBPath.new()
	
	var segment1 = HBPaths.HBBezierSpline.new()
	segment1.start_position = Vector2(990, 540)
	segment1.end_position = Vector2(1200, 790)
	segment1.control_a = Vector2(1100, 600)
	segment1.control_b = Vector2(1150, 700)
	path.segments.append(segment1)
	var segment2 = HBPaths.HBContinuousBezierSpline.new()
	segment2.start_position = Vector2(1200, 790)
	segment2.end_position = Vector2(1500, 900)
	#segment2.control_a = Vector2(1300, 900)
	segment2.control_b = Vector2(1400, 900)
	path.segments.append(segment2)
	
	open_path.paths.append(path)
	
	var path_b = HBPaths.HBPath.new()
	
	var segment3 = HBPaths.HBSpline.new()
	segment3.start_position = Vector2(990, 540)
	segment3.end_position = Vector2(1200, 790)
	path_b.segments.append(segment3)
	var segment4 = HBPaths.HBSpline.new()
	segment4.start_position = Vector2(111, 90)
	segment4.end_position = Vector2(1500, 900)
	path_b.segments.append(segment4)
	
	open_path.paths.append(path_b)
	
	var path_c = HBPaths.HBPath.new()
	
	var segment5 = HBPaths.HBCardinalSpline.new()
	segment5.start_position = Vector2(990, 540)
	segment5.end_position = Vector2(1200, 790)
	path_c.segments.append(segment5)
	var segment6 = HBPaths.HBCardinalSpline.new()
	segment6.start_position = Vector2(111, 90)
	segment6.end_position = Vector2(1500, 900)
	path_c.segments.append(segment6.clone())
	
	open_path.paths.append(path_c)
	
	path_preview.create_spline.connect(_on_create_spline)
	path_preview.split_spline.connect(_on_split_spline)
	
	rebuild_tree()
	
	remove_child(path_preview)

func set_editor(p_editor):
	super.set_editor(p_editor)
	
	path_preview.set_editor(p_editor)
	path_preview.set_paths_module(self)
	
	add_preview_tool(path_preview)
	
	editor.game_preview.widget_area.connect("widget_area_input", Callable(path_preview, "_widget_area_input"))

func _input(event: InputEvent):
	super._input(event)
	
	var selected = get_selected()
	
	if shortcuts_blocked():
		return
	
	pass

func _toggle_path_preview():
	if path_preview.visible:
		path_preview.clear_preview()
		path_preview.clear_widgets()
		path_preview.hide()
	else:
		path_preview.set_path(self.selected_path, self.selected_segment, self.open_path.paths)
		path_preview.rebuild_widgets()
		path_preview.show()

func update_preview():
	path_preview.clear_widgets()
	
	rebuild_tree()
	
	path_preview.update_preview()
	path_preview.rebuild_widgets()

func rebuild_tree():
	path_edit_tree.clear()
	
	if not self.open_path:
		return
	
	path_edit_tree.set_column_expand(0, true)
	path_edit_tree.set_column_expand(1, false)
	path_edit_tree.set_column_expand(2, false)
	# path_edit_tree.set_column_expand(3, false)
	path_edit_tree.set_column_custom_minimum_width(0, 9)
	path_edit_tree.set_column_custom_minimum_width(1, 1)
	path_edit_tree.set_column_custom_minimum_width(2, 1)
	# path_edit_tree.set_column_custom_minimum_width(3, 1)
	
	var root := path_edit_tree.create_item()
	root.set_text(0, self.open_path.name)
	
	for path in self.open_path.paths:
		var path_item := root.create_child()
		path_item.set_text(0, path.name)
		
		path_item.set_meta("path", path)
		
		path_item.add_button(1, copy_icon, -1, false, "Copy this subpath to another path.")
		path_item.add_button(2, delete_icon, -1, false, "Delete this subpath.")
		
		var last_segment = null
		for segment in path.segments:
			var segment_item := path_item.create_child()
			segment_item.set_text(0, segment.name)
			
			segment_item.add_button(1, copy_icon, -1, false, "Copy this segment to another subpath.")
			segment_item.add_button(2, delete_icon, -1, false, "Delete this segment.")
			
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

func _on_path_type_selected(idx: int):
	UserSettings.user_settings.editor_last_spline_type = idx

func _on_lock_distance_selected(idx: int):
	var lock_spline_distance := true if idx == 0 else false
	UserSettings.user_settings.editor_lock_spline_distance = lock_spline_distance

func add_segment():
	self.selected_segment = null
	path_preview.selected_segment = null
	
	var spline_types := [
		HBPaths.HBSpline.new(),
		HBPaths.HBBezierSpline.new(),
		HBPaths.HBContinuousBezierSpline.new(),
		HBPaths.HBCardinalSpline.new(),
		HBPaths.HBCircularSpline.new(),
		HBPaths.HBPeriodicSpline.new(),
	]
	
	var new_segment = spline_types[UserSettings.user_settings.editor_last_spline_type]
	new_segment.set_meta("adding", true)
	path_preview.new_segment = new_segment
	path_preview.adding_segment = true
	
	path_preview.update_split_widget()
	
	path_preview.update_preview()
	path_preview.rebuild_widgets()

func _on_create_spline(spline):
	var new_segment_idx := self.selected_path.segments.size()
	var selected_path_idx = self.open_path.paths.find(selected_path)
	
	var insert_spline := func():
		self.open_path.paths[selected_path_idx].segments.insert(new_segment_idx, spline)
	
	var remove_spline := func():
		self.open_path.paths[selected_path_idx].segments.remove_at(new_segment_idx)
	
	undo_redo.create_action("Create spline.")
	
	undo_redo.add_do_method(insert_spline)
	undo_redo.add_undo_method(remove_spline)
	
	undo_redo.add_do_method(Callable(call_deferred).bind("update_preview"))
	undo_redo.add_undo_method(Callable(call_deferred).bind("update_preview"))
	
	undo_redo.commit_action()

func _on_split_spline(spline: HBPaths.HBBezierSpline, point: Vector2, t_value: float):
	var new_segment_idx = self.selected_path.segments.find(spline)
	var selected_path_idx = self.open_path.paths.find(selected_path)
	
	var new_splines := spline.split_at(point, t_value)
	
	var insert_spline := func():
		self.open_path.paths[selected_path_idx].segments.remove_at(new_segment_idx)
		
		self.open_path.paths[selected_path_idx].segments.insert(new_segment_idx, new_splines[0])
		self.open_path.paths[selected_path_idx].segments.insert(new_segment_idx + 1, new_splines[1])
	
	var remove_spline := func():
		self.open_path.paths[selected_path_idx].segments.remove_at(new_segment_idx + 1)
		self.open_path.paths[selected_path_idx].segments.remove_at(new_segment_idx)
		
		self.open_path.paths[selected_path_idx].segments.insert(new_segment_idx, spline)
	
	undo_redo.create_action("Split spline.")
	
	undo_redo.add_do_method(insert_spline)
	undo_redo.add_undo_method(remove_spline)
	
	undo_redo.add_do_method(Callable(call_deferred).bind("update_preview"))
	undo_redo.add_undo_method(Callable(call_deferred).bind("update_preview"))
	
	undo_redo.commit_action()
