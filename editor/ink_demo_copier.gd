@tool
extends EditorExportPlugin

const DEMO_SOURCE := "res://ink_demos"
const DEMO_DEST_NAME := "ink"

## Marker that must be present in project.godot for this plugin to act.
const STANDALONE_MARKER := "inkodot/is_standalone_app"

const SKIPPED_EXTENSIONS := ["import"]
const SKIPPED_DIRECTORIES := [".import", ".godot"]

var _export_path := ""


func _get_name() -> String:
	return "InkDemoCopier"


func _export_begin(features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	# Mobile exports have no writable "next to the executable" location.
	# The app extracts demos from the .pck at first launch instead — see
	# InkEditor.EnsureDemoFiles().
	if "android" in features or "ios" in features:
		_export_path = ""
		return

	_export_path = path


func _export_end() -> void:
	if not _is_standalone_app():
		return

	if _export_path.is_empty():
		return

	if not DirAccess.dir_exists_absolute(DEMO_SOURCE):
		return

	var dest_dir := _export_path.get_base_dir().path_join(DEMO_DEST_NAME)

	if DirAccess.dir_exists_absolute(dest_dir):
		print("[Inkodot] '%s' already exists — skipping demo copy." % dest_dir)
		return

	var err := _copy_recursive(DEMO_SOURCE, dest_dir)
	if err != OK:
		push_warning("[Inkodot] Failed to copy demos to '%s' (error %d)." % [dest_dir, err])
	else:
		print("[Inkodot] Copied demos to '%s'." % dest_dir)


func _is_standalone_app() -> bool:
	return bool(ProjectSettings.get_setting(STANDALONE_MARKER, false))


func _copy_recursive(src_res: String, dst_abs: String) -> Error:
	var src_abs := ProjectSettings.globalize_path(src_res)

	var src_dir := DirAccess.open(src_abs)
	if not src_dir:
		return DirAccess.get_open_error()

	var mk_err := DirAccess.make_dir_recursive_absolute(dst_abs)
	if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
		return mk_err

	for file in src_dir.get_files():
		if _should_skip_file(file):
			continue

		var err := DirAccess.copy_absolute(
			src_abs.path_join(file),
			dst_abs.path_join(file))
		if err != OK:
			return err

	for sub in src_dir.get_directories():
		if _should_skip_directory(sub):
			continue

		var err := _copy_recursive(src_res.path_join(sub), dst_abs.path_join(sub))
		if err != OK:
			return err

	return OK


func _should_skip_file(file_name: String) -> bool:
	var ext := file_name.get_extension().to_lower()
	return ext in SKIPPED_EXTENSIONS


func _should_skip_directory(dir_name: String) -> bool:
	return dir_name in SKIPPED_DIRECTORIES
