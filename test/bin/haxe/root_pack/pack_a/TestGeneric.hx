package root_pack.pack_a;

@:jsRequire("my-npm", "pack_a.TestGeneric.TestBaseGeneric") extern class TestBaseGeneric<MyT> {
	private function myFunc(obj:MyT):Void;
}

@:jsRequire("my-npm", "pack_a.TestGeneric") extern class TestGeneric extends root_pack.pack_a.TestGeneric.TestBaseGeneric<root_pack.pack_a.TestClassC> {

}