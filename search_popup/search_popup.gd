@tool
extends Window

@export var code_edit: CodeEdit

const DEBOUNCE_SEC := 0.15
const PREVIEW_MAX_CHARS := 120
const MAX_RESULTS_PER_FILE := 200
const MAX_TOTAL_RESULTS := 500

var _debounce: Timer

@onready var input: LineEdit        = %SearchInput
@onready var case_check: CheckBox   = %CaseCheck
@onready var regex_check: CheckBox  = %RegexCheck
@onready var project_check: CheckBox = %ProjectCheck
@onready var result_tree: Tree      = %ResultTree
@onready var status_label: Label    = %StatusLabel


func _ready() -> void:
	close_requested.connect(hide)

	_debounce = Timer.new()
	_debounce.wait_time = DEBOUNCE_SEC
	_debounce.one_shot = true
	add_child(_debounce)
	_debounce.timeout.connect(_run_search)

	input.text_changed.connect(_on_input_changed)
	input.text_submitted.connect(_on_input_submitted)
	case_check.toggled.connect(_on_option_toggled)
	regex_check.toggled.connect(_on_option_toggled)
	project_check.toggled.connect(_on_option_toggled)
	result_tree.item_activated.connect(_on_result_activated)


## Show the popup, optionally prefilling with the CodeEdit's current
## single-line selection. Focus lands on the input and its text is selected.
func open_with_focus() -> void:
	if is_instance_valid(code_edit) and code_edit.has_selection():
		var sel := code_edit.get_selected_text()
		if not sel.contains("\n"):
			input.text = sel

	popup_centered(Vector2i(640, 420))
	input.grab_focus()
	input.select_all()
	_run_search()


#region Inputs

func _on_input_changed(_new_text: String) -> void:
	_debounce.start()

func _on_input_submitted(_text: String) -> void:
	_debounce.stop()
	_run_search()
	_jump_to_first_result()

func _on_option_toggled(_pressed: bool) -> void:
	_debounce.stop()
	_run_search()

#endregion


#region Search

func _run_search() -> void:
	result_tree.clear()
	status_label.text = ""

	if not is_instance_valid(code_edit):
		status_label.text = "No editor bound"
		return

	var query := input.text
	if query.is_empty():
		status_label.text = "Type to search"
		return

	var use_regex    := regex_check.button_pressed
	var case_sensitive := case_check.button_pressed
	var in_project   := project_check.button_pressed

	var re: RegEx = null
	if use_regex:
		var pattern := query
		if not case_sensitive:
			pattern = "(?i)" + pattern

		re = RegEx.create_from_string(pattern)
		if re == null or not re.is_valid():
			status_label.text = "Invalid regex"
			return

	var files := PackedStringArray()
	if in_project:
		var root: String = code_edit.MainFolder
		if root.is_empty() or not DirAccess.dir_exists_absolute(root):
			status_label.text = "No folder open"
			return
		files = _collect_ink_files(root)
	else:
		var current: String = code_edit.FilePath
		if current.is_empty():
			status_label.text = "No file open"
			return
		files = PackedStringArray([current])

	var tree_root := result_tree.create_item()
	var total := 0
	var file_count := 0
	var capped := false

	for path in files:
		if total >= MAX_TOTAL_RESULTS:
			capped = true
			break

		var file_results := _search_file(path, query, re, case_sensitive)
		if file_results.is_empty():
			continue

		file_count += 1
		var file_item := result_tree.create_item(tree_root)
		file_item.set_text(0, "📄 %s  (%d)" % [path.get_file(), file_results.size()])
		file_item.set_custom_color(0, Color(0.7, 0.7, 0.7))
		file_item.set_selectable(0, false)

		var shown := 0
		for r in file_results:
			if total >= MAX_TOTAL_RESULTS:
				capped = true
				break
			if shown >= MAX_RESULTS_PER_FILE:
				break

			var child := result_tree.create_item(file_item)
			child.set_text(0, "Line %d · %s" % [r["line"], r["preview"]])
			child.set_metadata(0, {"path": path, "line": r["line"]})
			shown += 1
			total += 1

	if total == 0:
		status_label.text = "No matches"
		return

	var suffix := " (capped at %d)" % MAX_TOTAL_RESULTS if capped else ""
	status_label.text = "%d result%s in %d file%s%s" % [
		total, "" if total == 1 else "s",
		file_count, "" if file_count == 1 else "s",
		suffix,
	]


## Returns [{path, line, preview}, …] for every match in `path`.
func _search_file(path: String, query: String, re: RegEx, case_sensitive: bool) -> Array:
	var out: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return out

	var line_num := 0
	while not file.eof_reached():
		var line := file.get_line()
		line_num += 1

		var matched := false
		if re != null:
			matched = re.search(line) != null
		elif case_sensitive:
			matched = line.find(query) >= 0
		else:
			matched = line.findn(query) >= 0

		if not matched:
			continue

		var preview := line.strip_edges()
		if preview.length() > PREVIEW_MAX_CHARS:
			preview = preview.substr(0, PREVIEW_MAX_CHARS - 1) + "…"

		out.append({"path": path, "line": line_num, "preview": preview})

	return out


## Recursively gathers every `.ink` file under `root`.
func _collect_ink_files(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(root)
	if not dir:
		return out

	for f in dir.get_files():
		if f.ends_with(".ink"):
			out.append(root.path_join(f))

	for sub in dir.get_directories():
		out.append_array(_collect_ink_files(root.path_join(sub)))

	return out

#endregion


#region Navigation

func _jump_to_first_result() -> void:
	var root := result_tree.get_root()
	if not root: return
	var first_file := root.get_first_child()
	if not first_file: return
	var first_result := first_file.get_first_child()
	if not first_result: return

	result_tree.set_selected(first_result, 0)
	_on_result_activated()


func _on_result_activated() -> void:
	var item := result_tree.get_selected()
	if not item:
		return

	var meta = item.get_metadata(0)
	if not (meta is Dictionary):
		return

	var path: String = meta["path"]
	var line: int = meta["line"]

	if not is_instance_valid(code_edit):
		return

	if code_edit.FilePath != path:
		code_edit.SetNewFile(path)

	# Defer one frame: SetNewFile schedules its Update() async, and we want
	# the caret move to happen after the editor has settled into the new file.
	_set_caret.call_deferred(line - 1)
	hide()


func _set_caret(line: int) -> void:
	if not is_instance_valid(code_edit):
		return
	code_edit.grab_focus()
	code_edit.set_caret_line(line)
	code_edit.set_caret_column(0)
	code_edit.center_viewport_to_caret()

#endregion
