package root_pack.pack_a;

@:jsRequire("my-npm", "pack_a.TestProperty") extern class TestProperty {
	var myProp(get, set) : Dynamic;
	private function get_myProp():Dynamic;
	private function set_myProp(v:Dynamic):Dynamic;
}