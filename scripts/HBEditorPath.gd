extends HBSerializable

class_name HBEditorPath

const EDITOR_PATHS_PATH := "user://editor_paths"

var name := "New Path"
var filename := "new_path.json" # Internal, not serialized

var paths: Array[HBPaths.HBPath] = []
var autohide := false

func _init():
	serializable_fields += [
		"name", "autohide",
	]

func get_serialized_type() -> String:
	return "EditorPath"

func save(base_path: String = EDITOR_PATHS_PATH) -> int:
	self.filename = HBUtils.get_valid_filename(self.name.to_lower()) + ".json"
	if self.filename == ".json":
		return ERR_FILE_BAD_PATH
	
	var path := HBUtils.join_path(base_path, filename)
	
	if FileAccess.file_exists(path):
		return ERR_ALREADY_EXISTS
	
	var file := FileAccess.open(path, FileAccess.WRITE)

	var result = FileAccess.get_open_error()
	if result != OK:
		return result
	
	var data = self.serialize()
	if not data:
		Log.log(self, "Data was not serialized.", Log.LogLevel.ERROR)
		return ERR_FILE_CORRUPT
	
	var json = JSON.stringify(data, "  ")
	if not json:
		Log.log(self, "Data could not be formatted as json.", Log.LogLevel.ERROR)
		return ERR_FILE_CORRUPT
	
	file.store_string(json)
	file.close()
	
	return OK

func get_transform() -> EditorTransformationTemplate:
	var transform := EditorTransformationTemplate.new()
	#transform.template = self
	
	return transform
