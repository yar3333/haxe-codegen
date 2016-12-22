package p;

@:expose
enum TestEnum
{
	Larry;
	LikeVar;
	LikeFunc(a:Int);
}

// For some reason, haxe won’t expose the enum properly.
// So hackily expose it for now. TODO: file bug report
// against haxe or change how codegen handles enums to
// be consistent with how Haxe represents enums in emitted
// code (needs research).
#if js
@:native("(()=>global.p={TestEnum:p_TestEnum})()") extern class X { static var x:Int; }
class Y { static var z = X.x; } // Cause the native to be emitted
#end
