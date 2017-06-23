@:expose
class CallbackConsumer {
	public static function consume(value, f:String->(String->Void)->Void) {
		var last;
		f(value, function (newLast) {
			last = newLast;
		});
		return last;
	}
}
