package root_pack.pack_a;

import root_pack.pack_a.TestClassC;

class TestBaseGeneric<MyT>
{
	function myFunc(obj:MyT) {}
}

class TestGeneric extends TestBaseGeneric<TestClassC>
{
}