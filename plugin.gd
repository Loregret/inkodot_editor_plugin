@tool
extends EditorPlugin

@export var editor_scene := preload("res://addons/inkodot_editor/editor/InkEditor.tscn")
@export var icon := preload("res://addons/inkodot_editor/icon.svg")

const InkDemoCopier := preload("res://addons/inkodot_editor/editor/ink_demo_copier.gd")

const dock_name := "Inkodot"
const STANDALONE_MARKER := "inkodot/is_standalone_app"

var dock_content: Control
var _demo_copier: EditorExportPlugin


func _enter_tree() -> void:
	if dock_content:
		dock_content.queue_free()

	dock_content = editor_scene.instantiate()
	dock_content.hide()
	EditorInterface.get_editor_main_screen().add_child(dock_content)

	# Only register the demo copier in the standalone app itself — not when
	# this plugin is installed in someone else's project.
	if _is_standalone_app():
		_demo_copier = InkDemoCopier.new()
		add_export_plugin(_demo_copier)


func _exit_tree() -> void:
	if is_instance_valid(dock_content):
		EditorInterface.get_editor_main_screen().remove_child(dock_content)
		dock_content = null

	if _demo_copier:
		remove_export_plugin(_demo_copier)
		_demo_copier = null


func _is_standalone_app() -> bool:
	return ProjectSettings.get_setting(STANDALONE_MARKER, false)


#region Main Screen

func _make_visible(visible: bool) -> void:
	if not dock_content:
		return

	if dock_content.get_parent() is Window:
		if visible:
			EditorInterface.set_main_screen_editor(dock_name)
			dock_content.show()
			dock_content.get_parent().grab_focus()
	else:
		dock_content.visible = visible

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return dock_name

func _get_plugin_icon() -> Texture2D:
	return icon

#endregion
