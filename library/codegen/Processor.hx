package codegen;

import neko.Lib;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Printer;
import sys.FileSystem;
import sys.io.File;
import haxe.macro.Type;
import haxe.io.Path;
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
	var types : Array<Type>;
	
	public function new(generator:IGenerator, applyNatives:Bool, filter:Array<String>, mapper:Array<{ from:String, to:String }>) 
	{
		if (filter == null || filter.length == 0) filter = [ "+*" ];
		if (mapper == null) mapper = [];
		
		this.filter = filter;
		
		mapper = mapper.copy();
		mapper.reverse();
		
		for (key in stdTypes.keys())
		{
			filter.push("-" + key);
			mapper.push({ from:key, to:stdTypes.get(key) });
		}
		
		Context.onGenerate(function(innerTypes)
		{
			types = innerTypes;
			
			var typeDefs = [];
			for (type in types)
			{
				var r = processType(type);
				if (r != null) typeDefs.push(r);
			}
			
			if (applyNatives) Tools.applyNatives(typeDefs);
			
			typeDefs = typeDefs.filter(function(tt) return !isExcludeType(tt));
			
			Patcher.run(typeDefs, Tools.mapType.bind(mapper));
			
			generator.generate(typeDefs);
		});
	}
	
	function processType(type:Type) : TypeDefinitionEx
	{
		switch (type)
		{
			case Type.TInst(t, params):
				var c = t.get();
				
				if (isExcludeType({ pack:c.pack, name:c.name, meta:c.meta.get() })) return createStube(c);
				
				var instanceFields = c.constructor != null ? [ c.constructor.get() ] : [];
				instanceFields = instanceFields.concat(c.fields.get());
				instanceFields = instanceFields.filter(function(f) return !f.meta.has(":noapi") && f.isPublic);
				instanceFields = instanceFields.filter(function(f) return !f.name.startsWith("get_") && !f.name.startsWith("set_") || !instanceFields.exists(function(f2) return f2.name == f.name.substring("get_".length)));
				
				var staticFields = c.statics.get();
				staticFields = staticFields.filter(function(f) return !f.meta.has(":noapi") && f.isPublic);
				staticFields = staticFields.filter(function(f) return !f.name.startsWith("get_") && !f.name.startsWith("set_") || !staticFields.exists(function(f2) return f2.name == f.name.substring("get_".length)));
				
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
					fields : instanceFields.map(classFieldToField.bind(c, false)).concat(staticFields.map(classFieldToField.bind(c, true)))
				};
				
			case Type.TEnum(t, params):
				var c = t.get();
				
				if (isExcludeType({ pack:c.pack, name:c.name, meta:c.meta.get() })) return createStube(c);
				
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
						.filter(function(f) return !f.meta.has(":noapi"))
						.map(enumFieldToField)
						.array()
				};
				
			case Type.TType(t, params):
				var c = t.get();
				
				if (isExcludeType({ pack:c.pack, name:c.name, meta:c.meta.get() })) return createStube(c);
				
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
					fields : null
				};
				
			case Type.TAbstract(t, params):
				var c = t.get();
				
				if (isExcludeType({ pack:c.pack, name:c.name, meta:c.meta.get() })) return createStube(c);
				
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
					fields : [] //c.constructs.map(enumFieldToField).array()
				};
				
			case _:
				return null;
		}
	}
	
	function createStube(c: { pack:Array<String>, name:String, module:String, meta:MetaAccess } ) : TypeDefinitionEx
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
			fields : []
		};
	}
	
	function isExcludeType(c:{ pack:Array<String>, name:String, meta:Metadata }) : Bool
	{
		var path = c.pack.concat([c.name]).join(".");
		
		if (filter.length > 0)
		{
			var included = false;
			for (s in filter)
			{
				s = s.trim();
				if (s == "" || s.startsWith("#") || s.startsWith("//")) continue;
				if (s.startsWith("-"))
				{
					if (path == s.substring(1) || path.startsWith(s.substring(1) + ".")) return true;
				}
				else 
				if (s.startsWith("+"))
				{
					if (s == "+*" || path == s.substring(1) || path.startsWith(s.substring(1) + ".")) included = true;
				}
				else
				{
					Context.fatalError("Unknow filter string '" + s + "'.", Context.currentPos());
				}
			}
			if (!included) return true;
		}
		
		return c.meta.exists(function(m) return m.name==":noapi");
	}
	
	function getTypePath(e:Null<{ t:Ref<ClassType> }>) : TypePath
	{
		if (e == null || e.t == null) return null;
		var klass = e.t.get();
		if (klass == null) return null;
		
		return
		{
			pack: klass.pack,
			name: klass.name,
			params: klass.params.map(typeParameterToTypeParam),
			sub: null
		};
	}
	
	function typeParameterToTypeParam(param:TypeParameter) : TypeParam
	{
		return TypeParam.TPType(typeToComplexType(param.t));
	}
	
	
	function typeParameterToTypeParamDec(t:TypeParameter) : TypeParamDecl
	{
		return
		{
			name:t.name,
			params:null,
			constraints:null
		};
	}
	
	function classFieldToField(klass:ClassType, isStatic:Bool, f:ClassField) : Field
	{
		return
		{
			name : f.name,
			doc : f.doc,
			access : getAccesses(klass, isStatic , f),
			kind : getFieldKind(f),
			pos : Context.currentPos(),
			meta : f.meta.get()
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
					.filter(function(f) return !f.meta.has(":noapi") && f.isPublic)
					.map(classFieldToField.bind(null, false))
					.map(function(f) { f.doc = f.doc; return f; });
				for (f in fields) f.access = f.access.filter(function(a) return a != Access.APublic && a != Access.APrivate);
				return ComplexType.TAnonymous(fields);
				
			case _:
				return type.toComplexType();
		}
	}
	
	function getClass(klassPath:TypePath) : ClassType
	{
		if (klassPath == null) return null;
		
		for (type in types)
		{
			switch (type)
			{
				case Type.TInst(t, params):
					var c = t.get();
					if (c.pack.concat([c.name]).join(".") == klassPath.pack.concat([klassPath.name]).join(".")) return c;
				case _:
			}
		}
		return null;
	}
}