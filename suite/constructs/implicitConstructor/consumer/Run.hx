class SubClass extends BaseTest
{
	public function new()
	{
		super();
	}
}

class Run
{
	static function main()
	{
		var instance = new SubClass();
		var expected = 'This is a bass test';
		if (instance.forceImplicitConstructor != expected)
		{
			throw 'Expected ${expected}, actual: ${instance.forceImplicitConstructor}';
		}
	}
}
