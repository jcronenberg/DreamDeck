class_name PluginsPopup
extends Control
## The popup where users can activate and configure plugins

var _plugins: Array[PluginCoordinator.Plugin]
var _current_plugin: int = -1


func _ready() -> void:
	populate_plugins()


func populate_plugins() -> void:
	%PluginSelectorList.clear()

	_plugins = PluginCoordinator.get_plugins()

	for plugin in _plugins:
		%PluginSelectorList.add_item(plugin.plugin_name)

	_on_plugin_selector_list_item_selected(0)


func populate_plugin_panel(plugin: PluginCoordinator.Plugin) -> void:
	%PluginName.text = plugin.plugin_name
	%PluginIcon.texture = plugin.get_icon()
	%PluginDescription.text = "[center][b]Description:[/b]\n%s[/center]" % [plugin.plugin_description]
	%ActivateCheckButton.set_pressed_no_signal(plugin.is_activated())
	%SettingsButton.visible = plugin.show_settings_button()

	for toggled_con in %ActivateCheckButton.get_signal_connection_list("toggled"):
		%ActivateCheckButton.disconnect("toggled", toggled_con["callable"])

	%ActivateCheckButton.connect("toggled", plugin.set_activated)
	%ActivateCheckButton.connect("toggled", _on_activate_check_button_toggled)


func _on_plugin_selector_list_item_selected(index: int) -> void:
	var plugin_name: String = %PluginSelectorList.get_item_text(index)
	for plugin in _plugins:
		if plugin.plugin_name == plugin_name:
			populate_plugin_panel(plugin)
			_current_plugin = index
			return

	push_error("PluginsPopup: Couldn't find plugin \"%s\" within plugins" % [plugin_name])


func _on_activate_check_button_toggled(_toggled: bool) -> void:
	%SettingsButton.visible = _plugins[_current_plugin].show_settings_button()


func _on_settings_button_pressed() -> void:
	PopupManager.push_stack_item(_plugins[_current_plugin].get_loader().get_settings_page())


func _on_popup_confirm(node: Control) -> bool:
	if node == self:
		return true
	return node.confirm()


func _on_popup_cancel(node: Control) -> void:
	if not node or node == self:
		return
	node.cancel()
