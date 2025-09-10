class_name TOMLParser
## A parser for a subset of TOML.
## 
## As of now it only needs to support a reduced subset of TOML with some basic
## value types to properly parse mods. This could change in the future.
## It also does not support all key types: Only bare and dot keys will be parsed correctly.

## Parse a TOML string. Dot keys are only supported in table or array definitions.
static func parse(contents: String) -> Dictionary:
	print("================ TOML TIME ===============")
	print(contents)
	var _out := TOML.parse_string(contents)
	print(_out)
	_out.set("default", {})
	return _out
	
	var out := {"default": {}}
	
	var output_ref = out["default"]
	var last_output_ref = out["default"]
	
	var in_array = false
	
	var lines := contents.split("\n")
	for line in lines:
		# Array of tables
		if line.begins_with("[["):
			var key := line.substr(2, line.length() - 5) as String
			var new_sections = parse_key(key)
			var array_key = new_sections.pop_back()
			
			if not array_key:
				continue
			
			# Build inner representation of the object from the key data and get
			# an output reference to the parent table
			output_ref = out
			for section in new_sections:
				if output_ref.has(section):
					var new_ref = output_ref[section]
					
					if new_ref is Array and not new_ref.is_empty():
						# Set section to last defined object of this array
						output_ref = new_ref[-1]
					else:
						# Set section
						output_ref = new_ref
				else:
					output_ref[section] = {}
			
			# Create array if it doesnt exist
			if not output_ref.has(array_key):
				output_ref[array_key] = []
			
			# Create a new entry in the table and set the output reference
			output_ref[array_key].push_back({})
			output_ref = output_ref[array_key][-1]
			
			continue
		
		# Tables/sections
		if line.begins_with("["):
			var key := line.substr(1, line.length() - 2) as String
			var new_sections = parse_key(key)
			var table_key = new_sections.pop_back()
			
			if not table_key:
				continue
			
			# Build inner representation of the object from the key data and get
			# an output reference to the parent table
			output_ref = out
			for section in new_sections:
				if output_ref.has(section):
					var new_ref = output_ref[section]
					
					if new_ref is Array:
						# Set section to last defined object of this array
						output_ref = new_ref[-1]
					else:
						# Set section
						output_ref = new_ref
				else:
					output_ref[section] = {}
			
			output_ref[table_key] = {}
			output_ref = output_ref[table_key]
			
			continue
		
		# Split at the first = only
		var line_split = line.split("=", true, 1) as PackedStringArray
		if line_split.size() > 1:
			var line_key := line_split[0].strip_edges() as String
			var line_value := line_split[1].strip_edges() as String
			
			# Handle array values. NOTE: We do not check for values in the first 
			# or last line of the array. This is technically valid TOML, but the
			# parser would probably need to be rewritten to be recursive instead
			# of lines-based.
			if line_value.begins_with("["):
				if output_ref is Array:
					output_ref[line_key].append([])
				else:
					last_output_ref = output_ref
					output_ref[line_key] = []
					output_ref = output_ref[line_key]
				
				in_array = true
				
				pass
			
			if line_value.contains("]") and in_array:
				output_ref = last_output_ref
				
				in_array = false
				
				continue
			
			var value = parse_value(line_value)
			
			if value != null:
				if in_array:
					output_ref.append(value)
				else:
					output_ref[line_key] = value
	
	return out

## Parse a TOML value. This only supports strings, inline tables, booleans, and numeric types.
static func parse_value(value: String):
	# String literals
	if value.begins_with("\"") and value.ends_with("\""):
		return value.substr(1, value.length() - 2)
	
	# Inline tables
	if value.begins_with("{") and value.ends_with("}"):
		var fields = value.substr(1, value.length() - 2).split(",") as PackedStringArray
		var output = {}
		
		for field in fields:
			var line_split = field.split("=") as PackedStringArray
			
			if line_split.size() > 1:
				var line_key := line_split[0].strip_edges() as String
				var line_value := line_split[1].strip_edges() as String
				
				var _value = parse_value(line_value)
				
				if output != null:
					output[line_key] = _value
		
		return output
	
	# Boolean values
	if value == "true":
		return true
	if value == "false":
		return false
	
	# Integers and floats
	if value.is_valid_int():
		return value.to_int()
	if value.is_valid_float():
		return value.to_float()

## Parse an arbitrary key. Currently this only supports bare keys and dot keys
## See https://toml.io/en/v1.0.0#keys for more information.
## 
## Returns keys in an ordered array based on depth (a.b.c => ["a", "b", "c"]).
static func parse_key(key: String) -> Array:
	return key.split(".")

## Load and parse a TOML file.
static func from_file(path: String) -> Dictionary:
	var contents := ""

	var f := FileAccess.open(path, FileAccess.READ)
	if FileAccess.get_open_error() == OK:
		contents = f.get_as_text()
	return parse(contents)
		
