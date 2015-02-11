package testpack;

extern class TestModule
{
	@:overload(function(src:String, options:Int) : String {})
	static function play(src:String, ?interrupt:String, ?delay:Int, ?offset:Int, ?loop:Int, ?volume:Float, ?pan:Float, ?startTime:Int, ?duration:Int) : String;
}