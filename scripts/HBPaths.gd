class_name HBPaths

class HBLinearPath:
	extends Control
	
	var points: PackedVector2Array
	var colors: PackedColorArray
	
	func _init():
		self.points = PackedVector2Array()
		self.colors = PackedColorArray()
		
	func _draw():
		draw_polyline_colors(self.points, self.colors, 6, true)
		
	func append(point: Vector2, color: Color):
		self.points.append(point)
		self.colors.append(color)
		
		queue_redraw()
	
	func remap_coords(f: Callable):
		for i in range(self.points.size()):
			self.points[i] = f.call(self.points[i])

class HBPath:
	extends HBSerializable

	var segments: Array[HBSpline]

	var resolution: int = 50

	func _init():
		serializable_fields += [
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

	var start_position: Vector2
	var end_position: Vector2

	var lock_to_last_position: bool

	func _init():
		serializable_fields += [
			"start_position", "end_position", 
			"lock_to_last_position", 
		]
	
	func get_editor_widget() -> PackedScene:
		return preload("res://tools/editor/widgets/PathControlWidget.tscn")
	
	func interpolate(t: float) -> Vector2:
		return start_position.lerp(end_position, t)
	
	func render_to_path(path: HBLinearPath, last_spline: HBSpline, color: Color, resolution: int):
		var dt: float = 1.0 / resolution
		
		if lock_to_last_position and last_spline:
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
		serializable_fields += [
			"control_a", "control_b", 
		]
	
	func interpolate(t: float) -> Vector2:
		return start_position.bezier_interpolate(control_a, control_b, end_position, t)

class HBContinuousBezierSpline:
	extends HBBezierSpline
	
	func render_to_path(path: HBLinearPath, last_spline: HBSpline, color: Color, resolution: int):
		if last_spline:
			self.control_a = self.start_position + (self.start_position - last_spline.control_b)
		
		super(path, last_spline, color, resolution)
