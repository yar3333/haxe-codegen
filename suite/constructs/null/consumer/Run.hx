class Run
{
	static function main()
	{
		callLambdaWithNullableInt(TestClass.useNullableInt);
	}

	static function callLambdaWithNullableInt(f:Null<Int>->Void)
	{
		f(23);
		f(null);
	}
}

class TestInterfaceImplementation implements ITestInterface
{
	public function returnNullableInt()
	{
		return 23;
	}
}

class TestInterfaceImplementation2 implements ITestInterface
{
	public function returnNullableInt():Null<Int>
	{
		return null;
	}
}
