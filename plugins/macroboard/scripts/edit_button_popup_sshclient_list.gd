class_name DeselectableItmeList
extends ItemList
## This class only exits because ItemList has some weird behavior when trying to
## make it so pressing an item again deselects it
## because all the signal seemingly happen after the selection is triggered
## is_selected() always returns true, so there is no way to detect if it was
## not selected before the signal is triggered
## so we store the selected_item and manage it ourselves

## The custom selected item
var selected_item: int = -1

func _on_item_clicked(index, _at_position, _mouse_button_index):
	if index == selected_item:
		deselect(index)
		selected_item = -1
	else:
		select(index)
		selected_item = index


## Use this function to select something from code
func custom_select(index: int):
	select(index)
	selected_item = index
