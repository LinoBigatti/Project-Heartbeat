extends Control

class_name EditorTimelineItemSpline

signal time_changed

const DND_START_MARGIN = 25.0
const SIDE_MOVEMENT_DEADZONE = 10.0

var _class_name: String = "EditorTimelineItemSpline" # Workaround for godot#4708
var _inheritance: Array = []

var editor

var data = HBPaths.HBPath.new()

var _start_time := 0
var current_durations := {} 

var current_id: int

var _drag_start_position : Vector2
var _drag_start_time : float
var _drag_x_offset : float
var _drag_new_time : float
var _drag_moving = false
var _start_dragging = false
var _layer
var _drag_last

var _end_time_drag_start_position : Vector2
var _end_time_drag_start_time : float
var _end_time_drag_x_offset : float
var _end_time_drag_new_time : float
var _end_time_drag_moving = false
var _end_time_dragging = false
var _end_time_drag_i = 0
var _end_time_drag_last

var widget: HBEditorWidget

var _draw_selected_box = false

@onready var hack = get_node("TextureRect2/Control")

@onready var start_texture_rect = get_node("TextureRect")
@onready var end_texture_rect = get_node("TextureRect2")

var end_texture_rects := []

func _init():
	_class_name = "EditorTimelineItemSpline" # Workaround for godot#4708

func _ready():
	set_process(false)
	queue_redraw()
	RenderingServer.canvas_item_set_z_index(get_canvas_item(), 1)
	add_to_group("editor_timeline_items")
	
	set_texture()

func set_texture():
	start_texture_rect.set_deferred("size", Vector2(get_size().y, get_size().y))
	end_texture_rect.set_deferred("size", Vector2(get_size().y, get_size().y))
	
	for rect in end_texture_rects:
		rect.set_deferred("size", Vector2(get_size().y, get_size().y))
	
	_on_time_changed()

func set_start(value: int):
	if _start_time != value:
		_start_time = value
		emit_signal("time_changed")

func set_path(path: HBPaths.HBPath):
	data = path
	
	current_durations.clear()
	
	for rect in end_texture_rects:
		remove_child(rect)
		rect.queue_free()
	end_texture_rects.clear()
	
	if data and data.segments:
		for i in range(data.segments.size()):
			var segment = data.segments[i]
			if segment is HBPaths.HBSpline:
				current_durations[segment] = segment.get_duration()
				
				var rect := end_texture_rect.duplicate()
				
				add_child(rect)
				rect.show()
				rect.set_meta("idx", i)
				end_texture_rects.append(rect)
	
	_on_time_changed()

func get_editor_size():
	return Vector2(0, size.y)

func _draw():
	if _draw_selected_box:
		var selected_rect_size = Vector2(size.y, size.y) * 0.85
		var selected_square_rect = Rect2((Vector2(0.0, size.y) - selected_rect_size) / 2.0, selected_rect_size)
		draw_rect(selected_square_rect, Color.YELLOW, false, 1.0)
	
	if data and data is HBPaths.HBPath and data.segments:
		var current_start_time = _start_time
		
		for segment in data.segments:
			if segment is HBPaths.HBSpline:
				var width = 5
				var y = (start_texture_rect.size.y - width)/2
				
				var start = Vector2(editor.scale_msec(current_start_time), y)
				var draw_size = Vector2(editor.scale_msec(current_durations[segment]), width)
				var color = UserSettings.user_settings.editor_selected_spline_color
				
				draw_rect(Rect2(start, draw_size), color)
				
				hack.set_enable_hack(false)
				if global_position.x <= 0.0:
					hack.set_enable_hack(true)
					hack.run_uwu_hack(draw_size.x, color)
				
				current_start_time += current_durations[segment]

func _on_view_port_size_changed():
	if get_viewport():
		_on_time_changed()
		
func _on_time_changed():
	var current_end_time_ms = _start_time
	
	if data and data is HBPaths.HBPath and data.segments:
		start_texture_rect.position.x = editor.scale_msec(current_end_time_ms) - start_texture_rect.get_size().x / 2
		start_texture_rect.position.y = 0.0
		
		for rect in end_texture_rects:
			var segment = data.segments[rect.get_meta("idx")]
			current_end_time_ms += current_durations[segment]
			
			rect.position.x = editor.scale_msec(current_end_time_ms) - rect.get_size().x / 2
			rect.position.y = 0.0
	
	queue_redraw()

func _process(delta):
	var current_end_time = _start_time
	if data and data is HBPaths.HBPath and data.segments:
		if _start_dragging:
			var new_time = _drag_start_time + editor.scale_pixels(get_viewport().get_mouse_position().x - _drag_start_position.x)
			new_time = int(editor.snap_time_to_timeline(new_time))
			
			if abs(get_viewport().get_mouse_position().x - _drag_start_position.x) > SIDE_MOVEMENT_DEADZONE or _drag_moving:
				_drag_moving = true
				
				var drag_delta = new_time - _drag_last
				_drag_last = new_time
				
				if abs(drag_delta) > 0:
					if data.segments[0].placement_style == HBPaths.PLACEMENT_STYLE.LOCKED_DISTANCE:
						pass
					
					_start_time += drag_delta
					
					_on_time_changed()
		
		if _end_time_dragging:
			var new_time = _end_time_drag_start_time + editor.scale_pixels(get_viewport().get_mouse_position().x - _end_time_drag_start_position.x)
			new_time = int(editor.snap_time_to_timeline(new_time))
			
			for i in range(data.segments.size()):
				var segment = data.segments[i]
				current_end_time += current_durations[segment]
				
				if i != _end_time_drag_i:
					continue
				
				if abs(get_viewport().get_mouse_position().x - _end_time_drag_start_position.x) > SIDE_MOVEMENT_DEADZONE\
						or _end_time_drag_moving:
					_end_time_drag_moving = true
					
					var drag_delta = new_time - _end_time_drag_last
					_end_time_drag_last = new_time
					
					if current_end_time + drag_delta > _start_time:
						if abs(drag_delta) > 0:
							if segment.placement_style == HBPaths.PLACEMENT_STYLE.LOCKED_DISTANCE:
								pass
							
							current_durations[segment] += drag_delta
							
							_on_time_changed()

func _input(event):
	if editor.game_playback.is_playing():
		return
	
	var start_time = _start_time
	
	if get_start_click_rect().has_point(get_global_mouse_position()):
		if event.is_action_pressed("editor_select"): 
			_start_dragging = true
			_drag_moving = false
			_drag_start_position = get_viewport().get_mouse_position()
			_drag_start_time = start_time
			_drag_x_offset = (global_position - get_viewport().get_mouse_position()).x
			_drag_last = start_time
			set_process(true)
	
	if event.is_action_released("editor_select") and _start_dragging:
		_drag_moving = false
		if is_processing():
			set_process(false)
			_start_dragging = false
			if _drag_start_time != start_time:
				pass
	
	var current_end_time = start_time
	for rect in end_texture_rects:
		var idx = rect.get_meta("idx")
		var segment = data.segments[idx]
		current_end_time += current_durations[segment]
		
		if get_end_click_rect(rect).has_point(get_global_mouse_position()):
			if event.is_action_pressed("editor_select"):
				_end_time_dragging = true
				_end_time_drag_i = idx
				_end_time_drag_moving = false
				_end_time_drag_start_position = get_viewport().get_mouse_position()
				_end_time_drag_start_time = current_end_time
				_end_time_drag_x_offset = (global_position - get_viewport().get_mouse_position()).x
				_end_time_drag_last = current_end_time
				set_process(true)
		
		if event.is_action_released("editor_select") and _end_time_dragging and _end_time_drag_i == idx:
			_end_time_dragging = false
			
			if is_processing():
				set_process(false)
				
				data.segments[idx].duration_ms = current_durations[segment]

func sync_value(property_name: String):
	pass

func select():
	_draw_selected_box = true
	queue_redraw()

func deselect():
	_draw_selected_box = false
	queue_redraw()
	if widget:
		widget.queue_free()
		widget = null

func get_start_click_rect():
	var global_rect = get_global_rect()
	if start_texture_rect:
		global_rect = start_texture_rect.get_global_rect()
	
	return global_rect

func get_end_click_rect(rect: TextureRect):
	var global_rect = get_global_rect()
	if rect:
		global_rect = rect.get_global_rect()
	
	return global_rect
