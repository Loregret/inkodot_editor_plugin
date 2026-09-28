using Godot;
using System;
using System.Threading.Tasks;

namespace InkodotEditor;

public partial class InkEditor
{
	Shortcut FoldAllShortcut = new()
	{
		Events = [new InputEventKey() { Keycode = Key.K, ShiftPressed = true, CtrlPressed = true, }]
	};

	Shortcut UnfoldAllShortcut = new()
	{
		Events = [new InputEventKey() { Keycode = Key.K, AltPressed = true, CtrlPressed = true, }]
	};

	Shortcut FoldIndentShortcut = new()
	{
		Events = [new InputEventKey() { Keycode = Key.K, CtrlPressed = true, }]
	};

	Shortcut UnfoldIndentShortcut = new()
	{
		// Events = [new InputEventKey() { Keycode = Key.K, AltPressed = true, }]
	};

	Shortcut UnfoldBelowShortcut = new()
	{
		Events = [new InputEventKey() { Keycode = Key.K, AltPressed = true, }]
	};

	Shortcut SaveShortcut = new()
	{
		Events = [new InputEventKey() { Keycode = Key.S, CtrlPressed = true }]
	};

	Shortcut SaveAllShortcut = new()
	{
		Events = [new InputEventKey() { Keycode = Key.S, CtrlPressed = true, ShiftPressed = true, }]
	};


	enum CodeMenuEntries
	{
		FoldAll,
		UnfoldAll,
		UnfoldBelow,
		FoldIndent,
		UnfoldIndent,
	}

	PopupMenu? Menu => GetMenu();


	//> Main

	public void CreateMenu()
	{
		if (!IsInstanceValid(Menu)) return;

		var menu = new PopupMenu();

		//* Menu Button
		Menu.AddSeparator();
		Menu.AddSubmenuNodeItem("Fold", menu);

		//* Add Popup Entries
		menu.AddSeparator();

		//* Unfold Next
		menu.AddItem("Unfold Line Below", (int)CodeMenuEntries.UnfoldBelow);
		menu.IdPressed += id =>
		{
			if (id != (int)CodeMenuEntries.UnfoldBelow) return;

			TextUnfoldBelow();
		};

		menu.AddSeparator();

		//* Fold Indent
		menu.AddItem("Fold by Indent", (int)CodeMenuEntries.FoldIndent);
		menu.IdPressed += id =>
		{
			if (id != (int)CodeMenuEntries.FoldIndent) return;

			TextFoldByIndent();
		};

		//* Unfold Indent
		menu.AddItem("Unfold by Indent", (int)CodeMenuEntries.UnfoldIndent);
		menu.IdPressed += id =>
		{
			if (id != (int)CodeMenuEntries.UnfoldIndent) return;

			TextUnfoldByIndent();
		};

		menu.AddSeparator();

		//* Fold All
		menu.AddItem("Fold All", (int)CodeMenuEntries.FoldAll);
		menu.IdPressed += id =>
		{
			if (id != (int)CodeMenuEntries.FoldAll) return;

			FoldAllLines();
		};

		//* Unfold All
		menu.AddItem("Unfold All", (int)CodeMenuEntries.UnfoldAll);
		menu.IdPressed += id =>
		{
			if (id != (int)CodeMenuEntries.UnfoldAll) return;

			UnfoldAllLines();
		};
	}

	public override void _GuiInput(InputEvent @event)
	{
		if (SaveAllShortcut.MatchesEvent(@event))
		{
			SaveSession();

			AcceptEvent();
			return;
		}

		if (SaveShortcut.MatchesEvent(@event))
		{
			WriteFile(FilePath);

			AcceptEvent();
			return;
		}

		if (FoldAllShortcut.MatchesEvent(@event))
		{
			FoldAllLines();
			AcceptEvent();
			return;
		}

		if (UnfoldAllShortcut.MatchesEvent(@event))
		{
			UnfoldAllLines();
			AcceptEvent();
			return;
		}

		if (FoldIndentShortcut.MatchesEvent(@event))
		{
			TextFoldByIndent();
			AcceptEvent();
			return;
		}

		if (UnfoldIndentShortcut.MatchesEvent(@event))
		{
			TextUnfoldByIndent();
			AcceptEvent();
			return;
		}

		if (UnfoldBelowShortcut.MatchesEvent(@event))
		{
			TextUnfoldBelow();
			AcceptEvent();
			return;
		}
	}


	//> Actions

	void TextFoldByIndent()
	{
		var current = GetCaretLine();
		var indent = GetIndentLevel(current);
		var end = GetLineCount();

		for (int x = current; x < end; x++)
		{
			if (!CanFoldLine(x)) continue;

			if (GetIndentLevel(x) < indent) continue;

			FoldLine(x);
		}
	}

	void TextUnfoldByIndent()
	{
		var current = GetCaretLine();
		var indent = GetIndentLevel(current);
		var end = GetLineCount();

		for (int x = current; x < end; x++)
		{
			if (GetIndentLevel(x) < indent) continue;

			UnfoldLine(x);
		}
	}

	async void TextUnfoldBelow()
	{
		var current = GetCaretLine();
		var end = GetLineCount();

		for (int i = current; i < end; i++)
		{
			if (!IsLineFolded(i)) continue;

			UnfoldLine(i);

			await Task.Delay(85);

			for (int x = i + 1; x < end; x++)
			{
				FoldLine(x);
			}

			break;
		}

	}

}
