package codegen;

interface IGenerator
{
	public function generate(types:Array<TypeDefinitionEx>) : Void;
    public var language(default, never) : String;
}
