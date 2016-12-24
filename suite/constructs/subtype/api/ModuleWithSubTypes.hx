@:expose
class SubTypeA {
	public function new() {
	}
}

@:expose
interface ISubTypeB {
	var subTypedProperty(default, null):SubTypeA;
	function getSubTypeA():SubTypeA;
	function processA(a:SubTypeA):Bool;
}
