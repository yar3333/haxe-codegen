package extgen;

import neko.Lib;
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

class Processor
{
	var toplevelPackage:String;
	var includeRegex:EReg;
	var excludeRegex:EReg;
	
	public function new(toplevelPackage:String, includeRegex:EReg, excludeRegex:EReg, generator:IGenerator) 
	{
		this.toplevelPackage = toplevelPackage;
		this.includeRegex = includeRegex;
		this.excludeRegex = excludeRegex;
		
		Context.onGenerate(function(types)
		{
			var typeDefs = [];
			for (type in types)
			{
				var r = processType(type);
				if (r != null) typeDefs.push(r);
			}
			generator.generate(typeDefs);
		});
	}
	
	function processType(type:Type) : TypeDefinitionAndDoc
	{
		switch (type)
		{
			case Type.TInst(t, params):
				var c = t.get();
				if (isExcludeType(c)) return null;
				return
				{
					doc : c.doc,
					pack : c.pack,
					name : c.name,
					pos : c.pos,
					meta : c.meta.get(),
					params : [], //c.params.map(stringToTypeParamDec), // todo
					isExtern : c.isExtern,
					kind : TypeDefKind.TDClass(getTypePath(c.superClass), c.interfaces.map(getTypePath), c.isInterface),
					fields : c.fields.get()
						.filter(function(f) return !f.meta.has("noapi"))
						.map(classFieldToField.bind(false))
						.concat(c.statics.get().map(classFieldToField.bind(true)))
				};
				
			case Type.TEnum(t, params):
				var c = t.get();
				if (isExcludeType(c)) return null;
				return
				{
					doc : c.doc,
					pack : c.pack,
					name : c.name,
					pos : c.pos,
					meta : c.meta.get(),
					params : [], // todo
					isExtern : c.isExtern,
					kind : TypeDefKind.TDEnum,
					fields : c.constructs
						.filter(function(f) return !f.meta.has("noapi"))
						.map(enumFieldToField)
						.array()
				};
				
			case Type.TType(t, params):
				var c = t.get();
				if (isExcludeType(c)) return null;
				return
				{
					doc : c.doc,
					pack : c.pack,
					name : c.name,
					pos : c.pos,
					meta : c.meta.get(),
					params : [], // todo
					isExtern : c.isExtern,
					kind : TypeDefKind.TDAlias(typeToComplexType(c.type)),
					fields : null
				};
				
			case Type.TAbstract(t, params):
				var c = t.get();
				if (isExcludeType(c)) return null;
				return
				{
					doc : c.doc,
					pack : c.pack,
					name : c.name,
					pos : c.pos,
					meta : c.meta.get(),
					params : [], // todo
					isExtern : c.isExtern,
					kind : TypeDefKind.TDAlias(typeToComplexType(c.type)),
					fields : [] //c.constructs.map(enumFieldToField).array()
				};
				
			case _:
				return null;
		}
	}
	
	function isExcludeType(c:{ pack:Array<String>, name:String, meta:MetaAccess }) : Bool
	{
		var path = c.pack.concat([c.name]).join(".");
		if (includeRegex != null && !includeRegex.match(path)) return true;
		if (excludeRegex != null &&  excludeRegex.match(path)) return true;
		return c.meta.has("noapi");
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
	
	/*
	function stringToTypeParamDec(s:String) : haxe.macro.TypeParamDecl
	{
		return
		{
			name:s,
			params:null,
			constraints:null
		};
	}
	*/
	
	function classFieldToField(isStatic:Bool, f:ClassField) : Field
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
	
	function enumFieldToField(f:EnumField) : Field
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
	
	function getAccesses(isStatic:Bool, f:ClassField) : Array<Access>
	{
		var r = [];
		//if (f.isOverride) r.push(Access.AOverride);
		if (f.isPublic) r.push(Access.APublic);
		else            r.push(Access.APrivate);
		if (isStatic) r.push(Access.AStatic);
		//if (f.set.match(Rights.RDynamic)) r.push(Access.ADynamic);
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
							params: [] //Array<TypeParamDecl>
						});
						
					case _: 
						null;
				}
				
			case FieldKind.FVar(read, write):
				FieldType.FVar(typeToComplexType(f.type));
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
					.filter(function(f) return !f.meta.has("noapi"))
					.map(classFieldToField.bind((false)))
					.map(function(f) { f.doc = f.doc; return f; });
				for (f in fields) f.access = f.access.filter(function(a) return a != Access.APublic && a != Access.APrivate);
				return ComplexType.TAnonymous(fields);
				
			case _:
				return type.toComplexType();
		}
	}
	
	/*function getFieldInfo(cf:haxe.rtti.ClassField)  :FieldInfo
	{
		var modifiers = {
			isInline: false,
			isDynamic: false
		}
		var isMethod = false;
		var get = "default";
		var set = "default";
		switch (cf.set) {
			case RNo:
				set = "null";
			case RCall(_):
				set = "set";
			case RMethod:
				isMethod = true;
			case RDynamic:
				set = "dynamic";
				isMethod = true;
				modifiers.isDynamic = true;
			default:
		}
		switch (cf.get) {
			case RNo:
				get = "null";
			case RCall(_):
				get = "get";
			case RDynamic:
				get = "dynamic";
			case RInline:
				modifiers.isInline = true;
			default:
		}
		function varOrProperty() {
			return if (get == "default" && set == "default") {
				Variable;
			} else {
				Property(get, set);
			}
		}
		var kind = if (isMethod || modifiers.isInline) {
			switch (cf.type) {
				case CFunction(args, ret):
					Method(args, ret);
				default:
					varOrProperty();
			}
		} else {
			varOrProperty();
		}
		return {
			kind: kind,
			modifiers: modifiers
		}
	}*/
}