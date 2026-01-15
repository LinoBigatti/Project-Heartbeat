extends Control

class_name HBEditorPathPreview

signal create_spline(spline)
signal split_spline(spline, point: Vector2, t_value: float)

@onready var clip_mask = get_node("Control")

var editor : set = set_editor
var paths_module : set = set_paths_module

var paths: Array[HBPaths.HBPath] = []
var selected_path: HBPaths.HBPath = null
var selected_segment: HBPaths.HBSpline = null
var clipped_segments: Array[HBPaths.HBLinearPath] = []
var control_widgets: Array[HBEditorWidget] = []
var selected_widget: HBEditorWidget = null

var adding_segment := false
var new_segment: HBPaths.HBSpline = null
var new_segment_widgets:  Array[HBEditorWidget] = []
var min_distance_segment: Dictionary = {"point": null, "segment": null, "spline": null, "distance": INF}
var split_widget: HBEditorWidget = null

func _init():
	pass

func _ready():
	get_viewport().connect("size_changed", Callable(self, "_on_resized"))
	
	set_process(true)

func _input(event):
	pass

func _process(delta):
	var parent = get_parent()
	clip_mask.position = Vector2.ZERO
	clip_mask.size = Vector2(1920, 1080)
	
	var clip = clip_mask.get_global_rect().intersection(parent.get_global_rect())
	
	clip_mask.global_position = clip.position
	clip_mask.size = clip.size
	
	queue_redraw()
	
	set_process(false)

func _on_resized():
	await get_tree().process_frame
	update_widgets()
	call_deferred("update_preview")
	
	set_process(true)

func _on_gizmo_dragged(_delta):
	_on_resized()

func _on_update_preview():
	_on_resized()
	
	queue_redraw()

func _widget_area_input(event: InputEvent):
	if not adding_segment or not selected_path:
		return
	
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = editor.game_preview.widget_area.get_local_mouse_position()
		
		var position_control_points: Array[Vector2] = []
		
		min_distance_segment = {"point": null, "segment": null, "spline": null, "distance": INF}
		for segment_preview in clipped_segments:
			if segment_preview.get_meta("segment", null) == self.new_segment:
				continue
			
			var spline: HBPaths.HBSpline = segment_preview.get_meta("segment")
			if spline.get_meta("adding", false) or not segment_preview.get_meta("selected", false):
				continue
			
			position_control_points.append(editor.rhythm_game.remap_coords(spline.start_position))
			position_control_points.append(editor.rhythm_game.remap_coords(spline.end_position))
			
			for i in range(segment_preview.points.size()):
				var point := segment_preview.points[i]
				var t := segment_preview.t_values[i]
				
				var distance := mouse_pos.distance_to(point)
				
				if distance < min_distance_segment.distance:
					min_distance_segment = {"point": point, "t": t, "segment": segment_preview, "spline": spline, "distance": distance}
		
		if min_distance_segment.point in position_control_points:
			min_distance_segment["at_position_node"] = true
		
		update_split_widget()

func set_editor(_editor):
	editor = _editor

func set_paths_module(_paths_module):
	paths_module = _paths_module

func set_path(_selected_path: HBPaths.HBPath, _segment: HBPaths.HBSpline, _paths: Array[HBPaths.HBPath]):
	self.selected_segment = _segment
	self.paths = _paths
	
	var rebuild_widgets := false
	if (self.selected_path != _selected_path) or (not _selected_path):
		self.selected_path = _selected_path
		
		rebuild_widgets = true
	
	update_preview()
	
	if rebuild_widgets:
		rebuild_widgets()
	
	queue_redraw()

func add_control_property_widget(spline: HBPaths.HBSpline, control_property: StringName) -> HBEditorWidget:
	var set_fn := func (pos): spline.set(control_property, pos)
	var get_fn := Callable(spline.get).bind(control_property)
	
	var widget_instance = add_control_point_widget(spline, set_fn, get_fn)
	widget_instance.control_property = control_property
	
	# Refresh widget's tree item
	if spline.has_meta(control_property):
		var control_node_item = spline.get_meta(control_property, null)
		if control_node_item:
			control_node_item.set_meta("widget", widget_instance)
	
	if spline.get_meta("adding", false):
		if control_property == "end_position":
			widget_instance.created.connect(_create_new_segment)
		
		widget_instance.set_meta("creating", true)
		new_segment_widgets.append(widget_instance)
	
	return widget_instance

func add_control_point_widget(spline: HBPaths.HBSpline, set_fn: Callable, get_fn: Callable) -> HBEditorWidget:
	var widget: PackedScene = spline.get_editor_widget()
	
	if widget:
		var widget_instance = widget.instantiate() as HBEditorPathControlWidget
		widget_instance.editor = self.editor
		widget_instance.paths_preview = self
		
		paths_module.add_preview_widget(widget_instance)
		
		var position: Vector2 = get_fn.call()
		widget_instance.position = editor.rhythm_game.remap_coords(position) - widget_instance.size / 2
		
		widget_instance.movement_gizmo.connect("dragged", _on_gizmo_dragged)
		widget_instance.set_spline(spline)
		
		widget_instance.connect("update_preview", _on_update_preview)
		widget_instance.connect("position_changed", set_fn)
		widget_instance.set_meta("refresh_fn", func (): return editor.rhythm_game.remap_coords(get_fn.call()))
		
		control_widgets.append(widget_instance)
		
		return widget_instance
	
	return null

func clear_widgets():
	for widget in control_widgets:
		widget.queue_free()
	
	control_widgets.clear()
	new_segment_widgets.clear()
	
	if split_widget:
		split_widget.queue_free()
		
		split_widget = null

func clear_preview():
	for segment in clipped_segments:
		segment.queue_free()
	
	clipped_segments.clear()

func update_widgets():
	if not self.selected_path:
		return
	
	for widget in control_widgets:
		widget.get_tree_item()
		
		if widget != self.selected_widget:
			widget.deselect()
		
		var color = UserSettings.user_settings.editor_spline_color
		if  (self.selected_segment and widget.spline == self.selected_segment) or \
			(self.adding_segment and widget.spline == self.new_segment and widget.control_property == "end_position"):
			color = UserSettings.user_settings.editor_selected_spline_color
		if widget.movement_gizmo.disabled:
			color = UserSettings.user_settings.editor_disabled_spline_color
		
		widget.line_color = color
		
		if self.new_segment and widget.spline == self.new_segment:
			if self.split_widget and self.split_widget.visible:
				widget.hide()
			else:
				widget.show()
		
		var refresh_fn = widget.get_meta("refresh_fn")
		
		if refresh_fn:
			var new_pos = refresh_fn.call()
			
			widget.position = new_pos - widget.size / 2
		
		widget.queue_redraw()
	
	update_split_widget()

func rebuild_widgets():
	self.clear_widgets()
	
	if not self.selected_path:
		return
	
	var segments: Array[HBPaths.HBSpline] = []
	
	segments.append_array(self.selected_path.segments)
	if self.new_segment:
		segments.append(self.new_segment)
	
	var last_widget = null
	for i in range(segments.size()):
		var segment = segments[i]
		
		var last_segment = null
		if i != 0:
			last_segment = segments[i - 1]
		
		var next_segment = null
		if i < segments.size() - 1:
			next_segment = segments[i + 1]
		
		var color = UserSettings.user_settings.editor_spline_color
		if self.selected_segment and segment == self.selected_segment:
			color = UserSettings.user_settings.editor_selected_spline_color
		
		var start_widget = null
		if not last_segment:
			start_widget = add_control_property_widget(segment, "start_position")
			start_widget.line_color = color
		
		var end_widget = add_control_property_widget(segment, "end_position")
		end_widget.line_color = color
		if segment.has_meta("adding") and segment.get_meta("adding", false):
			end_widget.line_color = UserSettings.user_settings.editor_selected_spline_color
		
		if segment is HBPaths.HBBezierSpline:
			var control_b = add_control_property_widget(segment, "control_b")
			control_b.line_color = color
			control_b.connect_to_widget(end_widget)
			
			var control_a = add_control_property_widget(segment, "control_a")
			control_a.line_color = color
			
			if last_widget:
				control_a.connect_to_widget(last_widget)
			else:
				if start_widget:
					control_a.connect_to_widget(start_widget)
			
			if segment is HBPaths.HBContinuousBezierSpline and last_segment:
				control_a.disable()
				
				var refresh_fn = func():
					segment.update_control_a(last_segment)
					
					return editor.rhythm_game.remap_coords(segment.get("control_a"))
				
				control_a.set_meta("refresh_fn", refresh_fn)
			
			if segment is HBPaths.HBCardinalSpline:
				control_b.disable()
				
				var refresh_fn = func():
					segment.update_control_b(next_segment)
					
					return editor.rhythm_game.remap_coords(segment.get("control_b"))
				
				control_b.set_meta("refresh_fn", refresh_fn)
		
		if segment is HBPaths.HBPeriodicSpline:
			var amplitude_widget = add_control_point_widget(segment, segment.set_amplitude, segment.get_control_point)
			amplitude_widget.control_property = "amplitude"
			amplitude_widget.line_color = color
			
			if segment.has_meta("amplitude"):
				var control_node_item = segment.get_meta("amplitude", null)
				if control_node_item:
					control_node_item.set_meta("widget", amplitude_widget)
		
		last_widget = end_widget

func update_preview():
	self.clear_preview()
	
	if self.selected_path:
		var last_segment = self.selected_path.segments[-1]
		var new_segment_start = last_segment.end_position
		
		if self.new_segment:
			self.new_segment.offset_to_point(new_segment_start)
	
	var show_new_segment := self.adding_segment and self.new_segment and not (self.split_widget and self.split_widget.visible) as bool
	
	for path in self.paths:
		for i in range(path.segments.size()):
			var segment = path.segments[i]
			
			var last_segment = null
			if i != 0:
				last_segment = path.segments[i - 1]
			
			var next_segment = null
			if i < path.segments.size() - 1:
				next_segment = path.segments[i + 1]
			else:
				if show_new_segment and self.selected_path == path:
					next_segment = self.new_segment
			
			var color = UserSettings.user_settings.editor_disabled_spline_color
			if path == self.selected_path:
				color = UserSettings.user_settings.editor_spline_color
				if self.selected_segment and self.selected_segment == segment:
					color = UserSettings.user_settings.editor_selected_spline_color
			
			var segment_preview: HBPaths.HBLinearPath = segment.to_linear(last_segment, next_segment, color, UserSettings.user_settings.editor_spline_resolution)
			segment_preview.remap_coords(editor.rhythm_game.remap_coords)
			segment_preview.set_meta("segment", segment)
			
			if self.selected_path == path:
				segment_preview.set_meta("selected", true)
			
			clip_mask.add_child(segment_preview)
			
			clipped_segments.append(segment_preview)
			last_segment = segment
	
	if show_new_segment:
		var last_segment = self.selected_path.segments[-1]
		
		var segment_preview: HBPaths.HBLinearPath = self.new_segment.to_linear(last_segment, null, UserSettings.user_settings.editor_selected_spline_color, UserSettings.user_settings.editor_spline_resolution)
		segment_preview.remap_coords(editor.rhythm_game.remap_coords)
		segment_preview.set_meta("segment", self.new_segment)
		segment_preview.set_meta("selected", true)
		segment_preview.set_meta("dashed", true)
		
		clip_mask.add_child(segment_preview)
		
		clipped_segments.append(segment_preview)

func update_split_widget():
	var position := Vector2.ZERO
	if min_distance_segment.point:
		position = min_distance_segment.point
	
	if not self.split_widget:
		var spline := HBPaths.HBSpline.new()
		var widget: PackedScene = spline.get_editor_widget()
		
		if widget:
			var widget_instance = widget.instantiate() as HBEditorPathControlWidget
			widget_instance.editor = self.editor
			
			paths_module.add_preview_widget(widget_instance)
			
			self.split_widget = widget_instance
	
	if self.split_widget:
		self.split_widget.position = position - self.split_widget.size / 2
		
		self.split_widget.line_color = UserSettings.user_settings.editor_selected_spline_color
		
		if min_distance_segment.point and min_distance_segment.distance < UserSettings.user_settings.editor_spline_creation_deadzone:
			self.split_widget.show()
		else:
			self.split_widget.hide()
		
		self.split_widget.arrange_gizmo()
		self.split_widget.queue_redraw()

func _create_new_segment():
	if not self.adding_segment:
		return
	
	self.adding_segment = false
	self.new_segment.set_meta("adding", false)
	for widget in self.new_segment_widgets:
		widget.set_meta("creating", false)
	
	if split_widget and split_widget.visible and min_distance_segment.point:
		var point = editor.rhythm_game.inv_map_coords(min_distance_segment.point)
		
		split_spline.emit(min_distance_segment.spline, point, min_distance_segment.t)
	else:
		create_spline.emit(self.new_segment)
	
	self.new_segment = null
	self.min_distance_segment = {"point": null, "segment": null, "spline": null, "distance": INF}
