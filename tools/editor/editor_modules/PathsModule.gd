extends HBEditorModule

@onready var path_preview := get_node("PathPreview")

var path

func _ready():
	super._ready()
	
	add_shortcut("editor_apply_path", "_toggle_path_preview")
	
	path = HBPaths.HBPath.new()
	
	var segment = HBPaths.HBBezierSpline.new()
	segment.start_position = Vector2(990, 540)
	segment.end_position = Vector2(1200, 790)
	segment.control_a = Vector2(1100, 600)
	segment.control_b = Vector2(1150, 700)
	path.segments.append(segment)
	segment = HBPaths.HBContinuousBezierSpline.new()
	segment.lock_to_last_position = true
	segment.start_position = Vector2(1200, 790)
	segment.end_position = Vector2(1500, 900)
	#segment.control_a = Vector2(1300, 900)
	segment.control_b = Vector2(1400, 900)
	path.segments.append(segment)
	
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
		path_preview.set_path(path)
		path_preview.show()
