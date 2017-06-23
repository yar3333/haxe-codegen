@:expose
class DisposableLazy<T:IDisposable> implements IDisposable
{
	public var value(get, null):T;
	var valueValue:T;
	var valueBuilt:Bool;
	var valueBuilder:Void->T;

	public function new(valueBuilder:Void->T)
	{
		this.valueBuilder = valueBuilder;
	}

	function get_value()
	{
		if (!valueBuilt)
		{
			valueValue = valueBuilder();
			valueBuilt = true;
		}
		return valueValue;
	}

	public function dispose()
	{
		if (valueBuilt)
		{
			valueValue.dispose();
		}
	}
}
