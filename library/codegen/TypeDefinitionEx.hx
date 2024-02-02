package codegen;

import haxe.macro.Expr;

typedef TypeDefinitionEx =
{>TypeDefinition,

	doc : String,
	module : String,
	isPrivate : Bool,
	isInterface : Bool
}
