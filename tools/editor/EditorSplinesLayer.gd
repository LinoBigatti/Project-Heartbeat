extends EditorLayer

class_name EditorSplineLayer

func add_item(item):
	var insert_pos = self.timing_points.bsearch_custom(item._start_time, self.bsearch_time)
	item._layer = self
	
	place_child(item)
	
	if not item.is_connected("time_changed", Callable(self, "_on_timeline_item_time_changed")):
		item.connect("time_changed", Callable(self, "_on_timeline_item_time_changed").bind(item))
	
	self.add_child(item)
	
	self.timing_points.insert(insert_pos, item)
	if self.timing_points.size() > 1:
		if item.time > self._cull_start_time and item.time < self._cull_end_time:
			item.set_process_input(true)
			item.show()
		else:
			item.set_process_input(false)
			item.hide()

func _on_timeline_item_time_changed(timeline_item: EditorTimelineItemSpline):
	place_child(timeline_item)

func place_child(child):
	child.size = child.get_editor_size()
	
	child._on_time_changed()

func bsearch_time(a: EditorTimelineItemSpline, b: EditorTimelineItemSpline):
	return a.time < b.time

func clear_items():
	for item in self.timing_points:
		remove_item(item)
		item.queue_free()
	
	queue_redraw()
