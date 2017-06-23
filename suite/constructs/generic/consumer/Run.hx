class Run
{
	static function main()
	{
		// Test that we can use the generic directly.
		var testBaseGenericInt = new TestBaseGeneric<Int>();
		testBaseGenericInt.myFunc(32);

		// Test that we can use the closed generic (it’s
		// actually not generic, it just has type parameters).
		var testGeneric = new TestGeneric();
		testGeneric.myFunc(new TestClassC());
		var testBaseGenericClassC:TestBaseGeneric<TestClassC> = testGeneric;
		testBaseGenericClassC.myFunc(new TestClassC());
	}
}

private class TestGenericSubclass<T> extends TestBaseGeneric<T>
{
	public function new()
	{
		super();
	}
}
