package codegen;

interface IGenerator
{
    public var language(default, never) : String;
    public var isApplyNatives(default, never) : Bool;
    public var nodeModule(default, null): String;
	
    public function generate(types:Array<TypeDefinitionEx>) : Void;
}
