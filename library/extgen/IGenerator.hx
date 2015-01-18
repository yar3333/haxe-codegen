package extgen;

import haxe.macro.Expr;

interface IGenerator
{
	public function generate(types:Array<TypeDefinitionAndDoc>) : Void;
}