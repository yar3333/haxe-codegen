package root_pack.pack_a;

@:jsRequire("my-npm", "pack_a.TestExtern") extern class TestExtern {
	@:overload(function(src:String, options:Int):String { })
	static function play(src:String, ?interrupt:String, ?delay:Int, ?offset:Int, ?loop:Int, ?volume:Float, ?pan:Float, ?startTime:Int, ?duration:Int):String;
}