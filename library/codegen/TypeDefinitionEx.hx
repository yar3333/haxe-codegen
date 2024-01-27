package codegen;

#if macro

import haxe.macro.Expr;

typedef TypeDefinitionEx =
{>TypeDefinition,

	doc:String,
	module:String,
	isPrivate:Bool
}

#end
