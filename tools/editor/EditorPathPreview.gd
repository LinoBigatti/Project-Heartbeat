extends Control

class_name HBEditorPathPreview

@onready var clip_mask = get_node("Control")

var editor : set = set_editor
var paths_module : set = set_paths_module

var path: HBPaths.HBPath
var clipped_segments: Array[HBPaths.HBLinearPath] = []
var control_widgets: Array[HBEditorWidget] = []

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
	
	if visible:
		pass
	
	queue_redraw()
	#set_process(false)

func _on_resized():
	await get_tree().process_frame
	call_deferred("update_preview")
	call_deferred("update_widgets")

func _on_gizmo_dragged(_delta):
	_on_resized()

func _on_update_preview():
	_on_resized()

func set_editor(_editor):
	editor = _editor

func set_paths_module(_paths_module):
	paths_module = _paths_module

func set_path(_path: HBPaths.HBPath):
	self.path = _path
	
	update_preview()
	rebuild_widgets()
	
	queue_redraw()

func add_control_point_widget(spline: HBPaths.HBSpline, control_property: StringName) -> HBEditorWidget:
	var widget: PackedScene = spline.get_editor_widget()
	
	if widget:
		var widget_instance = widget.instantiate() as HBEditorPathControlWidget
		widget_instance.editor = self.editor
		
		paths_module.add_preview_widget(widget_instance)
		
		var position: Vector2 = spline.get(control_property)
		widget_instance.starting_pos = position
		var new_pos = editor.rhythm_game.remap_coords(position)
		widget_instance.position = new_pos - widget_instance.size / 2
		
		widget_instance.movement_gizmo.connect("dragged", _on_gizmo_dragged)
		widget_instance.set_spline(spline)
		widget_instance.control_property = control_property
		
		widget_instance.connect("update_preview", _on_update_preview)
		widget_instance.connect("update_preview", _on_resized)
		widget_instance.connect("position_changed", func (pos): spline.set(control_property, pos))
		widget_instance.set_meta("refresh_fn", func (): return editor.rhythm_game.remap_coords(spline.get(control_property)))
		
		return widget_instance
	
	return null

func clear_widgets():
	for widget in control_widgets:
		widget.queue_free()
	
	control_widgets.clear()

func clear_preview():
	for segment in clipped_segments:
		segment.queue_free()
	
	clipped_segments.clear()

func update_widgets():
	if not self.path:
		return
	
	for widget in control_widgets:
		var refresh_fn = widget.get_meta("refresh_fn")
		
		if refresh_fn:
			var new_pos = refresh_fn.call()
			
			#widget.starting_pos = position
			widget.position = new_pos - widget.size / 2
			
			widget.queue_redraw()

func rebuild_widgets():
	self.clear_widgets()
	
	if not self.path:
		return
	
	var last_segment = null
	var last_widget = null
	for segment_preview in clipped_segments:
		var segment: HBPaths.HBSpline = segment_preview.get_meta("segment")
		
		var start_widget = null
		if not (last_segment and segment.lock_to_last_position):
			start_widget = add_control_point_widget(segment, "start_position")
			
			control_widgets.append(start_widget)
		
		var end_widget = add_control_point_widget(segment, "end_position")
		
		control_widgets.append(end_widget)
		
		if segment is HBPaths.HBBezierSpline:
			var control_b = add_control_point_widget(segment, "control_b")
			control_b.connect_to_widget(end_widget)
			
			control_widgets.append(control_b)
			
			var control_a = add_control_point_widget(segment, "control_a")
			
			if last_widget and segment.lock_to_last_position:
				control_a.connect_to_widget(last_widget)
			else:
				if start_widget:
					control_a.connect_to_widget(start_widget)
			
			if segment is HBPaths.HBContinuousBezierSpline:
				control_a.disable()
			
			control_widgets.append(control_a)
		
		last_segment = segment
		last_widget = end_widget

func update_preview():
	self.clear_preview()
	
	if not self.path:
		return
	
	var last_segment = null
	for segment in self.path.segments:
		var segment_preview: HBPaths.HBLinearPath = segment.to_linear(last_segment, Color("fffffff0"), 50)
		segment_preview.remap_coords(editor.rhythm_game.remap_coords)
		segment_preview.set_meta("segment", segment)
		
		clip_mask.add_child(segment_preview)
		
		clipped_segments.append(segment_preview)
		last_segment = segment
