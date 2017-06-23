@:expose
class BaseClass
{
	public function new()
	{
	}

	function inheritedFunction()
	{
		return 'BaseClass';
	}

	public function callInheritedFunction()
	{
		return inheritedFunction();
	}

	// TODO: In haxe, there is no such thing as private.
	// All functions are always accessible to sub-classes.
	// However, it is imaginable that one might want to
	// prevent functions defined in a library from showing
	// up in externs to help provide a stable public API.
	// I do not know how this should be done, though.
	//@:noexpose function modulePrivateFunction() { return 'BaseClass'; }
	//public function callModulePrivateFunction() { return modulePrivateFunction(); }
}
