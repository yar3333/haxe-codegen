package extgen;

import haxe.macro.Expr;
using Lambda;

class TypeMapper
{
	var map : Map<String, String>;
	
	public function new(map:Map<String, String>)
	{
		this.map = map;
	}
	
	public function process(types:Array<TypeDefinitionEx>)
	{
		for (type in types)
		{
			switch (type.kind)
			{
				case TypeDefKind.TDAbstract(t, from, to):
					processComplexType(t);
					if (from != null) from.iter(processComplexType);
					if (to != null) to.iter(processComplexType);
					
				case TypeDefKind.TDAlias(t):
					processComplexType(t);
					
				case TypeDefKind.TDClass: // nothing to do
				case TypeDefKind.TDEnum: // nothing to do
				case TypeDefKind.TDStructure: // nothing to do
			}
			
			if (type.fields != null) type.fields.iter(processField);
			type.params.iter(processTypeParamDecl);
		}
	}
	
	function processComplexType(ct:ComplexType)
	{
		if (ct == null) return;
		
		switch (ct)
		{
			case ComplexType.TPath(p):
				processTypePath(p);
				
			case ComplexType.TFunction(args, ret):
				args.iter(processComplexType);
				processComplexType(ret);
				
			case ComplexType.TAnonymous(fields):
				fields.iter(processField);
				
			case ComplexType.TParent(t):
				processComplexType(t);
				
			case ComplexType.TExtend(p, fields):
				p.iter(processTypePath);
				fields.iter(processField);
				
			case ComplexType.TOptional(t):
				processComplexType(t);
		}
	}
	
	function processField(field:Field)
	{
		switch (field.kind)
		{
			case FieldType.FFun(f):
				for (arg in f.args) processComplexType(arg.type);
				processComplexType(f.ret);
				f.params.iter(processTypeParamDecl);
				
			case FieldType.FProp(_, _, t, _):
				processComplexType(t);
				
			case FieldType.FVar(t, _):
				processComplexType(t);
		}
	}
	
	function processTypePath(tp:TypePath)
	{
		var path = tp.pack.concat([tp.name]);
		if (tp.sub != null) path.push(tp.sub);
		
		var to = map.get(path.join("."));
		if (to != null)
		{
			var n = to.lastIndexOf(".");
			if (n < 0)
			{
				tp.pack = [];
				tp.name = to;
			}
			else
			{
				tp.pack = to.substring(0, n).split(".");
				tp.name = to.substring(n + 1);
				
			}
			tp.sub = null;
		}
		
		tp.params.iter(processTypeParam);
	}
	
	function processTypeParamDecl(tp:TypeParamDecl)
	{
		if (tp.constraints != null) tp.constraints.iter(processComplexType);
		if (tp.params != null) tp.params.iter(processTypeParamDecl);
	}
	
	function processTypeParam(tp:TypeParam)
	{
		switch (tp)
		{
			case TypeParam.TPType(t): processComplexType(t);
			case _:
		}
	}
}