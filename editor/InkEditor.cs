using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Godot;
using Ink;
using GodotInk;

namespace InkodotEditor;

using GC = Godot.Collections;

[Tool]
public sealed partial class InkEditor : CodeEdit
{
	[Export(PropertyHint.Dir)] public string MainFolder = "res://";
	[Export(PropertyHint.File, "*.ink")] public string? FilePath;

	[ExportSubgroup("Ink Files")]
	[Export] public InkStory? CurrentStory;

	[ExportSubgroup("Nodes")]
	[Export] public Control? DialogueNode;

	[ExportSubgroup("Readonly")]
	[Export] public string Title = "...";

	[Export] public GC.Dictionary<string, string> StoriesSaveCache = [];

	[Export] public GC.Dictionary<int, string> Errors = [];
	[Export] public GC.Dictionary<int, string> Warnings = [];

	[Signal] public delegate void OnTextUpdatedEventHandler();
	[Signal] public delegate void SaveStateModifiedEventHandler();

	public List<int> ChoiceHistoryList = [];
	public bool IsUpdating;

	readonly HashSet<int> ColoredLines = [];


	//> Platform helpers

	/// <summary> True when running on a mobile platform (Android / iOS). </summary>
	public static bool IsMobile =>
		OS.HasFeature("mobile") || OS.HasFeature("android") || OS.HasFeature("ios");


	//> Main

	public override void _Ready()
	{
		if (Engine.IsEditorHint()) return;

		try
		{
			ProjectSettings.SetSetting("application/run/low_processor_mode", true);

			// Resolve the initial workspace:
			//   1. The user's last-opened folder, if it still exists on disk.
			//   2. The platform-appropriate default (see GetStandaloneRoot).
			if (MainFolder.IsNullOrEmpty() || MainFolder == "res://")
			{
				var saved = LoadLastFolder();
				if (!saved.IsNullOrEmpty())
				{
					MainFolder = saved;
					GD.Print($"[Inkodot] Restored last folder: '{saved}'");
				}
				else
				{
					MainFolder = GetStandaloneRoot();
				}
			}

			// If the workspace is empty (first launch, or user cleared it),
			// populate it with the demos bundled inside the .pck.
			EnsureDemoFiles();

			CreateMenu();

			TextChanged += () => Update().Forget();
			Update(true).Forget();
		}
		catch (Exception ex)
		{
			GD.PrintErr($"{ex}");
		}
	}

	public async Task Update(bool newFile = false)
	{
		while (IsUpdating)
			await Task.Delay(200);

		IsUpdating = true;

		ClearLinesBG();
		ClearStoryPage();

		LoadInkText();

		Title = Path.GetFileName(FilePath) ?? "...";

		if (newFile) StartDialogue();
		else LoadDialogue();

		IsUpdating = false;
		EmitSignal(SignalName.OnTextUpdated);
	}

	public void ChooseChoiceIndex(int index, bool saveChoice)
	{
		CurrentStory?.ChooseChoiceIndex(index);

		if (saveChoice)
		{
			ChoiceHistoryList.Add(index);
		}
	}

	/// <summary>
	/// Detach the editor from the current file and clear all associated state.
	/// Used when a file or folder the editor is bound to gets deleted.
	/// </summary>
	public void ClearFile()
	{
		if (!FilePath.IsNullOrEmpty())
			StoriesSaveCache.Remove(FilePath);

		ClearLinesBG();

		Text = "";

		FilePath = null;
		CurrentStory = null;
		Title = "...";
		ChoiceHistoryList.Clear();
		Errors.Clear();
		Warnings.Clear();

		if (!DialogueNode.Invalid())
			DialogueNode.CallDeferred("clear");

		EmitSignal(SignalName.OnTextUpdated);
	}

	void ClearStoryPage()
	{
		Errors.Clear();
		Warnings.Clear();
		Title = "";
	}

	void StartDialogue()
	{
		if (DialogueNode.Invalid()) return;

		ChoiceHistoryList.Clear();

		if (CurrentStory is null)
		{
			DialogueNode.CallDeferred("clear");
			return;
		}

		DialogueNode.CallDeferred("start", CurrentStory);
	}

	async void LoadDialogue()
	{
		if (DialogueNode.Invalid()) return;

		if (CurrentStory is null)
		{
			DialogueNode.CallDeferred("clear");
			return;
		}

		DialogueNode.CallDeferred("load_choices", CurrentStory, GetChoiceHistory());
	}

	void LoadInkText()
	{
		if (Text.IsNullOrEmpty())
		{
			CurrentStory = null;
			return;
		}

		try
		{
			CurrentStory = CompileStory(FilePath);
			CurrentStory?.Initialize();
		}
		catch (Exception ex)
		{
			CurrentStory = null;
			Errors[0] = $"{ex}";
		}
	}


	//> Workspace resolution

	/// <summary>
	/// Resolves the folder the standalone editor uses as its home.
	///
	/// Desktop: prefers &lt;exe_dir&gt;/ink/; falls back to
	/// &lt;user_data_dir&gt;/ink/ if the exe dir is unusable.
	///
	/// Android/iOS: the app is sandboxed and the executable lives inside
	/// the .apk / .ipa archive — there is no writable "next to the binary".
	/// We use the app's private data directory.
	/// </summary>
	static string GetStandaloneRoot()
	{
		// --- Android / iOS ---------------------------------------------
		if (IsMobile)
		{
			var mobileRoot = OS.GetUserDataDir().PathJoin("ink");
			DirAccess.MakeDirRecursiveAbsolute(mobileRoot);
			GD.Print($"[Inkodot] Mobile root: {mobileRoot}");
			return mobileRoot;
		}

		// --- Desktop ---------------------------------------------------
		var exePath = OS.GetExecutablePath();
		GD.Print($"[Inkodot] Executable path: '{exePath}'");

		var exeDir = exePath.GetBaseDir();

		if (OS.HasFeature("macos") && exeDir.GetFile() == "MacOS")
		{
			exeDir = exeDir.GetBaseDir().GetBaseDir().GetBaseDir();
			GD.Print($"[Inkodot] macOS bundle detected, walked out to: '{exeDir}'");
		}

		var exeDirValid =
			!exeDir.IsNullOrEmpty() &&
			exeDir != "/" &&
			exeDir.IsAbsolutePath() &&
			DirAccess.DirExistsAbsolute(exeDir);

		if (!exeDirValid)
		{
			GD.PushWarning(
				$"[Inkodot] Executable directory is unusable (got '{exeDir}'). " +
				"Falling back to user data directory.");

			var fallback = OS.GetUserDataDir().PathJoin("ink");
			DirAccess.MakeDirRecursiveAbsolute(fallback);
			return fallback;
		}

		var root = exeDir.PathJoin("ink");
		GD.Print($"[Inkodot] Using root folder: '{root}'");

		if (!DirAccess.DirExistsAbsolute(root))
		{
			var err = DirAccess.MakeDirRecursiveAbsolute(root);
			if (err != Error.Ok)
			{
				GD.PushWarning(
					$"[Inkodot] Could not create {root} (error {err}). " +
					"Falling back to user data directory.");

				var fallback = OS.GetUserDataDir().PathJoin("ink");
				DirAccess.MakeDirRecursiveAbsolute(fallback);
				return fallback;
			}
		}

		return root;
	}


	//> Demo extraction

	/// <summary>
	/// If the workspace contains no .ink files, copies the demos bundled at
	/// res://ink_demos/ into the workspace. Never overwrites existing files.
	///
	/// On desktop this duplicates the export plugin's "ink/" folder work, but
	/// the two don't conflict — the plugin writes next to the executable at
	/// export time, this writes into the resolved workspace at first launch,
	/// and both skip when files already exist.
	///
	/// On mobile this is the *only* way demos reach the user, since there is
	/// no writable location next to the APK.
	/// </summary>
	void EnsureDemoFiles()
	{
		if (MainFolder.IsNullOrEmpty()) return;
		if (!DirAccess.DirExistsAbsolute(MainFolder)) return;

		if (HasAnyInkFiles(MainFolder))
		{
			GD.Print("[Inkodot] Workspace already has .ink files, skipping demo extraction.");
			return;
		}

		var demoSource = "res://ink_demos";
		if (!DirAccess.DirExistsAbsolute(demoSource))
		{
			GD.Print("[Inkodot] No demos bundled, skipping extraction.");
			return;
		}

		GD.Print($"[Inkodot] Extracting demos to '{MainFolder}'...");
		CopyDirectoryRecursive(demoSource, MainFolder);
	}

	bool HasAnyInkFiles(string path)
	{
		var dir = DirAccess.Open(path);
		if (dir == null) return false;

		foreach (var f in dir.GetFiles())
		{
			if (f.EndsWith(".ink", StringComparison.OrdinalIgnoreCase))
				return true;
		}

		foreach (var sub in dir.GetDirectories())
		{
			if (HasAnyInkFiles(path.PathJoin(sub)))
				return true;
		}

		return false;
	}

	void CopyDirectoryRecursive(string srcRes, string dstAbs)
	{
		DirAccess.MakeDirRecursiveAbsolute(dstAbs);

		var dir = DirAccess.Open(srcRes);
		if (dir == null) return;

		foreach (var file in dir.GetFiles())
		{
			// Skip editor metadata companions.
			if (file.EndsWith(".import", StringComparison.OrdinalIgnoreCase))
				continue;

			var srcPath = srcRes.PathJoin(file);
			var dstPath = dstAbs.PathJoin(file);

			using var src = Godot.FileAccess.Open(srcPath, Godot.FileAccess.ModeFlags.Read);
			if (src == null) continue;

			var bytes = src.GetBuffer((long)src.GetLength());

			using var dst = Godot.FileAccess.Open(dstPath, Godot.FileAccess.ModeFlags.Write);
			if (dst == null) continue;

			dst.StoreBuffer(bytes);
		}

		foreach (var sub in dir.GetDirectories())
		{
			CopyDirectoryRecursive(srcRes.PathJoin(sub), dstAbs.PathJoin(sub));
		}
	}


	//> Session persistence

	const string ConfigPath     = "user://inkodot.cfg";
	const string SessionSection = "session";
	const string LastFolderKey  = "last_folder";

	static string LoadLastFolder()
	{
		// The last-folder concept doesn't apply on mobile — there is only
		// one workspace. Save the lookup entirely.
		if (IsMobile) return "";

		var cfg = new ConfigFile();
		if (cfg.Load(ConfigPath) != Error.Ok) return "";

		var value = cfg.GetValue(SessionSection, LastFolderKey, "");
		var path = value.AsString();

		if (path.IsNullOrEmpty()) return "";
		if (!DirAccess.DirExistsAbsolute(path)) return "";

		return path;
	}

	public void SaveLastFolder()
	{
		if (IsMobile) return;
		if (MainFolder.IsNullOrEmpty()) return;

		var cfg = new ConfigFile();
		cfg.Load(ConfigPath);
		cfg.SetValue(SessionSection, LastFolderKey, MainFolder);

		var err = cfg.Save(ConfigPath);
		if (err != Error.Ok)
			GD.PushWarning($"[Inkodot] Could not save session config: {err}");
	}


	//> Choice History

	int[] GetChoiceHistory() => [.. ChoiceHistoryList];

	void SetChoiceHistory(int[] newHistory) => ChoiceHistoryList = [.. newHistory];


	//> File

	public void SetRootDir(string path)
	{
		MainFolder = path;
	}

	public void SetNewFile(string? path)
	{
		try
		{
			CacheCurrentStory();
			FilePath = path;

			if (!FilePath.IsNullOrEmpty())
			{
				if (StoriesSaveCache.TryGetValue(FilePath, out var text))
				{
					Text = text;
				}
				else
				{
					var globalPath = ProjectSettings.GlobalizePath(FilePath);
					Text = File.ReadAllText(globalPath);
				}
			}
		}
		catch (Exception ex)
		{
			GD.PushWarning($"{ex}");
		}

		Update(true).Forget();
	}


	//> Save - File

	public bool IsFileChanged(string path)
	{
		if (StoriesSaveCache.ContainsKey(path))
		{
			return true;
		}

		if (path != FilePath) return false;

		var globalPath = ProjectSettings.GlobalizePath(path);
		var text = File.ReadAllText(globalPath);

		return !text.Equals(Text, StringComparison.Ordinal);
	}

	public void RemoveFromCache(string path)
	{
		StoriesSaveCache.Remove(path);

		if (FilePath == path)
		{
			var globalPath = ProjectSettings.GlobalizePath(FilePath);
			Text = File.ReadAllText(globalPath);

			Update(true).Forget();
		}

		EmitSignal(nameof(SaveStateModified));
	}

	public void WriteFile(string? path)
	{
		if (MainFolder.IsNullOrEmpty()) return;
		if (path.IsNullOrEmpty()) return;

		try
		{
			var story = CompileStory(path);
			if (story is null) return;
		}
		catch (Exception ex)
		{
			GD.PushError($"{ex}");
		}

		string? text = null;

		if (path == FilePath)
		{
			text = Text;
		}
		else if (StoriesSaveCache.TryGetValue(path, out var storyText))
		{
			text = storyText;
		}

		if (text is null) return;

		StoriesSaveCache.Remove(path);

		var globalPath = ProjectSettings.GlobalizePath(path);
		File.WriteAllText(globalPath, text);

		EmitSignal(nameof(SaveStateModified));
	}

	void CacheCurrentStory()
	{
		if (FilePath.IsNullOrEmpty()) return;
		if (Text.IsNullOrEmpty()) return;

		var globalPath = ProjectSettings.GlobalizePath(FilePath);
		if (!File.Exists(globalPath)) return;

		var text = File.ReadAllText(globalPath);

		if (!text.Equals(Text, StringComparison.Ordinal))
		{
			StoriesSaveCache[FilePath] = Text;
		}
	}


	//> Save - Session

	public void DiscardSession()
	{
		StoriesSaveCache.Clear();

		if (!FilePath.IsNullOrEmpty())
		{
			var globalPath = ProjectSettings.GlobalizePath(FilePath);
			var text = File.ReadAllText(globalPath);
			Text = text;
		}

		EmitSignal(nameof(SaveStateModified));
	}

	public void SaveSession()
	{
		if (!FilePath.IsNullOrEmpty())
		{
			StoriesSaveCache.Add(FilePath, Text);
		}

		foreach (var pair in StoriesSaveCache)
		{
			var path = pair.Key;
			var text = pair.Value;

			try
			{
				var story = CompileStory(path);
				if (story is null)
				{
					GD.PushError($"Can't save {FilePath}!");
					return;
				}
			}
			catch (Exception ex)
			{
				GD.PushError($"{ex}");
			}

			var globalPath = ProjectSettings.GlobalizePath(path);
			File.WriteAllText(globalPath, text);
		}

		StoriesSaveCache.Clear();

		EmitSignal(nameof(SaveStateModified));
	}


	//> Syntax

	void ClearLinesBG()
	{
		foreach (var lineNum in ColoredLines)
		{
			if (GetLineCount() > lineNum)
				SetLineBackgroundColor(lineNum, Colors.Transparent);
		}

		ColoredLines.Clear();
	}


	//> Ink Compiler

	InkStory? CompileStory(string? path)
	{
		var options = new Compiler.Options
		{
			errorHandler = InkCompilerErrorHandler,
		};

		if (!path.IsNullOrEmpty() && Godot.FileAccess.FileExists(path))
		{
			var globalPath = ProjectSettings.GlobalizePath(path);
			var folder = Path.GetDirectoryName(globalPath);

			if (folder is not null)
			{
				options.sourceFilename = globalPath;
				options.fileHandler = new FileHandler(folder);
			}
		}

		var compiler = new Compiler(Text, options);
		var json = compiler?.Compile()?.ToJson();
		if (json is null) return null;

		return new InkStory(json);
	}

	class FileHandler(string rootDir) : IFileHandler
	{
		public string ResolveInkFilename(string includedFileNames)
			=> Path.Combine(rootDir, includedFileNames);

		public string LoadInkFileContents(string fullFileName)
			=> File.ReadAllText(fullFileName);
	}

	void InkCompilerErrorHandler(string message, ErrorType errorType)
	{
		var lineNumRegEx = RegEx.CreateFromString(@"(?<=line) \d*");
		var lineNumMatch = lineNumRegEx.Search(message);

		var messageRegEx = RegEx.CreateFromString(@"(line \d*: )\K.*");
		var messageStrMatch = messageRegEx.Search(message);

		if (errorType == ErrorType.Error)
		{
			var num = lineNumMatch.GetString().ToInt();

			if (!Warnings.ContainsValue(message))
			{
				Errors[num] = messageStrMatch?.GetString() ?? message;

				var color = new Color(1, 0, 0, 0.25f);
				CallDeferred(TextEdit.MethodName.SetLineBackgroundColor, num - 1, color);

				ColoredLines.Add(num - 1);
			}

			return;
		}

		if (errorType == ErrorType.Warning)
		{
			var num = lineNumMatch.GetString().ToInt();

			if (!Warnings.ContainsValue(message))
			{
				Warnings[num] = messageStrMatch?.GetString() ?? message;

				var color = new Color(1, 0.5f, 0, 0.25f);
				CallDeferred(TextEdit.MethodName.SetLineBackgroundColor, num - 1, color);

				ColoredLines.Add(num - 1);
			}

			return;
		}
	}
}