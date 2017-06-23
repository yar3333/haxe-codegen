class Run
{
	public static function main()
	{
		var result = CallbackConsumer.consume('asdf', function (value, cb) {
			cb('x${value}');
		});
		if (result != 'xasdf')
		{
			throw 'Expected xasdf, got ${result}';
		}
	}
}
