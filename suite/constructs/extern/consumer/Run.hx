class Run
{
	static function main() {
		try {
			// Prove that things could be called without actually
			// binding to them at runtime. They’ll throw during
			// runtime (that’s why the try block) but should
			// compile fine.

			// Both overloads
			var x:String = TestExtern.play('src');
			var y:String = TestExtern.play('src', 32);
		} catch (ex:Dynamic) {
			// Run inlines.
			var instance:TestExtern = cast null;
			instance.myInlineFunc();
			TestExtern.myStaticInlineFunc();
		}
	}
}
