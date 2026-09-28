@tool
class_name AppPaths
extends RefCounted

## Subfolder the standalone app looks for (and creates) next to its executable.
const USER_FOLDER_NAME := "ink"


## Folder containing the executable. On macOS this walks *out* of the .app
## bundle so it returns the directory the user sees in Finder.
static func get_executable_dir() -> String:
	var exe := OS.get_executable_path()
	# macOS: /Applications/Foo.app/Contents/MacOS/Foo → /Applications
	if OS.has_feature("macos") and exe.get_base_dir().get_file() == "MacOS":
		return exe.get_base_dir().get_base_dir().get_base_dir().get_base_dir()
	return exe.get_base_dir()


## Default root the standalone editor opens on first launch.
## Creates the folder if it's missing so the first tree build succeeds.
static func get_default_root() -> String:
	if Engine.is_editor_hint():
		return "res://"

	var root := get_executable_dir().path_join(USER_FOLDER_NAME)

	if not DirAccess.dir_exists_absolute(root):
		var err := DirAccess.make_dir_recursive_absolute(root)
		if err != OK:
			push_warning(
				"[Inkodot] Could not create %s (error %d). Falling back to the executable directory."
				% [root, err])
			return get_executable_dir()

	return root


## True if we're running as a standalone app rather than the editor plugin.
static func is_standalone() -> bool:
	return not Engine.is_editor_hint()
