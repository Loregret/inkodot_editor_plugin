using Godot;

namespace InkodotEditor;

[Tool]
public partial class DialogueChoiceButton : Control
{
	[ExportSubgroup("Colors")]
	[Export] public Color RegularColor = Colors.White;
	[Export] public Color DisabledColor = Colors.DarkGray;

	[ExportSubgroup("Nodes")]
	[Export] public Button? Button;
	[Export] public RichTextLabel? RichTextLabel;

	public string Text { set => RichTextLabel?.Text = value; get => RichTextLabel?.Text ?? ""; }

	public bool IsDisabled => Button?.Disabled ?? true;

	public void SetText(string txt) => Text = txt;

	public void SetDisabled(bool disable = true)
	{
		Button?.Disabled = disable;

		if (disable) RichTextLabel?.AddThemeColorOverride("default_color", DisabledColor);
		else RichTextLabel?.AddThemeColorOverride("default_color", RegularColor);
	}
}
