@tool
extends Control

## Reference to the Ink story object.
@export var story: InkStory

@export var scroll_to_bottom := false

@export_subgroup("Text Formatter")
## Reference to the text formatter used to convert Ink text.
@export var formatter: TextFormatter

@export_subgroup("Scenes")
## Scene for displaying formatted dialogue text (e.g., RichTextLabel).
@export var richtext_scene: PackedScene
## Scene for choice buttons.
@export var button_scene: PackedScene

@export_subgroup("Nodes")
## Container where the dialogue and choice buttons will be added.
@export var container: Control
## Scroll container that will be automatically scrolled to show new content.
@export var scroll_container: ScrollContainer

var current_choices_buttons: Array[Control] = []


## Start the story dialogue.
func start(_story: InkStory):
	for child in container.get_children():
		child.queue_free()

	story = _story
	current_choices_buttons.clear()   # also a good idea

	if story == null or story.get_current_choices().is_empty() and not story.can_continue():
		return

	next()


## Clear nodes
func clear() -> void:
	for child in container.get_children():
		child.queue_free()
	current_choices_buttons.clear()
	story = null


## Advances the story: displays the next block of text and any available choices.
func next() -> void:
	if not story or not formatter:
		return

	# Display continuation text if available
	if story.can_continue():
		_show_continuation()

	# Display current choices
	_show_choices()


## Loading choices after text update
func load_choices(_story: InkStory, choices: PackedInt32Array):
	var v_scroll := scroll_container.get_v_scroll_bar().value

	start(_story)

	for index in choices:
		if current_choices_buttons.size() - 1 < index:
			break

		var button := current_choices_buttons[index]

		if is_instance_valid(button):
			_on_choice_pressed(button, index, false)

	scroll_container.get_v_scroll_bar().value = v_scroll


## Restart the Story
func restart():
	for child in container.get_children():
		child.queue_free()

	%CodeEdit.SetChoiceHistory([])
	story = %CodeEdit.CurrentStory
	story.reset_runtime_state()
	start(story)


## Shows all available continuation text until a choice point is reached.
func _show_continuation() -> void:
	var lines: Array[String] = []

	while story.can_continue():
		# Retrieve the next block of formatted text
		var _text := story.continue_story() as String
		if _text.is_empty(): continue
		
		_text = _text.strip_escapes()
		_text = _text.strip_edges()

		if _text.is_empty(): continue

		var line_text = formatter.GetConvertedText(_text)

		# Get tags for the current line
		var tags = story.get_current_tags()
		var prefix = ""
		var suffix_tags: Array[String] = []

		# Process tags
		prefix = "[color=purple]▪[/color] "
		for tag in tags:
			if tag.to_lower().begins_with("unit:"):
				# Extract name after "unit:" and use as prefix
				prefix += "[color=purple][code][u]" + tag.substr(5).strip_edges().to_lower() + "[/u][/code][/color]:"
			else:
				# Other tags are added to suffix
				suffix_tags.append(tag)

		# Build the line string
		var full_line = ""
		if not prefix.is_empty():
			full_line = prefix + " " + line_text
		else:
			full_line = line_text

		# Append suffix tags (each with # and purple color)
		if not suffix_tags.is_empty():
			var suffix_parts = []
			for tag in suffix_tags:
				suffix_parts.append("[color=purple]#" + tag + "[/color]")
			full_line += " " + ", ".join(suffix_parts)

		lines.append(full_line)

	if lines.is_empty():
		return

	# Join all lines with a blank line between them
	var full_text = "\n".join(lines)

	# Create and configure the rich text display
	var richtext = richtext_scene.instantiate()
	richtext.text = full_text
	container.add_child(richtext)
	richtext.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Wait one frame for layout to update, then scroll to the new element
	if scroll_container:
		if is_instance_valid(richtext):
			scroll_container.ensure_control_visible.call_deferred(richtext)


## Shows all current choices as buttons.
func _show_choices() -> void:
	var choices := story.get_current_choices()
	if choices.is_empty():
		return

	# Use a VBoxContainer to arrange choices vertically
	var choice_container = VBoxContainer.new()
	choice_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.add_child(choice_container)
	current_choices_buttons.clear()

	for choice in choices:
		var button := button_scene.instantiate() as Control
		current_choices_buttons.append(button)

		var _text := formatter.GetConvertedText(choice.get_text())
		button.SetText(_text)

		# When pressed, pass the button itself and the choice index
		if button.Button:
			button.Button.button_up.connect(_on_choice_pressed.bind(button, choice.get_index(), true))

		choice_container.add_child(button)
		button.set_anchors_preset(Control.PRESET_FULL_RECT)

		# Wait one frame for layout, then scroll to the button
		if scroll_to_bottom and scroll_container:
			if is_instance_valid(button):
				scroll_container.ensure_control_visible.call_deferred(button)


## Handles a choice button press. Keeps the pressed button visible and destroys all others.
func _on_choice_pressed(button: Control, choice_index: int, save_choice: bool) -> void:
	# Get the parent container (the VBoxContainer holding these choices)
	var parent = button.get_parent()
	if parent:
		# Destroy all other buttons in the same container
		for child in parent.get_children():
			if child != button:
				child.queue_free()

	# Disable the pressed button to prevent re-clicking
	button.SetDisabled(true)

	# Continue with the story
	%CodeEdit.ChooseChoiceIndex(choice_index, save_choice)

	next()
