package testpack;

typedef TestTypeDef =
{
	var mysecVar : String;
	var myvar : Int;
}


@:native("myNativePack.NativeName")
extern enum TestEnum
{
	B(test:Int);
	A;
}