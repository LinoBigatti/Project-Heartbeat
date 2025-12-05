class_name HBPaths

class HBLinearPath:
	extends Control
	
	var points: PackedVector2Array
	var colors: PackedColorArray
	
	func _init():
		self.points = PackedVector2Array()
		self.colors = PackedColorArray()
		
	func _draw():
		var width = UserSettings.user_settings.editor_spline_width
		
		if fmod(width, 2) == 0:
			draw_polyline_colors(self.points, self.colors, UserSettings.user_settings.editor_spline_width, true)
		else:
			var correction := Vector2(0.5, 0.5)
			
			var _points := PackedVector2Array()
			_points.resize(self.points.size())
			for i in range(self.points.size()):
				_points[i] = self.points[i] + correction
			
			draw_polyline_colors(_points, self.colors, UserSettings.user_settings.editor_spline_width, true)
		
	func append(point: Vector2, color: Color):
		self.points.append(point)
		self.colors.append(color)
		
		queue_redraw()
	
	func remap_coords(f: Callable):
		for i in range(self.points.size()):
			self.points[i] = f.call(self.points[i])

class HBPath:
	extends HBSerializable
	
	var name: String = "Path"
	
	var segments: Array[HBSpline]
	
	var resolution: int = 50
	
	func _init():
		serializable_fields += [
			"name", 
			"segments", 
		]
	
	func to_linear() -> HBLinearPath:
		var path := HBLinearPath.new()
		
		var last_segment = null
		for segment in self.segments:
			segment.render_to_path(path, last_segment, Color("478cbf"), self.resolution)
			
			last_segment = segment

		return path

class HBSpline:
	extends HBSerializable
	
	var name: String
	
	var start_position: Vector2
	var end_position: Vector2
	
	func _init():
		self.name = "Straight Line"
		
		serializable_fields += [
			"name", 
			"start_position", "end_position", 
		]
	
	func get_editor_widget() -> PackedScene:
		return preload("res://tools/editor/widgets/PathControlWidget.tscn")
	
	func interpolate(t: float) -> Vector2:
		return start_position.lerp(end_position, t)
	
	func render_to_path(path: HBLinearPath, last_spline: HBSpline, color: Color, resolution: int):
		var dt: float = 1.0 / resolution
		
		if last_spline:
			self.start_position = last_spline.end_position
			
		for i in range(resolution):
			path.append(self.interpolate(i * dt), color)
		
		path.append(self.interpolate(1.0), color)
	
	func to_linear(last_spline: HBSpline, color: Color, resolution: int) -> HBLinearPath:
		var path := HBLinearPath.new()
		
		render_to_path(path, last_spline, color, resolution)
		
		return path

class HBBezierSpline:
	extends HBSpline
	
	var control_a: Vector2
	var control_b: Vector2
	
	func _init():
		self.name = "Bezier Curve"
		
		serializable_fields += [
			"control_a", "control_b", 
		]
	
	func interpolate(t: float) -> Vector2:
		return start_position.bezier_interpolate(control_a, control_b, end_position, t)

class HBContinuousBezierSpline:
	extends HBBezierSpline
	
	func _init():
		self.name = "C1 Bezier Curve"
	
	func render_to_path(path: HBLinearPath, last_spline: HBSpline, color: Color, resolution: int):
		if last_spline:
			self.control_a = self.start_position + (self.start_position - last_spline.control_b)
		
		super(path, last_spline, color, resolution)
