@tool
extends SyntaxHighlighter

# =====================================================================
#  Inkodot syntax palette
#
#  Twenty roles, twenty distinct colors. Families are grouped by
#  semantic purpose and each one is spread across hue, saturation,
#  and lightness so no two tokens are visually confusable.
# =====================================================================

# --- Prose / neutral ------------------------------------------------
@export var default_color    := Color("#cdd6f4")   # off-white
@export var comment_color    := Color("#6c7086")   # dim slate
@export var logic_color      := Color("a19e8dff")   # medium slate wash

# --- Structure — warm (headings and data) ---------------------------
@export var knot_color       := Color("bcd169ff")   # peach — headings
@export var case_color       := Color("#fbbf24")   # amber — case markers
@export var number_color     := Color("2ab5c5ff")   # orange — numeric literals
@export var variable_color   := Color("b0ad66ff")   # pale yellow — identifiers

# --- Structure — cool (logic and code) ------------------------------
@export var stitch_color     := Color("#89dceb")   # sky cyan — subheadings
@export var operator_color   := Color("#5fb3d4")   # sapphire — operators
@export var keyword_color    := Color("#89b4fa")   # periwinkle — keywords
@export var function_color   := Color("#b4befe")   # lavender — function calls

# --- Flow markers ---------------------------------------------------
@export var divert_color     := Color("#ed6b94")   # hot pink — flow arrows
@export var gather_color     := Color("#cba6f7")   # mauve — weave joins
@export var glue_color       := Color("#c4d47a")   # chartreuse — glue <>

# --- Interactivity --------------------------------------------------
@export var choice_color     := Color("#a6e3a1")   # mint — player choices
@export var brackets_color   := Color("#6b9e7f")   # forest — choice brackets

# --- Literals -------------------------------------------------------
@export var string_color     := Color("b9d3c9ff")   # teal — quoted strings
@export var boolean_color    := Color("40d3aeff")   # dusty rose — true/false

# --- Metadata -------------------------------------------------------
@export var tag_color        := Color("d97dd2ff")   # orchid — #tags
@export var bbcode_color     := Color("ef98aaff")   # pastel pink — <bbcode>


# --- State -----------------------------------------------------------
var _brace_depth_at_line_start: PackedInt32Array = []
var _cached_line_count: int = -1
var _cached_char_count: int = -1

var _decl_keyword_regex: RegEx


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var result := {}
	var working_text := get_text_edit().get_line(line)

	if working_text.strip_edges().is_empty():
		return result

	_ensure_brace_state()

	# Structural block markers (braces, dashes, colons, tildes).
	_highlight_block_structure(working_text, result, line)

	# Structural keywords.
	_highlight_knots_and_stitches(working_text, result)
	_highlight_choices_and_gathers(working_text, result, line)
	_highlight_diverts(working_text, result)

	# Base logic wash.
	_highlight_logic(working_text, result)

	# Identifiers in a logic context — broad pass.
	_highlight_identifiers(working_text, result, line)

	# Specific overrides on top.
	_highlight_functions(working_text, result)
	_highlight_booleans(working_text, result)
	_highlight_numbers(working_text, result)
	_highlight_operators(working_text, result)

	if _is_logic_line(working_text):
		_highlight_word_operators(working_text, result)

	_highlight_keywords(working_text, result)
	_highlight_variables(working_text, result)

	# Text-ish passes last.
	_highlight_strings(working_text, result)
	_highlight_tags(working_text, result)
	_highlight_brackets(working_text, result)
	_highlight_glue(working_text, result)
	_highlight_bbcode(working_text, result)

	# Comments swallow everything.
	_highlight_comments(working_text, result)

	# Rebuild with contiguous, ascending keys.
	var normalized := {}
	for i in working_text.length():
		if result.has(i):
			normalized[i] = result[i]
		else:
			normalized[i] = {"color": default_color}

	return normalized


#region Logic-context detection

func _is_logic_line(text: String) -> bool:
	var s := text.strip_edges()
	if s.is_empty(): return false

	if s.begins_with("~"): return true
	if s.ends_with(":"): return true
	if s.contains("{"): return true

	if _decl_keyword_regex == null:
		_decl_keyword_regex = RegEx.create_from_string("^(VAR|CONST|LIST|INCLUDE)\\b")

	return _decl_keyword_regex.search(s) != null

#endregion


#region Constructs

func _highlight_knots_and_stitches(working_text: String, result: Dictionary) -> void:
	var knot_regex := RegEx.create_from_string("^[\\s]*===[=]*.*$")
	for m in knot_regex.search_all(working_text):
		_set_color_range(result, m.get_start(), m.get_end(), knot_color)

	var stitch_regex := RegEx.create_from_string("^[\\s]*={1,2}\\s+\\S.*$")
	for m in stitch_regex.search_all(working_text):
		_set_color_range(result, m.get_start(), m.get_end(), stitch_color)


func _highlight_choices_and_gathers(text: String, result: Dictionary, line_index: int) -> void:
	if line_index < _brace_depth_at_line_start.size() \
			and _brace_depth_at_line_start[line_index] > 0:
		return

	var choice_regex := RegEx.create_from_string("^[\\s]*[\\*\\+]\\s?")
	for m in choice_regex.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), choice_color)

	var gather_regex := RegEx.create_from_string("^[\\s]*-(?!>)\\s?")
	for m in gather_regex.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), gather_color)


func _highlight_diverts(text: String, result: Dictionary) -> void:
	var arrow_regex := RegEx.create_from_string("->|<-")
	for m in arrow_regex.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), divert_color)

	var word_regex := RegEx.create_from_string("\\b(END|DONE)\\b")
	for m in word_regex.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), divert_color)


func _highlight_keywords(text: String, result: Dictionary) -> void:
	var kw_regex := RegEx.create_from_string(
		"\\b(EXTERNAL|LIST|FUNCTION|ELSE|else|temp|ref|return" +
		"|stopping|shuffle|cycle|once)\\b")
	for m in kw_regex.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), keyword_color)


func _highlight_variables(text: String, result: Dictionary) -> void:
	# Declaration keyword — VAR / CONST / INCLUDE / LIST.
	var kw_regex := RegEx.create_from_string("^[\\s]*(VAR|CONST|INCLUDE|LIST)\\b")
	for m in kw_regex.search_all(text):
		_set_color_range(result, m.get_start(1), m.get_end(1), keyword_color)

	# Variable / constant / list name.
	var name_regex := RegEx.create_from_string(
		"^[\\s]*(?:VAR|CONST|LIST)\\s+([A-Za-z_]\\w*)")
	for m in name_regex.search_all(text):
		_set_color_range(result, m.get_start(1), m.get_end(1), variable_color)

	# LIST item names — everything identifier-shaped after the `=`.
	# Items may be wrapped in `(...)`, have custom values (`two = 2`), or
	# be a plain comma-separated list. The identifier regex naturally skips
	# parens, commas, and the `=` sign; the number pass colors any custom
	# numeric values.
	var s := text.strip_edges()
	if s.begins_with("LIST"):
		var eq := text.find("=")
		if eq >= 0:
			var item_regex := RegEx.create_from_string("\\b[A-Za-z_][A-Za-z0-9_]*\\b")
			for m in item_regex.search_all(text):
				if m.get_start() > eq:
					_set_color_range(result, m.get_start(), m.get_end(), variable_color)

	# INCLUDE path.
	var inc_regex := RegEx.create_from_string("^[\\s]*INCLUDE\\s+(\\S+)")
	for m in inc_regex.search_all(text):
		_set_color_range(result, m.get_start(1), m.get_end(1), string_color)


## Washes inline `{ ... }` groups with logic_color, but only up to the
## condition/output separator: everything from `{` to the first `:` (or the
## closing `}` if no `:` is present) is logic; output after a `:` is prose
## and left at the default color.
##
## Also handles bare multi-line block openers: a line whose `{` has no
## matching `}` gets washed through the end of the line.
func _highlight_logic(text: String, result: Dictionary) -> void:
	var brace_regex := RegEx.create_from_string("\\{")
	for m in brace_regex.search_all(text):
		var open_pos := m.get_start()
		var close_pos := text.find("}", open_pos)
		var colon_pos := text.find(":", open_pos)

		if colon_pos >= 0 and (close_pos < 0 or colon_pos < close_pos):
			# `{ cond: output }` — wash condition, leave output alone.
			_set_color_range(result, open_pos, colon_pos + 1, logic_color)
			if close_pos >= 0:
				# Also wash the closing `}` so the pair reads as a unit.
				_set_color_range(result, close_pos, close_pos + 1, logic_color)
		elif close_pos >= 0:
			# `{ value }` — whole group is logic.
			_set_color_range(result, open_pos, close_pos + 1, logic_color)
		else:
			# Multi-line block opener with no closer on this line.
			_set_color_range(result, open_pos, text.length(), logic_color)

	# Tilde lines — wash logic_color, marker in case_color.
	var lstripped := text.lstrip(" \t")
	if lstripped.begins_with("~"):
		var pos := text.find("~")
		if pos >= 0:
			_set_color_range(result, pos, text.length(), logic_color)
			_set_color_range(result, pos, pos + 1, case_color)


## Colours identifiers that appear in a logic context. Prose is never touched.
##
## Logic contexts:
##   * `~ ...` lines — everything after the tilde
##   * `- cond:` case lines — from after the dash through the colon
##   * each `{` on the line — up to the *first* `:` (condition end) or `}`
##     (group end), whichever comes first
func _highlight_identifiers(text: String, result: Dictionary, line_index: int) -> void:
	var ranges: Array = []
	var s := text.strip_edges()
	var first := _first_non_ws(text)

	if s.begins_with("~"):
		var pos := text.find("~")
		if pos >= 0:
			ranges.append([pos + 1, text.length()])

	elif s.begins_with("-") and s.ends_with(":"):
		var colon := text.rfind(":")
		if colon > first:
			ranges.append([first + 1, colon])

	var brace_regex := RegEx.create_from_string("\\{")
	for m in brace_regex.search_all(text):
		var open_pos := m.get_start()
		var close_pos := text.find("}", open_pos)
		var colon_pos := text.find(":", open_pos)

		var end := -1
		if colon_pos >= 0 and (close_pos < 0 or colon_pos < close_pos):
			end = colon_pos
		elif close_pos >= 0:
			end = close_pos
		else:
			end = text.length()

		if end > open_pos + 1:
			ranges.append([open_pos + 1, end])

	if ranges.is_empty():
		return

	var id_regex := RegEx.create_from_string("\\b[A-Za-z_][A-Za-z0-9_]*\\b")
	for m in id_regex.search_all(text):
		var start := m.get_start()
		var end := m.get_end()
		for r in ranges:
			if start >= r[0] and end <= r[1]:
				_set_color_range(result, start, end, variable_color)
				break


func _highlight_functions(text: String, result: Dictionary) -> void:
	var s := text.strip_edges()
	if s.begins_with("==="): return

	var fn_regex := RegEx.create_from_string("\\b([A-Za-z_][A-Za-z0-9_]*)\\s*(?=\\()")
	for m in fn_regex.search_all(text):
		_set_color_range(result, m.get_start(1), m.get_end(1), function_color)


func _highlight_booleans(text: String, result: Dictionary) -> void:
	var bool_regex := RegEx.create_from_string("\\b(true|false)\\b")
	for m in bool_regex.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), boolean_color)


func _highlight_numbers(text: String, result: Dictionary) -> void:
	var num_regex := RegEx.create_from_string("\\b\\d+(?:\\.\\d+)?\\b")
	for m in num_regex.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), number_color)


func _highlight_operators(text: String, result: Dictionary) -> void:
	var compound := RegEx.create_from_string(
		"\\+=|-=|\\*=|/=|%=|\\+\\+|--|==|!=|>=|<=|&&|\\|\\|")
	for m in compound.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), operator_color)

	var single_cmp := RegEx.create_from_string(
		"(?<![=!<>+\\-*/%])=(?!=)|(?<!-)>(?!=)|<(?!-)(?!=)")
	for m in single_cmp.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), operator_color)

	var arith := RegEx.create_from_string(
		"(?<=[\\w\\)\\]=]\\s)(?:\\+(?!\\+)(?!=)|-(?!>)(?!-)(?!=)|\\*(?![*=])|/(?![/=])|%(?!=))")
	for m in arith.search_all(text):
		if text.substr(0, m.get_start()).strip_edges().is_empty():
			continue
		_set_color_range(result, m.get_start(), m.get_end(), operator_color)


func _highlight_word_operators(text: String, result: Dictionary) -> void:
	var word_regex := RegEx.create_from_string("\\b(and|or|not|mod)\\b")
	for m in word_regex.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), operator_color)


func _highlight_strings(text: String, result: Dictionary) -> void:
	var string_regex := RegEx.create_from_string('\\".*?\\"')
	for m in string_regex.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), string_color)


func _highlight_tags(text: String, result: Dictionary) -> void:
	var tag_regex := RegEx.create_from_string("#[^\\s]+")
	for m in tag_regex.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), tag_color)


func _highlight_brackets(text: String, result: Dictionary) -> void:
	var bracket_regex := RegEx.create_from_string("\\[|\\]")
	for m in bracket_regex.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), brackets_color)


func _highlight_glue(text: String, result: Dictionary) -> void:
	var glue_regex := RegEx.create_from_string("<>")
	for m in glue_regex.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), glue_color)


func _highlight_bbcode(text: String, result: Dictionary) -> void:
	var bb_regex := RegEx.create_from_string("<(?>[^<>]|(?R))*>")
	for m in bb_regex.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), bbcode_color)


func _highlight_comments(text: String, result: Dictionary) -> void:
	var comment_regex := RegEx.create_from_string("//.*$")
	for m in comment_regex.search_all(text):
		_set_color_range(result, m.get_start(), m.get_end(), comment_color)

#endregion


#region Multi-line block structure

func _ensure_brace_state() -> void:
	var te := get_text_edit()
	if not te: return

	var lc := te.get_line_count()
	var cc := te.text.length()

	if lc == _cached_line_count and cc == _cached_char_count:
		return

	_cached_line_count = lc
	_cached_char_count = cc
	_brace_depth_at_line_start.resize(lc)

	var depth := 0
	for i in lc:
		_brace_depth_at_line_start[i] = depth
		depth = _brace_depth_after(te.get_line(i), depth)


func _brace_depth_after(line_text: String, start_depth: int) -> int:
	var depth := start_depth
	var in_string := false
	var i := 0
	var n := line_text.length()

	while i < n:
		var c := line_text[i]

		if not in_string and c == "/" and i + 1 < n and line_text[i + 1] == "/":
			break

		if c == "\\" and in_string and i + 1 < n:
			i += 2
			continue

		if c == "\"":
			in_string = not in_string
		elif not in_string:
			if c == "{":
				depth += 1
			elif c == "}":
				depth -= 1

		i += 1

	return depth


func _highlight_block_structure(text: String, result: Dictionary, line_index: int) -> void:
	if line_index >= _brace_depth_at_line_start.size():
		return

	var start_depth := _brace_depth_at_line_start[line_index]
	var end_depth := start_depth
	if line_index + 1 < _brace_depth_at_line_start.size():
		end_depth = _brace_depth_at_line_start[line_index + 1]

	if start_depth <= 0 and end_depth <= 0:
		return

	var s := text.strip_edges()
	if s.is_empty():
		return

	var first := _first_non_ws(text)

	if s == "{" or s == "}":
		_set_color_range(result, first, first + 1, logic_color)
		return

	if s.begins_with("-"):
		if s.ends_with(":"):
			var colon_pos := text.rfind(":")
			_set_color_range(result, first, colon_pos + 1, logic_color)
			_set_color_range(result, first, first + 1, case_color)
		else:
			_set_color_range(result, first, first + 1, case_color)
		return

	if s.ends_with(":"):
		var colon_pos := text.rfind(":")
		_set_color_range(result, first, colon_pos + 1, logic_color)
		return


func _first_non_ws(text: String) -> int:
	var i := 0
	while i < text.length() and (text[i] == " " or text[i] == "\t"):
		i += 1
	return i

#endregion


func _set_color_range(result: Dictionary, start: int, end: int, color: Color) -> void:
	for i in range(start, end):
		result[i] = {"color": color}
