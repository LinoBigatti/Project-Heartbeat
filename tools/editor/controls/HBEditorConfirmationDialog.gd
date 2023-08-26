extends ConfirmationDialog

class_name HBEditorConfirmationDialog

func _ready():
	close_requested.connect(hide)
