package root_pack.pack_a;

extern class TestExtern
{
	@:overload(function(src:String, options:Int) : String {})
	static function play(src:String, ?interrupt:String, ?delay:Int, ?offset:Int, ?loop:Int, ?volume:Float, ?pan:Float, ?startTime:Int, ?duration:Int) : String;
	
	inline function myInlineFunc() : Void { }
	static inline function myStaticInlineFunc() : Void { }
}