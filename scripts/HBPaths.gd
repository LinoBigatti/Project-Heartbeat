class_name HBPaths

enum PATH_ID {
	LINEAR = 0,
	BEZIER,
	C2_BEZIER,
	CARDINAL_SPLINE,
	CIRCLE_SEGMENT,
	PERIODIC_FN,
}

class HBLinearPath:
	extends Control
	
	const DASHED_SUBDIVISION := 17
	
	var points: PackedVector2Array
	var colors: PackedColorArray
	var t_values: PackedFloat64Array
	
	func _init():
		self.points = PackedVector2Array()
		self.colors = PackedColorArray()
		self.t_values = PackedFloat64Array()
		
	func _draw():
		var width = UserSettings.user_settings.editor_spline_width
		
		var draw_segments: Array[PackedVector2Array] = []
		if get_meta("dashed", false):
			var slice_size = self.points.size() / DASHED_SUBDIVISION
			
			for i in range(DASHED_SUBDIVISION):
				if i % 2 == 0:
					draw_segments.append(self.points.slice(i * slice_size, (i + 1) * slice_size))
		else:
			draw_segments.append(self.points)
		
		for segment in draw_segments:
			if fmod(width, 2) == 0:
				draw_polyline_colors(segment, self.colors, UserSettings.user_settings.editor_spline_width, true)
			else:
				var correction := Vector2(0.5, 0.5)
				
				var _points := PackedVector2Array()
				_points.resize(segment.size())
				for i in range(segment.size()):
					_points[i] = segment[i] + correction
				
				draw_polyline_colors(_points, self.colors, UserSettings.user_settings.editor_spline_width, true)
			
	func append(point: Vector2, color: Color, t: float):
		self.points.append(point)
		self.colors.append(color)
		self.t_values.append(t)
		
		queue_redraw()
	
	func remap_coords(f: Callable):
		for i in range(self.points.size()):
			self.points[i] = f.call(self.points[i])

class HBPath:
	extends HBSerializable
	
	var name: String = "Subpath"
	
	var segments: Array[HBSpline]
	
	var resolution: int = 50
	
	func _init():
		serializable_fields += [
			"name", 
			"segments", 
		]

class HBSpline:
	extends HBSerializable
	
	var id: PATH_ID
	
	var name: String
	
	var start_position: Vector2
	var end_position: Vector2
	
	func _init():
		self.id = PATH_ID.LINEAR
		
		self.name = "Straight Line" 
		
		self.start_position = Vector2.ZERO
		self.end_position = Vector2(128, 64)
		
		serializable_fields += [
			"name", 
			"start_position", "end_position", 
		]
	
	func get_editor_widget() -> PackedScene:
		return preload("res://tools/editor/widgets/PathControlWidget.tscn")
	
	func interpolate(t: float) -> Vector2:
		return start_position.lerp(end_position, t)
	
	func render_to_path(path: HBLinearPath, last_spline: HBSpline, next_spline: HBSpline, color: Color, resolution: int):
		var dt: float = 1.0 / resolution
		
		if last_spline:
			self.start_position = last_spline.end_position
			
		for i in range(resolution):
			var t := i * dt
			path.append(self.interpolate(t), color, t)
		
		path.append(self.end_position, color, 1.0)
	
	func to_linear(last_spline: HBSpline, next_spline: HBSpline, color: Color, resolution: int) -> HBLinearPath:
		var path := HBLinearPath.new()
		
		render_to_path(path, last_spline, next_spline, color, resolution)
		
		return path
	
	func offset_to_point(new_start_position: Vector2):
		var end_pos_rel = self.end_position - self.start_position
		
		self.start_position = new_start_position
		self.end_position = new_start_position + end_pos_rel
	
	func offset_start_to_point(new_start_position: Vector2):
		self.start_position = new_start_position
	
	func offset_end_to_point(new_end_position: Vector2):
		self.end_position = new_end_position
	
	func split_at(point: Vector2, t_value: float) -> Array[HBSpline]:
		var new_spline_a := HBSpline.new()
		var new_spline_b := HBSpline.new()
		
		new_spline_a.start_position = self.start_position
		new_spline_a.end_position = point
		
		new_spline_b.start_position = point
		new_spline_b.end_position = self.end_position
		
		return [new_spline_a, new_spline_b]
	
	func approximate_control_a() -> Vector2:
		var dt := 0.01
		
		var pos_a := self.start_position
		var pos_b := interpolate(dt)
		
		var derivative_2d := (pos_b - pos_a) / dt
		var length = clamp(derivative_2d.length(), 0.0, 512.0)
		derivative_2d = derivative_2d.normalized() * length
		
		return self.start_position + derivative_2d * 0.5
	
	func approximate_control_b() -> Vector2:
		var dt := 0.01
		
		var pos_a := interpolate(1.0 - dt)
		var pos_b := self.end_position
		
		var derivative_2d := (pos_b - pos_a) / dt
		var length = clamp(derivative_2d.length(), 0.0, 512.0)
		derivative_2d = derivative_2d.normalized() * length
		
		return self.end_position - derivative_2d * 0.5

class HBBezierSpline:
	extends HBSpline
	
	var control_a: Vector2
	var control_b: Vector2
	
	func _init():
		super()
		
		self.id = PATH_ID.BEZIER
		
		self.name = "Bezier Curve"
		
		self.control_a = Vector2(32, 64)
		self.control_b = Vector2(96, 128)
		
		serializable_fields += [
			"control_a", "control_b", 
		]
	
	func interpolate(t: float) -> Vector2:
		return start_position.bezier_interpolate(control_a, control_b, end_position, t)
	
	func offset_to_point(new_start_position: Vector2):
		var end_pos_rel = self.end_position - self.start_position
		var control_a_rel = self.control_a - self.start_position
		var control_b_rel = self.control_b - self.start_position
		
		self.start_position = new_start_position
		self.end_position = new_start_position + end_pos_rel
		self.control_a = new_start_position + control_a_rel
		self.control_b = new_start_position + control_b_rel
	
	func offset_start_to_point(new_start_position: Vector2):
		var control_a_rel = self.control_a - self.start_position
		
		self.start_position = new_start_position
		self.control_a = new_start_position + control_a_rel
	
	func offset_end_to_point(new_end_position: Vector2):
		var control_b_rel = self.control_b - self.end_position
		
		self.end_position = new_end_position
		self.control_a = new_end_position + control_b_rel
	
	func split_at(point: Vector2, t_value: float) -> Array[HBSpline]:
		var new_spline_a := HBBezierSpline.new()
		var new_spline_b := HBBezierSpline.new()
		
		# By constructing the bezier spline manually using linear interpolation
		# we can find a set of intermediate control points that represent the
		# exact same curve but split at the given t value.
		var start_to_a := self.start_position.lerp(self.control_a, t_value)
		var a_to_b     := self.control_a.lerp(self.control_b, t_value)
		var b_to_end   := self.control_b.lerp(self.end_position, t_value)
		
		var sa_to_ab := start_to_a.lerp(a_to_b, t_value)
		var ab_to_be := a_to_b.lerp(b_to_end, t_value)
		
		new_spline_a.control_a = start_to_a
		new_spline_a.control_b = sa_to_ab
		
		new_spline_b.control_a = ab_to_be
		new_spline_b.control_b = b_to_end
		
		new_spline_a.start_position = self.start_position
		new_spline_a.end_position = point
		
		new_spline_b.start_position = point
		new_spline_b.end_position = self.end_position
		
		return [new_spline_a, new_spline_b]
	
	func approximate_control_a() -> Vector2:
		return self.control_a
	
	func approximate_control_b() -> Vector2:
		return self.control_b

class HBContinuousBezierSpline:
	extends HBBezierSpline
	
	func _init():
		super()
		
		self.id = PATH_ID.C2_BEZIER
		
		self.name = "C1 Bezier Curve"
	
	func update_control_a(last_spline: HBSpline):
		if last_spline:
			self.control_a = self.start_position + (self.start_position - last_spline.approximate_control_b())
	
	func render_to_path(path: HBLinearPath, last_spline: HBSpline, next_spline: HBSpline, color: Color, resolution: int):
		update_control_a(last_spline)
		
		super(path, last_spline, next_spline, color, resolution)

class HBCardinalSpline:
	extends HBContinuousBezierSpline
	
	var curve_smoothness: float = 0.5
	
	func _init():
		super()
		
		self.id = PATH_ID.CARDINAL_SPLINE
		
		self.name = "Cardinal Spline"
		
		serializable_fields += [
			"curve_smoothness", 
		]
	
	func update_control_a(last_spline: HBSpline):
		if last_spline:
			var control_point: Vector2
			
			if last_spline is HBCardinalSpline:
				control_point = ((self.end_position - last_spline.start_position) * self.curve_smoothness) / 3.0 as Vector2
			else:
				control_point = self.start_position - last_spline.approximate_control_b()
			
			self.control_a = self.start_position + control_point
		else:
			var prev_point := self.start_position + (self.start_position - self.end_position) as Vector2
			var control_point := ((self.end_position - prev_point) * self.curve_smoothness) / 3.0 as Vector2
			
			self.control_a = self.start_position + control_point
	
	func update_control_b(next_spline: HBSpline):
		if next_spline:
			var control_point: Vector2
			
			if next_spline is HBCardinalSpline:
				control_point = ((next_spline.end_position - self.start_position) * self.curve_smoothness) / 3.0
			else:
				control_point = (self.end_position - next_spline.approximate_control_a()) * -1
			
			self.control_b = self.end_position - control_point
		else:
			var next_point := self.end_position + (self.end_position - self.start_position) as Vector2
			var control_point := ((next_point - self.start_position) * self.curve_smoothness) / 3.0 as Vector2
			
			self.control_b = self.end_position - control_point
	
	func render_to_path(path: HBLinearPath, last_spline: HBSpline, next_spline: HBSpline, color: Color, resolution: int):
		update_control_a(last_spline)
		update_control_b(next_spline)
		
		super(path, last_spline, next_spline, color, resolution)

class HBCircularSpline:
	extends HBSpline
	
	var angle: float
	var clockwise: bool
	
	func _init():
		super()
		
		self.id = PATH_ID.CIRCLE_SEGMENT
		
		self.name = "Circular Segment"
		
		self.angle = 180.0
		self.clockwise = true
		
		serializable_fields += [
			"angle", "clockwise", 
		]
	
	func interpolate(t: float) -> Vector2:
		# Get the angles from each point to the circle center
		var complementary_angle := deg_to_rad((180.0 - self.angle) / 2)
		
		# Construct the circle center with some basic trigonometry
		var horizontal_vector_to_center := (self.end_position - self.start_position) / 2
		var radius := horizontal_vector_to_center.length() / cos(complementary_angle)
		
		var line_center := self.start_position + horizontal_vector_to_center
		var horizontal_direction_to_center := horizontal_vector_to_center.normalized()
		
		var vertical_distance_to_center := radius * sin(complementary_angle)
		var vertical_vector_to_center := horizontal_direction_to_center.rotated(PI / 2) * vertical_distance_to_center
		if not self.clockwise:
			vertical_vector_to_center *= -1
		
		var circle_center := line_center + vertical_vector_to_center
		
		var start_angle := fposmod(circle_center.angle_to_point(self.start_position), 2 * PI)
		
		# Make sure the circle has the correct direction
		var end_angle := start_angle + deg_to_rad(self.angle)
		if not self.clockwise:
			end_angle = start_angle - deg_to_rad(self.angle)
		
		var theta := lerpf(start_angle, end_angle, t)
		
		return circle_center + Vector2(cos(theta), sin(theta)) * radius
	
	func split_at(point: Vector2, t_value: float) -> Array[HBSpline]:
		var new_spline_a := HBCircularSpline.new()
		var new_spline_b := HBCircularSpline.new()
		
		new_spline_a.clockwise = self.clockwise
		new_spline_b.clockwise = self.clockwise
		
		var start_angle := self.angle if self.clockwise else 0.0
		var end_angle := 0.0 if self.clockwise else self.angle
		var theta := lerpf(start_angle, end_angle, t_value)
		
		new_spline_a.angle = self.angle - theta
		new_spline_b.angle = theta
		
		new_spline_a.start_position = self.start_position
		new_spline_a.end_position = point
		
		new_spline_b.start_position = point
		new_spline_b.end_position = self.end_position
		
		return [new_spline_a, new_spline_b]

class HBPeriodicSpline:
	extends HBSpline
	
	enum FUNC_TYPE {
		SINE,
		SAW,
		TRIANGLE,
		SQUARE,
	}
	
	var function_type: FUNC_TYPE
	var peak_count: int
	var amplitude: float
	
	func _init():
		super()
		
		self.id = PATH_ID.PERIODIC_FN
		
		self.name = "Periodic Function"
		
		self.function_type = FUNC_TYPE.TRIANGLE
		self.amplitude = 200.0
		self.peak_count = 3
		
		serializable_fields += [
			"function_type", "control_point", 
		]
	
	func interpolate(t: float) -> Vector2:
		var center := (self.start_position + self.end_position) / 2
		var radius := self.start_position.distance_to(center)
		
		var horizontal_pos := self.start_position.lerp(self.end_position, t)
		var vertical_vector := Vector2(1, 0).rotated(self.start_position.angle_to_point(self.end_position) - PI / 2)
		
		var start_angle := 0.0
		var end_angle := 2 * PI * self.peak_count
		var theta := lerpf(start_angle, end_angle, t)
		
		var function_value := 0.0
		match self.function_type:
			FUNC_TYPE.SINE:
				function_value = sin(theta)
			FUNC_TYPE.SAW:
				# Saw wave with a period of 2PI
				var period := 2 * PI
				
				function_value = -2 * ((theta / period) - floor(0.5 + theta / period)) as float
			FUNC_TYPE.TRIANGLE:
				# Triangle wave with a period of 2PI
				# We need to offset the wave by PI/2 because this equation
				# creates a wave with the same phase as a cosine function.
				var period := 2 * PI
				theta += PI / 2
				
				function_value = 2 * abs(2 * ((theta / period) - floor(0.5 + theta / period))) - 1 as float
			FUNC_TYPE.SQUARE:
				# Define square wave using the sign of a sine wave
				function_value = sign(sin(theta))
			_:
				pass
		
		return horizontal_pos + vertical_vector * function_value * amplitude
	
	func split_at(point: Vector2, t_value: float) -> Array[HBSpline]:
		# There is no real lossless way to split these splines, so we just
		# copy the parameters without any extra processing.
		
		var new_spline_a := HBPeriodicSpline.new()
		var new_spline_b := HBPeriodicSpline.new()
		
		new_spline_a.function_type = self.function_type
		new_spline_b.function_type = self.function_type
		
		new_spline_a.amplitude = self.amplitude
		new_spline_b.amplitude = self.amplitude
		
		new_spline_a.peak_count = self.peak_count
		new_spline_b.peak_count = self.peak_count
		
		new_spline_a.start_position = self.start_position
		new_spline_a.end_position = point
		
		new_spline_b.start_position = point
		new_spline_b.end_position = self.end_position
		
		return [new_spline_a, new_spline_b]
	
	func get_control_point() -> Vector2:
		var t := 1.0 / (self.peak_count * 4)
		if self.function_type == FUNC_TYPE.SAW:
			t = 1.0 / (self.peak_count * 2)
		
		return interpolate(t)
	
	func set_amplitude(control_point: Vector2) -> void:
		var straight_line := self.end_position - self.start_position
		var to_control_point := control_point - self.start_position
		
		var angle := straight_line.angle_to(to_control_point)
		var distance_to_line = -sin(angle) * to_control_point.length()
		
		self.amplitude = distance_to_line
