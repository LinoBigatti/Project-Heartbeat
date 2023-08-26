extends Window

class_name HBEditorWindow

func _ready():
	close_requested.connect(hide)
