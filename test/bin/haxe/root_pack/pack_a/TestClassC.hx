package root_pack.pack_a;

@:jsRequire("my-npm", "pack_a.TestClassC") extern class TestClassC {
	function new():Void;
	var linkA : root_pack.pack_a.TestClassC;
	var linkB : root_pack.RootClass;
}