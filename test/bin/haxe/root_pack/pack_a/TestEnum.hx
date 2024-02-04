package root_pack.pack_a;

@:jsRequire("my-npm", "pack_a.TestEnum") extern enum TestEnum {
	LikeVar;
	LikeFunc(a:Int);
}