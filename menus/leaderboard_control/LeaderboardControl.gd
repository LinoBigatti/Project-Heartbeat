extends Control

@export var minimum_position := 0
@export var max_position := 30
@export var show_user_position := true
const LeaderboardItem = preload("res://menus/leaderboard_control/LeaderboardItem.tscn")
@onready var not_found_label = get_node("CenterContainer/Label")
@onready var entries_container = get_node("Entries")
@onready var loading_texture_rect = get_node("CenterContainer2/TextureRect")
var current_leaderboard = ""
signal entries_set
func _ready():
	$CenterContainer2/AnimationPlayer.play("spin")

func set_entries(entries: Array[HBBackend.BackendLeaderboardEntry]):
	_on_leaderboard_entries_downloaded(0, entries)
	emit_signal("entries_set")

func _on_leaderboard_entries_downloaded(handle, entries: Array[HBBackend.BackendLeaderboardEntry]):
	loading_texture_rect.hide()
	not_found_label.hide()
	for i in range(entries.size()):
		var entry = entries[i]
		var mp_entry := HBMPLeaderboardEntry.Entry.new()
		mp_entry.game_info = entry.game_info
		mp_entry.member = entry.user
		mp_entry.rank = entry.rank
		var item = LeaderboardItem.instantiate()
		item.entry = mp_entry
		item.odd = i % 2 == 0
		entries_container.add_child(item)
