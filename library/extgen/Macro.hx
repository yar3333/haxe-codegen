package extgen;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Printer;
import sys.FileSystem;
import sys.io.File;
import haxe.macro.Type;
import haxe.io.Path;
using haxe.macro.Tools;
using Lambda;
using StringTools;

private class Filter
{
	public var r(default, null) : EReg;
	public var isIncludeFilter(default, null) : Bool;
	
	public function new(pattern: String, isIncludeFilter:Bool)
	{
		r = new EReg(pattern, "");
		this.isIncludeFilter = isIncludeFilter;
	}
}

class Macro
{
	static var outDir : String;
	static var toplevelPackage = "";
	static var pathFilters = new Array<Filter>();
	
	public static macro function generateHaxeExternals(outDir:String, ?toplevelPackage:String) : Void
	{
		Macro.outDir = outDir;
		Macro.toplevelPackage = toplevelPackage != null ? toplevelPackage : "";
		Context.onGenerate(function(types) types.iter(processType));
	}
	
	static function processType(type:Type)
	{
		var tt : TypeDefinition;
		
		switch(type)
		{
			case Type.TInst(t, params):
				var c = t.get();
				
				tt =
				{
					pack : c.pack,
					name : c.name,
					pos : c.pos,
					meta : c.meta.get(),
					params : [], //c.params.map(stringToTypeParamDec), // todo
					isExtern : true, //c.isExtern,
					kind : TypeDefKind.TDClass(getTypePath(c.superClass), c.interfaces.map(getTypePath), c.isInterface),
					fields : c.fields.get().map(classFieldToField.bind(false)).concat(c.statics.get().map(classFieldToField.bind(true)))
				};
				
				write(tt);
				
			case Type.TEnum(t, params):
				var c = t.get();
				
				tt =
				{
					pack : c.pack,
					name : c.name,
					pos : c.pos,
					meta : c.meta.get(),
					params : [], // todo
					isExtern : true, //c.isExtern,
					kind : TypeDefKind.TDEnum,
					fields : c.constructs.map(enumFieldToField).array()
				};
				
				write(tt);
				
			case Type.TType(t, params):
				var c = t.get();
				
				tt =
				{
					pack : c.pack,
					name : c.name,
					pos : c.pos,
					meta : c.meta.get(),
					params : [], // todo
					isExtern : c.isExtern,
					kind : TypeDefKind.TDAlias(typeToComplexType(c.type)),
					fields : null
				};
				
				write(tt);
				
			case Type.TAbstract(t, params):
				var c = t.get();
				
				tt =
				{
					pack : c.pack,
					name : c.name,
					pos : c.pos,
					meta : c.meta.get(),
					params : [], // todo
					isExtern : true, //c.isExtern,
					kind : TypeDefKind.TDAlias(typeToComplexType(c.type)),
					fields : [] //c.constructs.map(enumFieldToField).array()
				};
				
				write(tt);
				
			case _:
		}
	}
	
	static function getTypePath(e:Null<{ t:Ref<ClassType> }>) : TypePath
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
	
	static function typeParameterToTypeParam(param:TypeParameter) : TypeParam
	{
		return TypeParam.TPType(typeToComplexType(param.t));
	}
	
	/*
	static function stringToTypeParamDec(s:String) : haxe.macro.TypeParamDecl
	{
		return
		{
			name:s,
			params:null,
			constraints:null
		};
	}
	*/
	
	static function classFieldToField(isStatic:Bool, f:ClassField) : Field
	{
		return
		{
			name : f.name,
			doc : f.doc,
			access : getAccesses(isStatic, f),
			kind : getFieldKind(f),
			pos : Context.currentPos(),
			meta : f.meta.get()
		};
	}
	
	static function enumFieldToField(f:EnumField) : Field
	{
		return
		{
			name : f.name,
			doc : f.doc,
			access : [],
			kind : FieldType.FFun
				({
					args : switch (f.type)
							{
								case Type.TFun(args, ret): args.map(toFunctionArg);
								case _: [];
							},
					ret: null,
					expr: null,
					params: []
				}),
			pos : Context.currentPos(),
			meta : f.meta.get()
		};
	}
	
	static function getAccesses(isStatic:Bool, f:ClassField) : Array<Access>
	{
		var r = [];
		//if (f.isOverride) r.push(Access.AOverride);
		if (f.isPublic) r.push(Access.APublic);
		else            r.push(Access.APrivate);
		if (isStatic) r.push(Access.AStatic);
		//if (f.set.match(Rights.RDynamic)) r.push(Access.ADynamic);
		return r;
	}
	
	static function getFieldKind(f:ClassField) : FieldType
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
							params: [] //Array<TypeParamDecl>
						});
						
					case _: 
						null;
				}
				
			case FieldKind.FVar(read, write):
				FieldType.FVar(typeToComplexType(f.type));
		}
	}
	
	static function toFunctionArg(arg:{ name:String, opt:Bool, t:Type  }) : FunctionArg
	{
		return 
		{
			name: arg.name,
			opt: arg.opt,
			type: typeToComplexType(arg.t)
		};
	}
	
	static function isTypeFiltered(type:{path:String, meta:Metadata, isPrivate:Bool})
	{
		if (hasNoapiMeta(type.meta)) return true;
		if (type.isPrivate) return true;
		return isPathFiltered(type.path);
	}

	static function isPathFiltered(path:String)
	{
		var hasInclusionFilter = false;
		for (filter in pathFilters)
		{
			if (filter.isIncludeFilter) hasInclusionFilter = true;
			if (filter.r.match(path)) return !filter.isIncludeFilter;
		}
		return hasInclusionFilter;
	}
	
	static function typeToComplexType(type:Type) : ComplexType
	{
		switch (type)
		{
			case Type.TAnonymous(a):
				var fields = a.get().fields.map(classFieldToField.bind((false)));
				for (f in fields) f.access = f.access.filter(function(a) return a != Access.APublic && a != Access.APrivate);
				return ComplexType.TAnonymous(fields);
				
			case _:
				return type.toComplexType();
		}
	}
	
	static function hasNoapiMeta(meta:Metadata) : Bool
	{
		return meta.exists(function(m) return m.name == "noapi");
	}
	
	static function write(tt:TypeDefinition)
	{
		var path = outDir + "/" + tt.pack.concat([ tt.name ]).join("/") + '.hx';
		var dir = haxe.io.Path.directory(path);
		if (dir != "" && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		File.saveContent(path, new Printer().printTypeDefinition(tt));
	}
}
