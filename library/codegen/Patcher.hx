package codegen;

import haxe.macro.Expr;
using Lambda;

class Patcher
{
	var customProcessTypePath : TypePath->ComplexType;
	var customProcessField : Field->Void;
	
	public static function run(types:Array<TypeDefinitionEx>, ?customProcessTypePath:TypePath->ComplexType, ?customProcessField:Field->Void)
	{
		var instance = new Patcher(customProcessTypePath ?? x -> null, customProcessField ?? x -> {});
		instance.process(types);
	}
	
	function new(customProcessTypePath:TypePath->ComplexType, customProcessField:Field->Void)
	{
		this.customProcessTypePath = customProcessTypePath;
		this.customProcessField = customProcessField;
	}
	
	function process(types:Array<TypeDefinitionEx>)
	{
		for (type in types)
		{
			switch (type.kind)
			{
				case TypeDefKind.TDAbstract(t, flags, from, to):
					processComplexType(t);
					processComplexTypes(from);
					processComplexTypes(to);
					
				case TypeDefKind.TDAlias(t):
					processComplexType(t);

                case TypeDefKind.TDClass(superClass, interfaces, isInterface, isFinal, isAbstract):
                    if (superClass != null) processTypePath(superClass);
                    if (interfaces != null) for (i in interfaces) processTypePath(i);
				
				case TypeDefKind.TDEnum: // nothing to do
				case TypeDefKind.TDStructure: // nothing to do
                case TypeDefKind.TDField(_, ): // nothing to do
			}
			
			if (type.fields != null) type.fields.iter(processField);
			type.params.iter(processTypeParamDecl);
            
            if (type.methodOverloads != null) for (_ => v in type.methodOverloads) v.iter(processField);
		}
	}
	
	function processComplexTypes(types:Array<ComplexType>)
	{
		if (types == null) return;
		for (i in 0...types.length)
		{
			var r = processComplexType(types[i]);
			if (r != null) types[i] = r;
		}
	}
	
	function processComplexType(ct:ComplexType) : ComplexType
	{
		if (ct == null) return null;
		
		switch (ct)
		{
			case ComplexType.TPath(p):
				return processTypePath(p);
				
			case ComplexType.TFunction(args, ret):
				processComplexTypes(args);
				return processComplexType(ret);
				
			case ComplexType.TAnonymous(fields):
				fields.iter(processField);
				
			case ComplexType.TParent(t):
				return processComplexType(t);
				
			case ComplexType.TExtend(p, fields):
				p.iter(processTypePath);
				fields.iter(processField);
				
			case ComplexType.TOptional(t):
				return processComplexType(t);

            case ComplexType.TIntersection(tl):
                processComplexTypes(tl);

            case ComplexType.TNamed(n, t):
                return processComplexType(t);
		}
		
		return null;
	}
	
	function processField(field:Field)
	{
		customProcessField(field);
		
		if (field.kind == null) return;
		
		switch (field.kind)
		{
			case FieldType.FFun(f):
				for (i in 0...f.args.length)
				{
					var r = processComplexType(f.args[i].type);
					if (r != null) f.args[i].type = r;
				}
				
				var r = processComplexType(f.ret);
				if (r != null) f.ret = r;
				
				f.params.iter(processTypeParamDecl);
				
			case FieldType.FProp(get, set, t, e):
				var r = processComplexType(t);
				if (r != null)
				{
					field.kind = FieldType.FProp(get, set, r, e);
				}
				
			case FieldType.FVar(t, e):
				var r = processComplexType(t);
				if (r != null)
				{
					field.kind = FieldType.FVar(r, e);
				}
		}
	}
	
	function processTypePath(tp:TypePath) : ComplexType
	{
        var r = customProcessTypePath(tp);
        if (r != null)
        {
            var r2 = processComplexType(r);
            return r2 != null ? r2 : r;
        }
		
		processTypeParams(tp.params);
		return null;
	}
	
	function processTypeParamDecl(tp:TypeParamDecl)
	{
		if (tp.constraints != null) processComplexTypes(tp.constraints);
		if (tp.params != null) tp.params.iter(processTypeParamDecl);
	}
	
	function processTypeParams(params:Array<TypeParam>)
	{
		for (i in 0...params.length)
		{
			params[i] = processTypeParam(params[i]);
		}
	}
	
	function processTypeParam(tp:TypeParam) : TypeParam
	{
		switch (tp)
		{
			case TypeParam.TPType(t):
				var r = processComplexType(t);
				if (r != null) return TypeParam.TPType(r);
			case _:
		}
		return tp;
	}
}
