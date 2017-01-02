class Run
{
	static function main()
	{
		var lazyInstance = new DisposableLazy(function ()
		{
			return new MyDisposable();
		});
		var x = lazyInstance.value;
		lazyInstance.dispose();
	}

#if violate_constraint
	function violateConstraint()
	{
		new DisposableLazy(function ()
		{
			return new MyNonDisposable();
		});
	}
#end
}

class MyNonDisposable
{
	public function new()
	{
	}
}

class MyDisposable implements IDisposable
{
	public function new()
	{
	}

	public function dispose()
	{
	}
}
