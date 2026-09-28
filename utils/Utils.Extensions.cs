using Godot;
using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;
using System.Threading.Tasks;

namespace InkodotEditor;

using GC = Godot.Collections;

public static partial class Utils
{
	/// <summary> Check if node is not deleted and not null. </summary>
	public static bool Valid<T>([NotNullWhen(true)] this T? obj) where T : GodotObject?
	{
		return GodotObject.IsInstanceValid(obj);
	}

	/// <summary> Check if node is deleted or null. </summary>
	public static bool Invalid<T>([NotNullWhen(false)] this T? obj) where T : GodotObject?
	{
		return !Valid(obj);
	}

	/// <summary> Check if string is empty or null </summary>
	public static bool IsNullOrEmpty([NotNullWhen(false)] this string? obj)
	{
		return string.IsNullOrEmpty(obj);
	}

	///<summary> Helper for Godot Dictionary</summary>
	public static bool ContainsValue<[MustBeVariant] TKey, [MustBeVariant] TValue>(this GC.Dictionary<TKey, TValue> dictionary, TValue value)
	{
		foreach (var pair in dictionary)
		{
			if (!EqualityComparer<TValue>.Default.Equals(pair.Value, value)) continue;

			return true;
		}

		return false;
	}

	/// <summary> Observes the task to avoid the UnobservedTaskException event to be raised.</summary>
	public static void Forget(this Task task)
	{
		if (!task.IsCompleted || task.IsFaulted)
		{
			_ = ForgetAwaited(task);
		}

		async static Task ForgetAwaited(Task task)
		{
			await task.ConfigureAwait(ConfigureAwaitOptions.SuppressThrowing);
		}
	}

}