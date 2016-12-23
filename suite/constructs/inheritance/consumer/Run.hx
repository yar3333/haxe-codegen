class Run
{
	static function main()
	{
		var instance = new BaseClass();
		assertEqual('BaseClass', instance.callInheritedFunction());

		// Polymorphic!
		instance = new SubClass();
		assertEqual('SubClass', instance.callInheritedFunction(), 'Base class did not see override.');
		// Now access our subclass directly…
		var subInstance = new SubClass();
		assertEqual('BaseClass', subInstance.callBaseInheritedFunction(), 'Class called wrong function when trying to access super');
	}

	static function assertEqual<T>(expected:T, actual:T, ?m:String)
	{
		if (expected != actual)
		{
			throw '${if (m == null) 'Assertion failed' else m}: expected=${expected}, actual=${actual}';
		}
	}
}

private class SubClass extends BaseClass
{
	override function inheritedFunction()
	{
		return 'SubClass';
	}

	public function callBaseInheritedFunction()
	{
		return super.inheritedFunction();
	}
}
