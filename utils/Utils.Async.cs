using System;
using System.Threading;
using System.Threading.Tasks;
using Godot;

namespace InkodotEditor;

using CT = CancellationToken;

public static partial class Utils
{
	//> Delay

	public static async Task DelaySeconds(float seconds, CT ct = default)
	{
		await Task.Delay(TimeSpan.FromSeconds(seconds), ct);
	}

	/// <summary> Await the next Godot process frame. </summary>
	public static async Task NextFrame(Node node, CT ct = default)
	{
		if (ct.IsCancellationRequested) return;
		if (node.Invalid()) return;

		var tree = node.GetTree();
		if (tree is null)
		{
			await Task.Yield();
			return;
		}

		await node.ToSignal(tree, SceneTree.SignalName.ProcessFrame);
		ct.ThrowIfCancellationRequested();
	}

}