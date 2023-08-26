extends AcceptDialog

class_name HBEditorAcceptDialog

func _ready():
	close_requested.connect(hide)
