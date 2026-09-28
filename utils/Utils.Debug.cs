using Godot;

namespace InkodotEditor;

public static partial class Utils
{
	public static void PushDebug(this GodotObject? obj, string message)
	{
		var tag = obj?.GetType().Name ?? "null";
		GD.Print($"[{tag}] {message}");
	}

	public static void PushError(this GodotObject? obj, string message)
	{
		var tag = obj?.GetType().Name ?? "null";
		GD.PushError($"[{tag}] {message}");
	}

	public static void PushWarning(this GodotObject? obj, string message)
	{
		var tag = obj?.GetType().Name ?? "null";
		GD.PushWarning($"[{tag}] {message}");
	}
}