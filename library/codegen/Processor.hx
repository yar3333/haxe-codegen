package codegen;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
using haxe.macro.Tools;
using StringTools;
using Lambda;

class Processor
{
	var stdTypes =
	[
		"StdTypes.Float" => "Float",
		"StdTypes.Int" => "Int",
		"StdTypes.Void" => "Void",
		"StdTypes.Bool" => "Bool",
		"StdTypes.Null" => "Null",
		"StdTypes.Dynamic" => "Dynamic",
		"StdTypes.Iterator" => "Iterator",
		"StdTypes.Iterable" => "Iterable",
		"StdTypes.ArrayAccess" => "ArrayAccess"
	];
	
	var filter : Array<String>;
    var language: String;
	
	public function new(generator:IGenerator, applyNatives:Bool, filter:Array<String>, mapper:Array<{ from:String, to:String }>, isUnpackNull:Bool, includePrivate:Bool, requireNodeModule:String) 
	{
		if (filter == null || filter.length == 0) filter = [];
		if (mapper == null) mapper = [];

        filter = filter.map(x -> x.trim()).filter(x -> x != "" && !x.startsWith("//") && !x.startsWith("#"));
		
		this.filter = filter;
		this.language = generator.language;
		
		mapper = mapper.copy();
		mapper.reverse();
		
		for (key in stdTypes.keys())
		{
			filter.push("-" + key);
			mapper.push({ from:key, to:stdTypes.get(key) });
		}
		
		Context.onGenerate(function(types)
		{
			var typeDefs = [];
			for (type in types)
			{
                var tt = processType(type, includePrivate);
				if (isIncludeType(tt))
                {
                    forceExposeForType(type);
                    typeDefs.push(tt);
                    
                    if (!tt.isInterface)
                    {
                        switch (type)
                        {
                            case TInst(t, _): addRttiPathMeta(t.get());
                            case TEnum(t, _): addRttiPathMeta(t.get());
                            case _:
                        }
                    }   
                }
			}

			if (applyNatives) mapper = mapper.concat(Tools.extractNativesMapper(types));
			
			if (requireNodeModule != null && requireNodeModule != "")
            {
                Tools.addJsRequireMeta(typeDefs.filter(x -> !x.isInterface), requireNodeModule);
            }

			Tools.mapTypeDefs(typeDefs, mapper);

			Patcher.run
			(
				typeDefs,
				function(tp:TypePath)
				{
					Tools.mapType(mapper, tp);
					
					if (isUnpackNull && tp.name == "Null" && tp.params.length == 1)
					{
						switch (tp.params[0])
						{
							case TypeParam.TPType(ct):	return ct;
							case TypeParam.TPExpr(e):	// nothing to do
						}
					}
					
					return null;
				}
			);
			
			generator.generate(typeDefs);
		});
	}

    private function forceExposeForType(type:Type) : Void
    {
        switch (type)
        {
            case TInst(t, params): 
                var klass = t.get();
                if (!klass.meta.has(":expose")) klass.meta.add(":expose", [], klass.pos);
                
            case _:
        }
    }

    private function addRttiPathMeta(t: { meta:MetaAccess, pack:Array<String>, name:String })
    {
        if (t.meta.get().exists(x -> x.name == ":rtti") && !t.meta.get().exists(x -> x.name == "rtti.path"))
        {
            var rttiPath = t.pack.concat([ t.name ]).join(".");
            t.meta.add("rtti.path", [ macro $v{rttiPath} ], t.meta.get().find(x -> x.name == ":rtti").pos);
        }
    }
	
	function processType(type:Type, includePrivate:Bool) : TypeDefinitionEx
	{
		switch (type)
		{
			case Type.TInst(t, params):
				var c = t.get();
				
				if (!isIncludeType({ isPrivate:c.isPrivate, pack:c.pack, name:c.name, meta:c.meta.get() })) return createStube(c);
				
				var instanceFields = c.constructor != null ? [ c.constructor.get() ] : [];
				instanceFields = instanceFields.concat(c.fields.get());
				instanceFields = instanceFields.filter(x -> isIncludeClassField(instanceFields, x, includePrivate));
				fixGetterSetterReturnTypes(instanceFields);
				
				var staticFields = c.statics.get();
				staticFields = staticFields.filter(x -> isIncludeClassField(staticFields, x, includePrivate));
				fixGetterSetterReturnTypes(staticFields);

				return
				{
					doc : c.doc,
					module : c.module,
					pack : c.pack,
					name : c.name,
					pos : c.pos,
					meta : c.meta.get(),
					params : c.params.map(typeParameterToTypeParamDec),
					isExtern : c.isExtern,
					kind : TypeDefKind.TDClass(getTypePath(c.superClass), c.interfaces.map(getTypePath), c.isInterface),
					fields : instanceFields.map(classFieldToField.bind(c, false)).concat(staticFields.map(classFieldToField.bind(c, true))),
					isPrivate : c.isPrivate,
                    isInterface: c.isInterface
				};
				
			case Type.TEnum(t, params):
				var c = t.get();
				
				if (!isIncludeType({ isPrivate:c.isPrivate, pack:c.pack, name:c.name, meta:c.meta.get() })) return createStube(c);
				
				return
				{
					doc : c.doc,
					module : c.module,
					pack : c.pack,
					name : c.name,
					pos : c.pos,
					meta : c.meta.get(),
					params : c.params.map(typeParameterToTypeParamDec),
					isExtern : c.isExtern,
					kind : TypeDefKind.TDEnum,
					fields : c.constructs
						.filter(x -> !x.meta.has(":noapi") && !x.meta.has(":noapi_" + language))
						.map(enumFieldToField)
						.array(),
					isPrivate : c.isPrivate,
                    isInterface : false
				};
				
			case Type.TType(t, params):
				var c = t.get();
				
				if (!isIncludeType({ isPrivate:c.isPrivate, pack:c.pack, name:c.name, meta:c.meta.get() })) return createStube(c);

				return
				{
					doc : c.doc,
					module : c.module,
					pack : c.pack,
					name : c.name,
					pos : c.pos,
					meta : c.meta.get(),
					params : c.params.map(typeParameterToTypeParamDec),
					isExtern : c.isExtern,
					kind : TypeDefKind.TDAlias(typeToComplexType(c.type)),
					fields : null,
					isPrivate : c.isPrivate,
                    isInterface : false
				};
				
			case Type.TAbstract(t, params):
				var c = t.get();
				
				if (!isIncludeType({ isPrivate:c.isPrivate, pack:c.pack, name:c.name, meta:c.meta.get() })) return createStube(c);
				
				return
				{
					doc : c.doc,
					module : c.module,
					pack : c.pack,
					name : c.name,
					pos : c.pos,
					meta : c.meta.get(),
					params : c.params.map(typeParameterToTypeParamDec),
					isExtern : c.isExtern,
					kind : TypeDefKind.TDAlias(typeToComplexType(c.type)),
					fields : [], //c.constructs.map(enumFieldToField).array()
					isPrivate : c.isPrivate,
                    isInterface : false
				};
				
			case _:
				return null;
		}
	}
	
	function isIncludeClassField(fields:Array<ClassField>, f:ClassField, includePrivate:Bool) : Bool
	{
        if (f.meta.has(":noapi")) return false;
        if (f.meta.has(":noapi_" + language)) return false;
        if (f.meta.has(":compilerGenerated")) return false;
        
        if (f.name.startsWith("get_") || f.name.startsWith("set_"))
        {
            var propName = f.name.substring("get_".length);
            var prop = fields.find(x -> x.name == propName);
            if (prop != null)
            {
                if (Context.defined("jsprop") && prop.meta.has(":property")) return false;
            }
        }
        
        return f.isPublic || includePrivate;
	}
	
	function fixGetterSetterReturnTypes(fields:Array<ClassField>)
	{
		for (f in fields)
		{
			if (f.name.startsWith("get_") || f.name.startsWith("set_"))
			{
				var propFields = fields.filter(function(f2) return f2.name == f.name.substring("get_".length));
				if (propFields.length == 1)
				{
					switch (f.type)
					{
						case Type.TFun(args, ret):
							switch (ret)
							{
								case Type.TMono(t):
									if (t != null && t.get() == null)
									{
										f.type = Type.TFun(args, propFields[0].type);
									}
									
								case _:
							}
							
						case _:
					}
				}
			}
		}
	}
	
	function createStube(c: { isPrivate:Bool, pack:Array<String>, name:String, module:String, meta:MetaAccess } ) : TypeDefinitionEx
	{
		return
		{
			doc : null,
			module : c.module,
			pack : c.pack,
			name : c.name,
			pos : null,
			meta : c.meta.get(),
			params : [],
			isExtern : true,
			kind : TypeDefKind.TDClass(null, null, false),
			fields : [],
			isPrivate : c.isPrivate,
            isInterface : false
		};
	}
	
	function isIncludeType(c:{ isPrivate:Bool, pack:Array<String>, name:String, meta:Metadata }) : Bool
	{
		if (c == null || c.isPrivate) return false;
		
        if (c.meta.exists(x -> x.name == ":noapi") || c.meta.exists(x -> x.name == ":noapi_" + language)) return false;

		var fullName = c.pack.concat([c.name]).join(".");

        for (s in filter.filter(x -> x.startsWith("-")))
        {
            if (fullName == s.substring(1) || fullName.startsWith(s.substring(1) + ".")) return false;
        }
    
        if (c.meta.exists(x -> x.name == ":expose")) return true;

        for (s in filter.filter(x -> x.startsWith("+")))
        {
            if (s == "+*" || fullName == s.substring(1) || fullName.startsWith(s.substring(1) + ".")) return true;
        }
    
		return false;
	}
	
	function getTypePath(e:Null<{ t:Ref<ClassType>, params:Array<Type> }>) : TypePath
	{
		if (e == null || e.t == null) return null;
		var klass = e.t.get();
		if (klass == null) return null;
		
		return
		{
			pack : klass.pack,
			name : Tools.getShortClassName(klass.module),
			params : e.params.map(function(p) return TypeParam.TPType(typeToComplexType(p))),
			sub : klass.module == Tools.getFullClassName(klass.pack, klass.name) ? null : klass.name,
		};
	}
	
	function typeParameterToTypeParamDec(t:TypeParameter) : TypeParamDecl
	{
		switch (t.t)
		{
			case Type.TInst(tt, params):
				var ttt = tt.get();
				
				switch (ttt.kind)
				{
					case ClassKind.KTypeParameter(constraints):
						return
						{
							name: t.name,
							params: null,
							constraints: constraints.map(function(x) return typeToComplexType(x))
						};
					
					case _: throw "Unexpected";
				}
				
			case _: throw "Unexpected";
		}
	}
	
	function classFieldToField(klass:ClassType, isStatic:Bool, f:ClassField) : Field
	{
		var meta = f.meta.get();
		for (m in meta) if (m.name == ":real_overload") m.name = ":overload";
		
		return
		{
			name : f.name,
			doc : f.doc,
			access : getAccesses(klass, isStatic , f),
			kind : getFieldKind(f),
			pos : Context.currentPos(),
			meta : meta
		};
	}
	
	function enumFieldToField(f:EnumField) : Field
	{
		return
		{
			name : f.name,
			doc : f.doc,
			access : [],
			kind :
				switch (f.type)
				{
					case Type.TFun(args, ret):
						FieldType.FFun
						({
							args : args.map(toFunctionArg),
							ret: null,
							expr: null,
							params: []
						});
					case Type.TEnum(t, params):
						FieldType.FVar(null);
					case _:
						Context.fatalError("Enum field '" + f.name + "' unexpected type '" + f.type + "'.", f.pos);
				},
			pos : Context.currentPos(),
			meta : f.meta.get()
		};
	}
	
	function getAccesses(klass:ClassType, isStatic:Bool, f:ClassField) : Array<Access>
	{
		var r = [];
		
		if (f.isPublic) r.push(Access.APublic);
		else            r.push(Access.APrivate);
		
		if (isStatic) r.push(Access.AStatic);
		
		var superClass = klass != null && klass.superClass != null ? klass.superClass.t.get() : null;
		while (superClass != null)
		{
			if (superClass.fields.get().exists(function(f2) return f2.name == f.name))
			{
				r.push(Access.AOverride);
				break;
			}
			if (superClass.superClass == null) break;
			superClass = superClass.superClass.t.get();
		}
		
		switch (f.kind)
		{
			case FieldKind.FMethod(k):
				switch (k)
				{
					case MethodKind.MethInline:
						r.push(Access.AInline);
					case _:
				}
			case _:
		}
		
		return r;
	}
	
	function getFieldKind(f:ClassField) : FieldType
	{
		return switch (f.kind)
		{
			case FieldKind.FMethod(k):
				switch (f.type)
				{
					case Type.TFun(args, ret):
						FieldType.FFun
						({
							args : args.map(toFunctionArg),
							ret: typeToComplexType(ret),
							expr: null,
							params: f.params.map(typeParameterToTypeParamDec)
						});
						
					case _: 
						null;
				}
				
			case FieldKind.FVar(read, write):
				var sRead = readVarAccessToString(read);
				var sWrite = writeVarAccessToString(write);
				
				if (sRead == "default" && sWrite == "default")
				{
					FieldType.FVar(typeToComplexType(f.type));
				}
				else
				{
					FieldType.FProp(sRead, sWrite, typeToComplexType(f.type));
				}
		}
	}
	
	function readVarAccessToString(a:VarAccess) : String
	{
		return switch (a)
		{
			case VarAccess.AccNo: "null";
			case VarAccess.AccCall: "get";
			case VarAccess.AccNever: "never";
			case _: "default";
		}
	}
	
	function writeVarAccessToString(a:VarAccess) : String
	{
		return switch (a)
		{
			case VarAccess.AccNo: "null";
			case VarAccess.AccCall: "set";
			case VarAccess.AccNever: "never";
			case _: "default";
		}
	}
	
	function toFunctionArg(arg:{ name:String, opt:Bool, t:Type  }) : FunctionArg
	{
		return 
		{
			name: arg.name,
			opt: arg.opt,
			type: typeToComplexType(arg.t)
		};
	}
	
	function typeToComplexType(type:Type) : ComplexType
	{
		switch (type)
		{
			case Type.TAnonymous(a):
				var fields = a.get().fields
					.filter(f -> !f.meta.has(":noapi") && !f.meta.has(":noapi_" + language) && f.isPublic)
					.map(classFieldToField.bind(null, false))
					.map(function(f) { f.doc = f.doc; return f; });
				for (f in fields) f.access = f.access.filter(a -> a != Access.APublic && a != Access.APrivate);
				return ComplexType.TAnonymous(fields);
				
			case _:
				return type.toComplexType();
		}
	}
}
