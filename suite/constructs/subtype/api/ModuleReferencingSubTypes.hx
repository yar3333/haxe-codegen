import ModuleWithSubTypes;

@:expose
class ModuleReferencingSubTypes extends SubTypeA implements ISubTypeB {
	public var subTypedProperty(default, null) = new SubTypeA();

	public function new() {
		super();
	}

	public function getSubTypeA() {
		return new SubTypeA();
	}

	public function processA(value:SubTypeA) {
		return getSubTypeA() == value;
	}
}
