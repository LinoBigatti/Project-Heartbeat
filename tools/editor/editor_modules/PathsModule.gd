extends HBEditorModule

const EDITOR_PATHS_PATH := "user://editor_paths"

const SPLINE_ARRANGE_RESOLUTION := 2000.0

@onready var load_icon = preload("res://tools/icons/icon_load.svg")
@onready var copy_icon = preload("res://tools/icons/icon_action_copy.svg")
@onready var delete_icon = preload("res://tools/icons/icon_remove.svg")

@onready var path_preview: HBEditorPathPreview = get_node("PathPreview")
@onready var path_edit_tree: Tree = get_node("%PathEditTree")

@onready var spline_control_panel = get_node("%SplineControls")
@onready var selected_spline_label = get_node("%SelectedSplineLabel")

@onready var path_type_control_group = get_node("%PathTypeControlGroup")
@onready var lock_distance_control_group = get_node("%LockDistanceControlGroup")
@onready var segment_name_line_edit: HBEditorLineEdit = get_node("%SegmentNameLineEdit")

@onready var cardinal_controls = get_node("%CardinalControlsVBoxContainer")
@onready var circle_controls = get_node("%CircleControlsVBoxContainer")
@onready var function_controls = get_node("%FunctionControlsVBoxContainer")

@onready var cardinal_smoothness_slider = get_node("%CardinalSmoothnessHSlider")

@onready var circle_direction_option_button = get_node("%CircleDirectionOptionButton")
@onready var circle_angle_slider = get_node("%CircleAngleHSlider")

@onready var function_type_option_button = get_node("%FunctionTypeOptionButton")
@onready var peak_count_slider = get_node("%PeakCountHSlider")

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

func get_new_segment_object(spline_type: int = -1):
	var spline_types := [
		HBPaths.HBSpline.new(),
		HBPaths.HBBezierSpline.new(),
		HBPaths.HBContinuousBezierSpline.new(),
		HBPaths.HBCardinalSpline.new(),
		HBPaths.HBCircularSpline.new(),
		HBPaths.HBPeriodicSpline.new(),
	]
	
	if spline_type == -1:
		spline_type = UserSettings.user_settings.editor_last_spline_type
	
	var spline = spline_types[spline_type]
	
	if spline is HBPaths.HBCardinalSpline:
		spline.curve_smoothness = UserSettings.user_settings.editor_last_cardinal_smoothness
	
	if spline is HBPaths.HBCircularSpline:
		spline.angle = UserSettings.user_settings.editor_last_circle_segment_angle
		spline.clockwise = UserSettings.user_settings.editor_circle_segment_clockwise
	
	if spline is HBPaths.HBPeriodicSpline:
		spline.function_type = UserSettings.user_settings.editor_last_periodic_fn_type
	
	return spline

func select_spline(spline: HBPaths.HBSpline) -> void:
	self.selected_segment = spline
	
	path_preview.set_path(self.selected_path, self.selected_segment, self.open_path.paths)
	
	update_timeline_preview()

func _toggle_path_preview():
	if path_preview.visible:
		path_preview.clear_preview()
		path_preview.clear_widgets()
		path_preview.hide()
	else:
		path_preview.set_path(self.selected_path, self.selected_segment, self.open_path.paths)
		path_preview.rebuild_widgets()
		path_preview.show()
	
	update_parameters()

func update_preview():
	path_preview.clear_widgets()
	
	rebuild_tree()
	update_parameters()
	
	path_preview.update_preview()
	path_preview.rebuild_widgets()

func update_timeline_preview():
	var spline_layer: EditorLayer = null
	for layer in editor.timeline.get_layers():
		if layer.layer_name == "Paths":
			spline_layer = layer
			break
	
	var selected := get_selected()
	var start_time = get_playhead_position()
	if selected:
		start_time = selected[0].data.time
	
	if spline_layer:
		if self.selected_path:
			editor.timeline.change_layer_visibility(true, spline_layer.layer_name)
			
			spline_layer.clear_items()
			
			var item = self.selected_path.get_timeline_item()
			
			item.editor = editor
			item.call_deferred("set_path", self.selected_path)
			item.set_start(start_time)
			
			spline_layer.add_child(item)
		else:
			editor.timeline.change_layer_visibility(false, spline_layer.layer_name)
			
			spline_layer.clear_items()

func update_parameters():
	update_segment_name()
	
	var control_panel_style = StyleBoxFlat.new()
	control_panel_style.bg_color = Color.TRANSPARENT
	
	var spline_type = UserSettings.user_settings.editor_last_spline_type
	if self.selected_segment:
		spline_type = self.selected_segment.id
		
		selected_spline_label.text = "Selected spline parameters..."
		
		control_panel_style.border_color = UserSettings.user_settings.editor_selected_spline_color
		
		control_panel_style.border_width_left = 3
		control_panel_style.border_width_right = 3
		control_panel_style.border_width_top = 3
		control_panel_style.border_width_bottom = 3
	else:
		selected_spline_label.text = "New spline parameters..."
	
	spline_control_panel.add_theme_stylebox_override("panel", control_panel_style)
	
	if spline_type == HBPaths.PATH_ID.CARDINAL_SPLINE:
		cardinal_controls.show()
		
		if self.selected_segment:
			cardinal_smoothness_slider.set_value_no_signal(self.selected_segment.curve_smoothness)
		else:
			cardinal_smoothness_slider.set_value_no_signal(UserSettings.user_settings.editor_last_cardinal_smoothness)
	else:
		cardinal_controls.hide()
	
	if spline_type == HBPaths.PATH_ID.CIRCLE_SEGMENT:
		circle_controls.show()
		
		if self.selected_segment:
			circle_direction_option_button.selected = 0 if self.selected_segment.clockwise else 1
			
			circle_angle_slider.set_value_no_signal(self.selected_segment.angle)
		else:
			circle_direction_option_button.selected = 0 if UserSettings.user_settings.editor_circle_segment_clockwise else 1
			
			circle_angle_slider.set_value_no_signal(UserSettings.user_settings.editor_last_circle_segment_angle)
	else:
		circle_controls.hide()
	
	if spline_type == HBPaths.PATH_ID.PERIODIC_FN:
		function_controls.show()
		
		if self.selected_segment:
			function_type_option_button.selected = self.selected_segment.function_type
			
			peak_count_slider.set_value_no_signal(self.selected_segment.peak_count)
		else:
			function_type_option_button.selected = UserSettings.user_settings.editor_last_periodic_fn_type
			
			peak_count_slider.set_value_no_signal(UserSettings.user_settings.editor_last_periodic_fn_peak_count)
	else:
		function_controls.hide()

func update_segment_name():
	segment_name_line_edit.editable = true
	
	if self.selected_segment:
		segment_name_line_edit.text = self.selected_segment.name
	else:
		if path_preview.new_segment and path_preview.adding_segment:
			segment_name_line_edit.text = path_preview.new_segment.name
		else:
			segment_name_line_edit.editable = false
			
			var new_segment = get_new_segment_object()
			segment_name_line_edit.text = new_segment.name
	
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
		for i in path.segments.size():
			var segment := path.segments[i]
			
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
			
			if segment is HBPaths.HBBezierSpline and not segment is HBPaths.HBCardinalSpline:
				if not segment is HBPaths.HBContinuousBezierSpline or i == 0:
					create_control_node_item.call("First control node", "control_a")
				
				create_control_node_item.call("Second control node", "control_b")
			
			if segment is HBPaths.HBPeriodicSpline:
				create_control_node_item.call("Amplitude control node", "amplitude")
			
			create_control_node_item.call("End position", "end_position")
			
			segment.set_meta("paths_module", self)
			last_segment = segment

func _on_path_edit_tree_cell_selected() -> void:
	var selected_item = path_edit_tree.get_selected()
	
	if selected_item.has_meta("path"):
		selected_path = selected_item.get_meta("path")
		selected_segment = null
	
	if selected_item.has_meta("segment"):
		var spline = selected_item.get_meta("segment")
		
		path_type_control_group.select(spline.id)
		
		select_spline(spline)
	
	if selected_item.has_meta("control_property"):
		var widget = selected_item.get_meta("widget", null)
		
		if widget:
			path_preview.selected_widget = widget
			widget.select()
	
	path_preview.update_widgets()
	
	update_parameters()

func _on_path_type_selected(idx: int):
	UserSettings.user_settings.editor_last_spline_type = idx
	UserSettings.save_user_settings()
	
	if self.selected_segment:
		var new_segment_idx := selected_path.segments.find(self.selected_segment)
		var selected_path_idx = self.open_path.paths.find(selected_path)
		
		var set_new_spline_type := func(old_spline):
			var new_spline = get_new_segment_object(idx)
			
			if new_spline is HBPaths.HBBezierSpline and old_spline is HBPaths.HBBezierSpline:
				new_spline.control_a = old_spline.control_a
				new_spline.control_b = old_spline.control_b
			elif new_spline is HBPaths.HBBezierSpline:
				new_spline.offset_start_to_point(old_spline.start_position)
				new_spline.offset_end_to_point(old_spline.end_position)
			
			new_spline.start_position = old_spline.start_position
			new_spline.end_position = old_spline.end_position
			
			self.open_path.paths[selected_path_idx].segments.remove_at(new_segment_idx)
			self.open_path.paths[selected_path_idx].segments.insert(new_segment_idx, new_spline)
			
			select_spline(new_spline)
		
		var undo := func(old_spline):
			self.open_path.paths[selected_path_idx].segments.remove_at(new_segment_idx)
			self.open_path.paths[selected_path_idx].segments.insert(new_segment_idx, old_spline)
		
		undo_redo.create_action("Change spline type.")
		
		undo_redo.add_do_method(set_new_spline_type.bind(self.selected_segment))
		undo_redo.add_undo_method(undo.bind(self.selected_segment))
		
		undo_redo.add_do_method(update_parameters)
		undo_redo.add_undo_method(update_parameters)
		
		undo_redo.add_do_method(Callable(call_deferred).bind("update_preview"))
		undo_redo.add_undo_method(Callable(call_deferred).bind("update_preview"))
		
		undo_redo.commit_action()
	
	if path_preview.adding_segment:
		_start_creating_segment()
	
	update_parameters()

func _on_lock_distance_selected(idx: int):
	var lock_spline_distance := true if idx == 0 else false
	
	UserSettings.user_settings.editor_lock_spline_distance = lock_spline_distance
	UserSettings.save_user_settings()

func _start_creating_segment():
	self.selected_segment = null
	path_preview.selected_segment = null
	
	var new_segment = get_new_segment_object()
	new_segment.set_meta("adding", true)
	path_preview.new_segment = new_segment
	path_preview.adding_segment = true
	
	path_type_control_group.select(new_segment.id)
	
	path_preview.update_split_widget()
	
	path_preview.update_preview()
	path_preview.rebuild_widgets()
	
	update_parameters()

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

func _on_split_spline(spline: HBPaths.HBSpline, point: Vector2, t_value: float):
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

func _on_segment_name_changed() -> void:
	if self.selected_segment:
		undo_redo.create_action("Rename spline.")
		
		undo_redo.add_do_property(self.selected_segment, "name", segment_name_line_edit.text)
		undo_redo.add_undo_property(self.selected_segment, "name", self.selected_segment.name)
		
		undo_redo.commit_action()
	elif path_preview.new_segment:
		path_preview.new_segment.name = segment_name_line_edit.text

func _on_cardinal_smoothness_changed(value: float) -> void:
	value = clamp(value, 0.0, 1.0)
	
	UserSettings.user_settings.editor_last_cardinal_smoothness = value
	UserSettings.save_user_settings()
	
	if self.selected_segment and self.selected_segment is HBPaths.HBCardinalSpline:
		undo_redo.create_action("Edit cardinal spline's smoothness.", UndoRedo.MERGE_ENDS)
		
		undo_redo.add_do_property(self.selected_segment, "curve_smoothness", value)
		undo_redo.add_undo_property(self.selected_segment, "curve_smoothness", self.selected_segment.curve_smoothness)
		
		undo_redo.add_do_method(update_preview)
		undo_redo.add_undo_method(update_preview)
		
		undo_redo.commit_action()
	else:
		if path_preview.new_segment and path_preview.new_segment is HBPaths.HBCardinalSpline:
			path_preview.new_segment.curve_smoothness = value
		
		update_preview()

func _on_circle_angle_changed(value: float) -> void:
	value = clamp(value, 0.0, 360.0)
	
	UserSettings.user_settings.editor_last_circle_segment_angle = value
	UserSettings.save_user_settings()
	
	if self.selected_segment and self.selected_segment is HBPaths.HBCircularSpline:
		undo_redo.create_action("Edit circle segment's angle.", UndoRedo.MERGE_ENDS)
		
		undo_redo.add_do_property(self.selected_segment, "angle", value)
		undo_redo.add_undo_property(self.selected_segment, "angle", self.selected_segment.angle)
		
		undo_redo.add_do_method(update_preview)
		undo_redo.add_undo_method(update_preview)
		
		undo_redo.commit_action()
	else:
		if path_preview.new_segment and path_preview.new_segment is HBPaths.HBCircularSpline:
			path_preview.new_segment.angle = value
		
		update_preview()

func _on_circle_direction_selected(idx: int):
	var circle_direction := true if idx == 0 else false
	
	UserSettings.user_settings.editor_circle_segment_clockwise = circle_direction
	UserSettings.save_user_settings()
	
	if self.selected_segment and self.selected_segment is HBPaths.HBCircularSpline:
		undo_redo.create_action("Edit circle segment's direction.")
		
		undo_redo.add_do_property(self.selected_segment, "clockwise", circle_direction)
		undo_redo.add_undo_property(self.selected_segment, "clockwise", self.selected_segment.clockwise)
		
		undo_redo.add_do_method(update_preview)
		undo_redo.add_undo_method(update_preview)
		
		undo_redo.commit_action()
	else:
		if path_preview.new_segment and path_preview.new_segment is HBPaths.HBCircularSpline:
			path_preview.new_segment.clockwise = circle_direction
		
		update_preview()

func _on_function_type_selected(idx: int):
	UserSettings.user_settings.editor_last_periodic_fn_type = idx
	UserSettings.save_user_settings()
	
	if self.selected_segment and self.selected_segment is HBPaths.HBPeriodicSpline:
		undo_redo.create_action("Edit periodic function's type.")
		
		undo_redo.add_do_property(self.selected_segment, "function_type", idx)
		undo_redo.add_undo_property(self.selected_segment, "function_type", self.selected_segment.function_type)
		
		undo_redo.add_do_method(update_preview)
		undo_redo.add_undo_method(update_preview)
		
		undo_redo.commit_action()
	else:
		if path_preview.new_segment and path_preview.new_segment is HBPaths.HBPeriodicSpline:
			path_preview.new_segment.function_type = idx
		
		update_preview()

func _on_peak_count_changed(value: float) -> void:
	value = int(clamp(value, 1.0, 31.0))
	
	UserSettings.user_settings.editor_last_periodic_fn_peak_count = value
	UserSettings.save_user_settings()
	
	if self.selected_segment and self.selected_segment is HBPaths.HBPeriodicSpline:
		undo_redo.create_action("Edit periodic function's frequency.", UndoRedo.MERGE_ENDS)
		
		undo_redo.add_do_property(self.selected_segment, "peak_count", value)
		undo_redo.add_undo_property(self.selected_segment, "peak_count", self.selected_segment.peak_count)
		
		undo_redo.add_do_method(update_preview)
		undo_redo.add_undo_method(update_preview)
		
		undo_redo.commit_action()
	else:
		if path_preview.new_segment and path_preview.new_segment is HBPaths.HBPeriodicSpline:
			path_preview.new_segment.peak_count = value
		
		update_preview()
