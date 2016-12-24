class Run
{
	static function main()
	{
		var instance:ModuleWithSubTypes.ISubTypeB = new ModuleReferencingSubTypes();
		instance.processA(instance.getSubTypeA());
		instance.processA(instance.subTypedProperty);
	}
}
