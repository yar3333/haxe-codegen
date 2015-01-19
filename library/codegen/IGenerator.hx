package codegen;

import haxe.macro.Expr;

interface IGenerator
{
	public function generate(types:Array<TypeDefinitionEx>) : Void;
}