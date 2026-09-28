using Godot;
using System;

namespace InkodotEditor;

public static class Signals
{
	/// <summary> Connect a signal only if it isn't already connected. </summary>
	public static bool TryConnect(GodotObject? emitter, StringName signal, Callable callable)
	{
		if (emitter.Invalid()) return false;
		if (!emitter.HasSignal(signal)) return false;
		if (emitter.IsConnected(signal, callable)) return false;

		emitter.Connect(signal, callable);
		return true;
	}

	// Convenience overloads so method groups resolve without wrapping in Callable.From.
	public static bool TryConnect(GodotObject? emitter, StringName signal, Action callback)
		=> TryConnect(emitter, signal, Callable.From(callback));

	public static bool TryConnect<[MustBeVariant] T>(GodotObject? emitter, StringName signal, Action<T> callback)
		=> TryConnect(emitter, signal, Callable.From(callback));

	public static bool TryConnect<[MustBeVariant] T1, [MustBeVariant] T2>(GodotObject? emitter, StringName signal, Action<T1, T2> callback)
		=> TryConnect(emitter, signal, Callable.From(callback));
}