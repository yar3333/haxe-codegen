package codegen;

#if macro

interface IGenerator
{
	public function generate(types:Array<TypeDefinitionEx>) : Void;
}

#end